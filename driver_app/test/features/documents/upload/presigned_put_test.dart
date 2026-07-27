import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/documents/upload/document_picker.dart';
import 'package:hoppin_driver/features/documents/upload/presigned_put_gateway.dart';
import 'package:hoppin_driver/features/documents/upload/upload_providers.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// 🔴 THE PRESIGNED PUT, AND THE FOUR WAYS IT SILENTLY BREAKS.
///
/// The three-step flow (`driver_repository.dart:188-236`) is
/// `documentUploadUrl` → **raw PUT** → `confirmDocument`. Step 2 is the only
/// request in this entire application that must NOT go through `ApiClient`, and
/// every reason is invisible until a real driver in Wolverhampton photographs a
/// real DVLA licence and gets a 403 they cannot act on.
///
/// **1. The `Authorization` header.** `ApiClient` attaches
/// `Authorization: Bearer <supabase token>` to every request via a Dio
/// interceptor (`api_client.dart:27-38`). A presigned S3/GCS URL signs a
/// SPECIFIC SET of headers; `Authorization` is not in that set. Sending one
/// invalidates the signature and the bucket answers **403 SignatureDoesNotMatch**.
/// The failure *looks* like an auth problem, so the instinctive fix — refresh
/// the token and retry — reproduces it forever.
///
/// **2. The `Content-Type`.** It is signed too, byte for byte. `ApiClient` pins
/// `application/json` on its Dio options; and Dio itself will helpfully append
/// `; charset=utf-8` if it sees a String body. Either mutation breaks the
/// signature exactly as thoroughly as the bearer does.
///
/// **3. The TTL.** Five minutes. A driver who opens the Documents screen, reads
/// eight rows, finds their licence in a drawer, photographs it, and comes back
/// has burnt more than five minutes. A URL fetched at *screen-open* is an upload
/// that fails **for the slowest and most careful drivers only** — the worst
/// possible failure distribution, and one no developer with a fast phone and a
/// staged test file will ever reproduce.
void main() {
  const slot = (
    uploadUrl:
        'https://storage.example.com/driver-docs/d-1/dvla_license/abc.jpg'
            '?X-Amz-Signature=deadbeefcafe&X-Amz-Expires=300',
    key: 'driver-docs/d-1/dvla_license/abc.jpg',
    contentType: 'image/jpeg',
    maxBytes: 10485760,
  );
  final expiry = DateTime.utc(2026, 7, 14, 12, 5);

  DocumentUploadSlot theSlot() => (
        uploadUrl: slot.uploadUrl,
        key: slot.key,
        contentType: slot.contentType,
        urlExpiresAt: expiry,
        maxBytes: slot.maxBytes,
      );

  group('🔴 the bare-Dio gateway', () {
    late _HeaderRecorder recorder;
    late DioPresignedPutGateway gateway;

    setUp(() {
      // A Dio the gateway will treat as its own. We install ONE interceptor
      // purely to CAPTURE what the gateway asked for and short-circuit with a
      // synthetic 200 — no socket is ever opened. The gateway constructs its
      // own bare Dio in production; injecting one here is the only way to see
      // the headers it actually sets.
      recorder = _HeaderRecorder();
      final dio = Dio()..interceptors.add(recorder);
      gateway = DioPresignedPutGateway(dio: dio);
    });

    test('🔴 the PUT carries NO `Authorization` header', () async {
      await gateway.put(
        uploadUrl: slot.uploadUrl,
        bytes: const [1, 2, 3, 4],
        contentType: slot.contentType,
      );

      final keys =
          recorder.headers!.keys.map((k) => k.toLowerCase()).toList();
      expect(
        keys,
        isNot(contains('authorization')),
        reason: '🔴 A bearer on a presigned PUT invalidates the SIGNATURE. The '
            'bucket answers 403 and it reads like an auth failure, so the next '
            'person refreshes the token and retries — forever. The PUT must '
            'use a bare Dio with ZERO interceptors, never ApiClient.',
      );
    });

    test('the PUT carries `Content-Type` equal to the slot, byte for byte',
        () async {
      await gateway.put(
        uploadUrl: slot.uploadUrl,
        bytes: const [1, 2, 3, 4],
        contentType: slot.contentType,
      );

      expect(
        recorder.headers![Headers.contentTypeHeader],
        slot.contentType,
        reason: 'EQUAL — not "starts with", not "contains". A '
            '`; charset=utf-8` suffix Dio appends to a String body breaks the '
            'signature exactly as thoroughly as the bearer does. The server '
            'signed `${slot.contentType}` and nothing else.',
      );
    });

    test('a non-2xx becomes a SANITISED UploadFailure carrying only a status',
        () async {
      recorder.status = 403;

      await expectLater(
        gateway.put(
          uploadUrl: slot.uploadUrl,
          bytes: const [1, 2, 3],
          contentType: slot.contentType,
        ),
        throwsA(
          isA<UploadFailure>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.toString(), 'toString()',
                  isNot(contains('storage.example.com'))),
        ),
        reason: 'a DioException carries `requestOptions.uri` — the presigned '
            'URL — and prints it from toString(). Rethrowing it hands a live '
            'write credential to every log sink downstream.',
      );
    });

    test('a transport failure becomes UploadFailure(0), still with no URI',
        () async {
      recorder.throwTransport = true;

      await expectLater(
        gateway.put(
          uploadUrl: slot.uploadUrl,
          bytes: const [1, 2, 3],
          contentType: slot.contentType,
        ),
        throwsA(
          isA<UploadFailure>()
              .having((e) => e.statusCode, 'statusCode', 0)
              .having((e) => e.toString(), 'toString()',
                  isNot(contains('X-Amz-Signature'))),
        ),
      );
    });
  });

  test('🔴 NOTHING in the upload path can reach ApiClient or set a bearer', () {
    // A SOURCE assertion, in the router_reachability_test tradition: the header
    // tests above prove the gateway we INJECTED behaves. They cannot prove that
    // someone, later, will not "simplify" the production gateway by reaching for
    // the shared client, or hand it `apiClientProvider`'s Dio "to reuse the
    // connection pool". This can.
    //
    // 🔴 IT READS THE CODE, NOT THE PROSE. The first cut of this grepped the
    // whole file and went red on the gateway's own doc comment — which NAMES
    // `api_client.dart` in order to explain, at length, why it must never import
    // it. A grep that matches a comment is the exact failure
    // `router_reachability_test.dart` documents: it passes and fails for reasons
    // that have nothing to do with what the code does. So: strip the comments,
    // then look.
    //
    // Scope is the WHOLE directory, not just the gateway. A controller that
    // reached for ApiClient's Dio and passed it in would break the signature
    // just as completely, and the gateway's own source would look innocent.
    final offenders = <String>[];
    for (final f in Directory('lib/features/documents/upload')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final lines = f.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        for (final banned in const [
          'api_client',
          'ApiClient',
          'apiClientProvider',
          'Authorization',
          'accessToken',
        ]) {
          if (line.contains(banned)) {
            offenders.add('${f.path}:${i + 1} → $banned');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: '🔴 THE PRESIGNED PUT CAN REACH A BEARER:\n  '
          '${offenders.join('\n  ')}\n\n'
          "`ApiClient`'s interceptor attaches `Authorization: Bearer <token>` "
          'to everything it sends. A presigned S3/GCS URL signs a specific set '
          'of headers and `Authorization` is not one of them — sending it '
          'invalidates the signature and the bucket answers 403. It reads like '
          'an auth failure, so the next person refreshes the token and retries, '
          'forever. The PUT uses a bare Dio with zero interceptors, and there '
          'must be no path from this directory to the shared client at all.',
    );
  });

  group('🔴 the upload URL is fetched at PUT TIME', () {
    test('zero upload-url calls at screen-open; exactly one when uploading',
        () async {
      final repo = _RecordingDriverRepo(theSlot());
      final container = ProviderContainer(
        overrides: [
          driverRepositoryProvider.overrideWithValue(repo),
          documentPickerProvider
              .overrideWithValue(_StubPicker(_jpegDoc())),
          presignedPutGatewayProvider
              .overrideWithValue(_RecordingGateway()),
        ],
      );
      addTearDown(container.dispose);

      // Screen-open: the controller builds. NOTHING is fetched.
      container.read(documentUploadControllerProvider);
      await Future<void>.delayed(Duration.zero);

      expect(
        repo.uploadUrlCalls,
        0,
        reason: '🔴 THE TTL IS FIVE MINUTES. A URL minted at screen-open is '
            'already stale by the time a driver has found their licence, '
            'photographed it, and come back. It fails for the slowest, most '
            'careful drivers ONLY — and never on a developer\'s desk.',
      );

      await container
          .read(documentUploadControllerProvider.notifier)
          .upload('dvla_license');

      expect(repo.uploadUrlCalls, 1,
          reason: 'exactly one slot, minted at the moment we PUT');
    });

    test('the slot is minted less than a second before the PUT', () async {
      final repo = _RecordingDriverRepo(theSlot());
      final gateway = _RecordingGateway();
      final container = ProviderContainer(
        overrides: [
          driverRepositoryProvider.overrideWithValue(repo),
          documentPickerProvider.overrideWithValue(_StubPicker(_jpegDoc())),
          presignedPutGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(documentUploadControllerProvider.notifier)
          .upload('dvla_license');

      final gap = gateway.putAt!.difference(repo.uploadUrlAt!);
      expect(gap, lessThan(const Duration(seconds: 1)),
          reason: 'the slot must be awaited IMMEDIATELY before the PUT, in the '
              'same method — never hoisted, cached in state, prefetched on '
              'build(), or memoised');
    });

    test('the PUT echoes the SLOT\'s content type, not our own guess', () async {
      // The server signs what IT chose. If it normalises `image/jpg` →
      // `image/jpeg`, we must PUT what it signed.
      final repo = _RecordingDriverRepo((
        uploadUrl: slot.uploadUrl,
        key: slot.key,
        contentType: 'image/jpeg',
        urlExpiresAt: expiry,
        maxBytes: slot.maxBytes,
      ));
      final gateway = _RecordingGateway();
      final container = ProviderContainer(
        overrides: [
          driverRepositoryProvider.overrideWithValue(repo),
          documentPickerProvider.overrideWithValue(_StubPicker(_jpegDoc())),
          presignedPutGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(documentUploadControllerProvider.notifier)
          .upload('dvla_license');

      expect(gateway.contentType, 'image/jpeg');
      expect(gateway.uploadUrl, slot.uploadUrl);
      expect(repo.confirmedKey, slot.key,
          reason: 'confirm must carry the SAME key step 1 issued');
    });
  });
}

PickedDocument _jpegDoc() =>
    (bytes: List<int>.filled(2048, 7), contentType: 'image/jpeg', sizeBytes: 2048);

/// Captures the request the gateway built and answers a synthetic response —
/// no socket, no network, no MethodChannel.
class _HeaderRecorder extends Interceptor {
  Map<String, dynamic>? headers;
  int status = 200;
  bool throwTransport = false;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    headers = Map<String, dynamic>.from(options.headers);
    if (throwTransport) {
      return handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'no route to ${options.uri}',
        ),
      );
    }
    if (status >= 200 && status < 300) {
      return handler.resolve(
        Response<void>(requestOptions: options, statusCode: status),
      );
    }
    handler.reject(
      DioException(
        requestOptions: options,
        response: Response<void>(requestOptions: options, statusCode: status),
        type: DioExceptionType.badResponse,
      ),
    );
  }
}

class _RecordingGateway implements PresignedPutGateway {
  DateTime? putAt;
  String? uploadUrl;
  String? contentType;
  List<int>? bytes;

  @override
  Future<void> put({
    required String uploadUrl,
    required List<int> bytes,
    required String contentType,
  }) async {
    putAt = DateTime.now();
    this.uploadUrl = uploadUrl;
    this.bytes = bytes;
    this.contentType = contentType;
  }
}

class _StubPicker implements DocumentPicker {
  _StubPicker(this.doc);
  final PickedDocument? doc;

  @override
  Future<PickedDocument?> pickImage({bool fromCamera = false}) async => doc;

  @override
  Future<PickedDocument?> pickFile() async => doc;
}

class _RecordingDriverRepo implements DriverRepository {
  _RecordingDriverRepo(this.slot);
  final DocumentUploadSlot slot;

  int uploadUrlCalls = 0;
  DateTime? uploadUrlAt;
  String? confirmedKey;

  @override
  Future<DocumentUploadSlot> documentUploadUrl({
    required String documentType,
    required String contentType,
  }) async {
    uploadUrlCalls++;
    uploadUrlAt = DateTime.now();
    return slot;
  }

  @override
  Future<DriverDocument> confirmDocument({
    required String documentType,
    required String key,
    DateTime? expiresAt,
  }) async {
    confirmedKey = key;
    return DriverDocument(
      id: 'doc-1',
      documentType: documentType,
      verificationStatus: 'pending_review',
      uploadedAt: DateTime.utc(2026, 7, 14),
      expiresAt: expiresAt,
    );
  }

  @override
  Future<List<DriverDocument>> documents() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
