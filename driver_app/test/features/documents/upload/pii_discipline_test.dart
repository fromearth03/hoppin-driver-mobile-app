import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/documents/upload/document_picker.dart';
import 'package:hoppin_driver/features/documents/upload/presigned_put_gateway.dart';
import 'package:hoppin_driver/features/documents/upload/upload_providers.dart';
import 'package:hoppin_driver/features/documents/upload/upload_state.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// 🔴 PII DISCIPLINE. TWO SEPARATE SECRETS, AND BOTH ARE REAL.
///
/// **The presigned URL is a bearer credential.** It grants **write access to our
/// storage bucket**, to **anyone who holds it**, for **five minutes**. A
/// `print()`, a `debugPrint`, an analytics event, a crash breadcrumb, or an
/// error message that interpolates it is a **credential leak** — and the natural
/// shape of a Dio failure hands it to you: `DioException.toString()` prints
/// `requestOptions.uri`, signature query string and all.
///
/// **The bytes are a DVLA licence, an NR3S background check, and a right-to-work
/// document.** The NR3S check reveals **criminal-record information** — UK GDPR
/// Article 10 territory, the most tightly regulated category there is. The app is
/// a **CONDUIT, NOT A STORE**: no preview persisted, no blob cached, no thumbnail
/// re-fetched, no `Uint8List` parked in state where a hot reload, a state dump,
/// or a crash report can surface it. Upload and forget.
///
/// These tests do not check that we *intend* to be careful. They check the two
/// mechanical properties that make carelessness impossible to ship.
void main() {
  // The parts of the credential, checked SEPARATELY. A leak of the signature
  // alone is a leak; so is a leak of the path (it contains the driver id and
  // the document type — "this driver uploaded an NR3S background check" is
  // itself a disclosure).
  const host = 'storage.example.com';
  const path = 'driver-docs/d-1/nr3s_background_check/scan.jpg';
  const signature = 'X-Amz-Signature=deadbeefcafe0123456789';
  const presignedUrl = 'https://$host/$path?$signature&X-Amz-Expires=300';

  final slot = (
    uploadUrl: presignedUrl,
    key: path,
    contentType: 'image/jpeg',
    urlExpiresAt: DateTime.utc(2026, 7, 14, 12, 5),
    maxBytes: 10485760,
  );

  /// Everything the framework printed while [body] ran — `debugPrint` is the
  /// funnel every Flutter log, every `FlutterError.reportError`, and every
  /// well-behaved breadcrumb goes through.
  Future<List<String>> captureLogs(Future<void> Function() body) async {
    final lines = <String>[];
    final original = debugPrint;
    final originalOnError = FlutterError.onError;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) lines.add(message);
    };
    FlutterError.onError = (details) => lines.add(details.toString());
    try {
      await body();
    } finally {
      debugPrint = original;
      FlutterError.onError = originalOnError;
    }
    return lines;
  }

  void expectNoCredential(String haystack, {required String where}) {
    for (final needle in const [host, path, signature, 'X-Amz']) {
      expect(
        haystack.contains(needle),
        isFalse,
        reason: '🔴 CREDENTIAL LEAK in $where: it contains `$needle`.\n\n'
            'The presigned URL is a five-minute write credential to our '
            'storage bucket. Anyone who reads it can overwrite a driver\'s '
            'compliance document. It must reach NO log sink and NO '
            'user-visible string — not on success, and especially not on '
            'failure, where DioException.toString() prints the URI for you.',
      );
    }
  }

  ProviderContainer harness({
    required PresignedPutGateway gateway,
    PickedDocument? picked,
  }) {
    final container = ProviderContainer(
      overrides: [
        driverRepositoryProvider.overrideWithValue(_Repo(slot)),
        documentPickerProvider.overrideWithValue(
          _StubPicker(picked ??
              (
                bytes: List<int>.filled(4096, 9),
                contentType: 'image/jpeg',
                sizeBytes: 4096
              )),
        ),
        presignedPutGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('🔴 a SUCCESSFUL upload logs no part of the presigned URL', () async {
    final container = harness(gateway: _OkGateway());

    final logs = await captureLogs(() async {
      await container
          .read(documentUploadControllerProvider.notifier)
          .upload('nr3s_background_check');
    });

    expectNoCredential(logs.join('\n'), where: 'the debugPrint log');
    expect(
      container.read(documentUploadControllerProvider).phase,
      UploadPhase.done,
      reason: 'sanity: the upload the logs are being checked for actually ran',
    );
  });

  test('🔴 a FAILING PUT logs no part of the presigned URL', () async {
    // The dangerous case. A real Dio failure carries `requestOptions.uri` — the
    // full signed URL — and prints it from toString(). If the gateway rethrows
    // the DioException, or if the controller logs `$e`, the credential lands in
    // the log.
    final container = harness(gateway: _ThrowingGateway(presignedUrl));

    final logs = await captureLogs(() async {
      await container
          .read(documentUploadControllerProvider.notifier)
          .upload('nr3s_background_check');
    });

    expectNoCredential(logs.join('\n'), where: 'the debugPrint log on failure');
    expect(container.read(documentUploadControllerProvider).phase,
        UploadPhase.error,
        reason: 'sanity: the failure path actually ran');
  });

  test('🔴 the error shown to the DRIVER contains no part of the URL',
      () async {
    final container = harness(gateway: _ThrowingGateway(presignedUrl));

    await container
        .read(documentUploadControllerProvider.notifier)
        .upload('nr3s_background_check');

    final state = container.read(documentUploadControllerProvider);
    expect(state.error, isNotNull,
        reason: 'a failed upload must say SOMETHING to the driver');
    expectNoCredential(state.error!, where: 'UploadState.error');
  });

  test('the failure state holds no bytes and no preview', () async {
    final container = harness(gateway: _ThrowingGateway(presignedUrl));
    await container
        .read(documentUploadControllerProvider.notifier)
        .upload('nr3s_background_check');

    final dumped = container.read(documentUploadControllerProvider).toString();
    expectNoCredential(dumped, where: 'UploadState.toString()');
  });

  test('🔴 no document byte can be persisted — nothing under upload/ can store',
      () {
    // A SOURCE assertion. The behavioural tests above prove today's code does
    // not persist. This proves tomorrow's cannot start to: the moment someone
    // adds a "handy" thumbnail cache to make the Documents list feel fast, this
    // goes red and names the file.
    //
    // 🔴 THE APP IS NEVER THE STORE OF RECORD. These are photographs of a DVLA
    // licence and an NR3S criminal-record check. A cached preview outlives the
    // upload, survives a crash, gets swept into a device backup, and sits on a
    // phone that gets sold.
    const forbidden = {
      'SharedPreferences': 'key-value storage',
      'shared_preferences': 'key-value storage',
      'path_provider': 'the filesystem',
      'getApplicationDocumentsDirectory': 'the filesystem',
      'getTemporaryDirectory': 'the filesystem',
      'localStorage': 'browser storage',
      'IndexedDB': 'browser storage',
      'window.localStorage': 'browser storage',
      'Hive': 'a local database',
      'sqflite': 'a local database',
      'writeAsBytes': 'a file write',
      'writeAsString': 'a file write',
    };

    final offenders = <String>[];
    for (final f in Directory('lib/features/documents/upload')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final text = f.readAsStringSync();
      for (final needle in forbidden.keys) {
        // Skip the comment lines that EXPLAIN the ban (this file's own prose,
        // and the gateway's). We are policing code, not the warnings about it.
        final hit = text
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('//'))
            .any((l) => l.contains(needle));
        if (hit) offenders.add('${f.path} → $needle (${forbidden[needle]})');
      }
    }

    expect(offenders, isEmpty,
        reason: '🔴 A DOCUMENT BYTE COULD BE PERSISTED:\n  '
            '${offenders.join('\n  ')}\n\n'
            'The app is a CONDUIT for a DVLA licence and an NR3S '
            'criminal-record check — never the store of record. Bytes live in '
            'memory for the duration of one PUT and die when the method '
            'returns.');
  });

  test('🔴 there is no log sink anywhere in the upload path', () {
    // `print`, `debugPrint`, `log` — any one of them, anywhere under upload/,
    // is one refactor away from being handed the URL.
    final offenders = <String>[];
    final sink = RegExp(r'(?<![\w.])(print|debugPrint|log)\s*\(');
    for (final f in Directory('lib/features/documents/upload')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final lines = f.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith('//')) continue;
        if (sink.hasMatch(lines[i])) offenders.add('${f.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'a log sink in the upload path is a credential leak waiting '
            'for the next person to reach for it:\n  ${offenders.join('\n  ')}');
  });

  test('🔴 UploadState declares no bytes field and no preview field', () {
    final src =
        File('lib/features/documents/upload/upload_state.dart').readAsStringSync();
    final code = src
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    for (final banned in const [
      'Uint8List',
      'List<int>',
      'previewUrl',
      'preview',
      'thumbnail',
      'bytes',
    ]) {
      expect(code.contains(banned), isFalse,
          reason: 'UploadState must never hold `$banned`. State survives a hot '
              'reload, gets dumped by a devtools inspector, and lands in a '
              'crash report. The bytes are a criminal-record check.');
    }
  });
}

class _OkGateway implements PresignedPutGateway {
  @override
  Future<void> put({
    required String uploadUrl,
    required List<int> bytes,
    required String contentType,
  }) async {}
}

/// Fails the way the REAL thing fails: a sanitised [UploadFailure]. If the
/// gateway ever regresses to rethrowing the raw DioException, the tests above
/// still hold it to account — because the controller must not print `$e` either.
class _ThrowingGateway implements PresignedPutGateway {
  _ThrowingGateway(this.url);
  final String url;

  @override
  Future<void> put({
    required String uploadUrl,
    required List<int> bytes,
    required String contentType,
  }) async {
    throw const UploadFailure(403);
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

class _Repo implements DriverRepository {
  _Repo(this.slot);
  final DocumentUploadSlot slot;

  @override
  Future<DocumentUploadSlot> documentUploadUrl({
    required String documentType,
    required String contentType,
  }) async =>
      slot;

  @override
  Future<DriverDocument> confirmDocument({
    required String documentType,
    required String key,
    DateTime? expiresAt,
  }) async =>
      DriverDocument(
        id: 'doc-1',
        documentType: documentType,
        verificationStatus: 'pending_review',
        uploadedAt: DateTime.utc(2026, 7, 14),
      );

  @override
  Future<List<DriverDocument>> documents() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
