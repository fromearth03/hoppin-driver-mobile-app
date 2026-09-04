import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/documents/data/documents_repository.dart';
import 'package:hoppin_driver/features/documents/data/models/driver_document.dart';
import 'package:mocktail/mocktail.dart';

class MockApi extends Mock implements ApiClient {}

class _FakeFormData extends Fake implements FormData {}

/// These tests assert against the shape the deployed ride-service really
/// accepts, confirmed by posting a real file to production on 2026-09-04
/// (HTTP 201, `verification_status: pending_review`).
///
/// The upload was a three-call presign → PUT → confirm sequence until then.
/// The presigned URL pointed at `http://minio:9000`, an internal Docker
/// hostname no device outside the server can resolve, so the PUT never
/// connected and no driver could submit a document. The service now accepts
/// the bytes directly on one multipart route and stores them itself.
void main() {
  setUpAll(() => registerFallbackValue(_FakeFormData()));

  late MockApi api;

  setUp(() => api = MockApi());

  final bytes = Uint8List.fromList([1, 2, 3]);

  void stubOk() {
    when(() => api.postMultipart<Map<String, dynamic>>(any(), any()))
        .thenAnswer((_) async => const Ok({
              'id': 'd1',
              'document_type': 'insurance_policy',
              'verification_status': 'pending_review',
            }));
  }

  FormData captureForm() =>
      verify(() => api.postMultipart<Map<String, dynamic>>(
              '/drivers/me/documents/upload', captureAny()))
          .captured
          .single as FormData;

  Future<Result<DriverDocument>> upload({DateTime? expiresAt}) =>
      DocumentsRepository(api).upload(
        documentType: 'insurance_policy',
        bytes: bytes,
        filename: 'policy.pdf',
        contentType: 'application/pdf',
        expiresAt: expiresAt,
      );

  test('posts multipart to the upload route', () async {
    stubOk();

    await upload();

    // The old presign/confirm routes must not be called at all — the whole
    // point of the change is that the client never touches object storage.
    verifyNever(() => api.post<Map<String, dynamic>>(any(),
        body: any(named: 'body')));
    captureForm();
  });

  test('sends document_type as a form field', () async {
    stubOk();

    await upload();

    final fields = {
      for (final f in captureForm().fields) f.key: f.value,
    };
    expect(fields['document_type'], 'insurance_policy');
  });

  test('sends the bytes under the field name the handler reads', () async {
    stubOk();

    await upload();

    final file = captureForm().files.single;
    // The handler reads the part named exactly "file"; anything else is a
    // 400 with no file found.
    expect(file.key, 'file');
    expect(file.value.length, bytes.length);
  });

  test('labels the part with its content type', () async {
    stubOk();

    await upload();

    // A part with no content type makes the service sniff the bytes. Sending
    // it means the stored object is labelled from what the app knows.
    expect(
      captureForm().files.single.value.contentType.toString(),
      'application/pdf',
    );
  });

  test('omits expires_at when the type does not carry one', () async {
    stubOk();

    await upload();

    final keys = captureForm().fields.map((f) => f.key);
    expect(keys, isNot(contains('expires_at')));
  });

  test('sends expires_at as UTC ISO-8601 when given', () async {
    stubOk();

    await upload(expiresAt: DateTime.utc(2027, 3, 4, 5, 6, 7));

    final fields = {
      for (final f in captureForm().fields) f.key: f.value,
    };
    expect(fields['expires_at'], '2027-03-04T05:06:07.000Z');
  });

  test('parses the created document out of the response', () async {
    stubOk();

    final r = await upload();

    expect(r.valueOrNull!.id, 'd1');
    expect(r.valueOrNull!.status, DocumentStatus.pending);
  });

  test('surfaces FILE_TOO_LARGE from the service', () async {
    when(() => api.postMultipart<Map<String, dynamic>>(any(), any()))
        .thenAnswer((_) async =>
            Err(ApiException('FILE_TOO_LARGE', 'over 10MB', 413)));

    final r = await upload();

    expect(r.errorOrNull!.code, 'FILE_TOO_LARGE');
  });

  test('surfaces STORAGE_DISABLED as retryable', () async {
    when(() => api.postMultipart<Map<String, dynamic>>(any(), any()))
        .thenAnswer((_) async =>
            Err(ApiException('STORAGE_DISABLED', 'bucket down', 503)));

    final r = await upload();

    expect(r.errorOrNull!.code, 'STORAGE_DISABLED');
    expect(r.errorOrNull!.isRetryable, isTrue);
  });
}
