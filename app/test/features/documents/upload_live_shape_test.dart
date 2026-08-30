import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/documents/data/documents_repository.dart';
import 'package:hoppin_driver/features/documents/data/models/driver_document.dart';
import 'package:hoppin_driver/features/documents/logic/upload_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockApi extends Mock implements ApiClient {}

class MockUploader extends Mock implements FileUploader {}

/// These tests assert against the shapes the deployed ride-service really
/// sends and requires, read from its Go source rather than the handover doc.
///
/// Every step of the upload was wrong against it: presign 400d without a
/// content_type, the response carries `key` (never `file_url`), and confirm
/// takes `key` — which the service prefix-checks against
/// `driver-docs/{uid}/{type}/`. A document could not be submitted at all, so
/// no driver could clear compliance.
void main() {
  setUpAll(() => registerFallbackValue(Uint8List(0)));

  late MockApi api;
  late MockUploader uploader;

  setUp(() {
    api = MockApi();
    uploader = MockUploader();
  });

  final bytes = Uint8List.fromList([1, 2, 3]);

  test('presign sends the content_type the service requires', () async {
    when(() => api.post<Map<String, dynamic>>(any(), body: any(named: 'body')))
        .thenAnswer((_) async => const Ok({'upload_url': 'u', 'key': 'k'}));

    await DocumentsRepository(api)
        .uploadUrl('insurance_policy', 'application/pdf');

    final body = verify(() => api.post<Map<String, dynamic>>(
            '/drivers/me/documents/upload-url',
            body: captureAny(named: 'body')))
        .captured
        .single as Map<String, dynamic>;
    // Without content_type the handler answers
    // "document_type and content_type are required" with a 400.
    expect(body['content_type'], 'application/pdf');
    expect(body['document_type'], 'insurance_policy');
  });

  test('confirm sends key, not a bucket url', () async {
    when(() => api.post<Map<String, dynamic>>(any(), body: any(named: 'body')))
        .thenAnswer((_) async => const Ok({
              'id': 'd1',
              'document_type': 'insurance_policy',
              'verification_status': 'pending_review',
            }));

    await DocumentsRepository(api).confirm(
      documentType: 'insurance_policy',
      key: 'driver-docs/u1/insurance_policy/abc.pdf',
    );

    final body = verify(() => api.post<Map<String, dynamic>>(
            '/drivers/me/documents', body: captureAny(named: 'body')))
        .captured
        .single as Map<String, dynamic>;
    expect(body['key'], 'driver-docs/u1/insurance_policy/abc.pdf');
    // The service has no bucket_file_url field, and prefix-checks the key
    // against driver-docs/{uid}/{type}/ — a URL can never satisfy that.
    expect(body.containsKey('bucket_file_url'), isFalse);
  });

  test('the whole upload runs on the key the presign returned', () async {
    final repo = MockDocsRepo();
    when(() => repo.uploadUrl(any(), any())).thenAnswer((_) async => const Ok({
          'upload_url': 'https://storage/put',
          'key': 'driver-docs/u1/insurance_policy/abc.pdf',
          'content_type': 'application/pdf',
        }));
    when(() => uploader.put(any(), any(), any()))
        .thenAnswer((_) async => const Ok(null));
    when(() => repo.confirm(
            documentType: any(named: 'documentType'),
            key: any(named: 'key'),
            expiresAt: any(named: 'expiresAt')))
        .thenAnswer((_) async => const Ok(DriverDocument(
            id: 'd1',
            documentType: 'insurance_policy',
            status: DocumentStatus.pending)));

    final c = ProviderContainer(overrides: [
      documentsRepositoryProvider.overrideWithValue(repo),
      fileUploaderProvider.overrideWithValue(uploader),
    ]);
    addTearDown(c.dispose);

    final r = await c
        .read(uploadControllerProvider.notifier)
        .upload('insurance_policy', bytes, 'policy.pdf');

    expect(r.isOk, isTrue);
    verifyInOrder([
      // The content type is settled before the presign so the PUT header,
      // the presigned signature and the stored extension all agree.
      () => repo.uploadUrl('insurance_policy', 'application/pdf'),
      () => uploader.put('https://storage/put', bytes, 'application/pdf'),
      () => repo.confirm(
          documentType: 'insurance_policy',
          key: 'driver-docs/u1/insurance_policy/abc.pdf',
          expiresAt: any(named: 'expiresAt')),
    ]);
  });

  test('an unsupported file type never reaches the network', () async {
    final repo = MockDocsRepo();
    final c = ProviderContainer(overrides: [
      documentsRepositoryProvider.overrideWithValue(repo),
      fileUploaderProvider.overrideWithValue(uploader),
    ]);
    addTearDown(c.dispose);

    // The service accepts only pdf, jpeg and png. Guessing image/jpeg for a
    // .docx would presign a key ending .jpg and store a mislabelled object.
    final r = await c
        .read(uploadControllerProvider.notifier)
        .upload('insurance_policy', bytes, 'policy.docx');

    expect(r.isOk, isFalse);
    expect(r.errorOrNull!.code, 'VALIDATION_FAILED');
    verifyNever(() => repo.uploadUrl(any(), any()));
    verifyNever(() => uploader.put(any(), any(), any()));
  });

  test('a presign missing its key fails instead of throwing', () async {
    final repo = MockDocsRepo();
    when(() => repo.uploadUrl(any(), any()))
        .thenAnswer((_) async => const Ok({'upload_url': 'https://storage/put'}));

    final c = ProviderContainer(overrides: [
      documentsRepositoryProvider.overrideWithValue(repo),
      fileUploaderProvider.overrideWithValue(uploader),
    ]);
    addTearDown(c.dispose);

    final r = await c
        .read(uploadControllerProvider.notifier)
        .upload('insurance_policy', bytes, 'policy.pdf');

    expect(r.isOk, isFalse);
    verifyNever(() => uploader.put(any(), any(), any()));
  });
}

class MockDocsRepo extends Mock implements DocumentsRepository {}
