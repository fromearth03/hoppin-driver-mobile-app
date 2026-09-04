import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/documents/data/documents_repository.dart';
import 'package:hoppin_driver/features/documents/data/models/driver_document.dart';
import 'package:hoppin_driver/features/documents/logic/upload_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockDocsRepo extends Mock implements DocumentsRepository {}

void main() {
  setUpAll(() => registerFallbackValue(Uint8List(0)));

  late MockDocsRepo repo;

  setUp(() => repo = MockDocsRepo());

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      documentsRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  final bytes = Uint8List.fromList([1, 2, 3]);

  final document = DriverDocument.fromJson(const {
    'id': 'doc-1',
    'document_type': 'vehicle_insurance',
    'verification_status': 'pending_review',
  });

  void stubUpload() {
    when(() => repo.upload(
          documentType: any(named: 'documentType'),
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
          contentType: any(named: 'contentType'),
          expiresAt: any(named: 'expiresAt'),
        )).thenAnswer((_) async => Ok(document));
  }

  test('posts the bytes in a single call', () async {
    stubUpload();

    final r = await container()
        .read(uploadControllerProvider.notifier)
        .upload('vehicle_insurance', bytes, 'insurance.jpg');

    expect(r.isOk, isTrue);
    expect(r.valueOrNull!.id, 'doc-1');
    verify(() => repo.upload(
          documentType: 'vehicle_insurance',
          bytes: bytes,
          filename: 'insurance.jpg',
          contentType: 'image/jpeg',
          expiresAt: null,
        )).called(1);
  });

  test('derives the content type from the extension', () async {
    stubUpload();

    await container()
        .read(uploadControllerProvider.notifier)
        .upload('vehicle_insurance', bytes, 'policy.PDF');

    verify(() => repo.upload(
          documentType: any(named: 'documentType'),
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
          contentType: 'application/pdf',
          expiresAt: any(named: 'expiresAt'),
        )).called(1);
  });

  test('rejects an unsupported extension without calling the service',
      () async {
    final r = await container()
        .read(uploadControllerProvider.notifier)
        .upload('vehicle_insurance', bytes, 'scan.heic');

    expect(r.errorOrNull!.code, 'VALIDATION_FAILED');
    verifyNever(() => repo.upload(
          documentType: any(named: 'documentType'),
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
          contentType: any(named: 'contentType'),
          expiresAt: any(named: 'expiresAt'),
        ));
  });

  test('rejects a file over 10 MB before uploading it', () async {
    final huge = Uint8List(10 * 1024 * 1024 + 1);

    final r = await container()
        .read(uploadControllerProvider.notifier)
        .upload('vehicle_insurance', huge, 'big.jpg');

    expect(r.errorOrNull!.code, 'FILE_TOO_LARGE');
    verifyNever(() => repo.upload(
          documentType: any(named: 'documentType'),
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
          contentType: any(named: 'contentType'),
          expiresAt: any(named: 'expiresAt'),
        ));
  });

  test('surfaces a failure on the state so the screen can render it',
      () async {
    when(() => repo.upload(
          documentType: any(named: 'documentType'),
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
          contentType: any(named: 'contentType'),
          expiresAt: any(named: 'expiresAt'),
        )).thenAnswer(
        (_) async => Err(ApiException('FILE_TOO_LARGE', 'too big', 413)));

    final c = container();
    final r = await c
        .read(uploadControllerProvider.notifier)
        .upload('vehicle_insurance', bytes, 'insurance.jpg');

    expect(r.isOk, isFalse);
    expect(c.read(uploadControllerProvider).error!.code, 'FILE_TOO_LARGE');
  });

  test('passes an expiry through when the type needs one', () async {
    stubUpload();
    final expires = DateTime.utc(2027, 1, 1);

    await container()
        .read(uploadControllerProvider.notifier)
        .upload('vehicle_insurance', bytes, 'insurance.jpg',
            expiresAt: expires);

    verify(() => repo.upload(
          documentType: any(named: 'documentType'),
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
          contentType: any(named: 'contentType'),
          expiresAt: expires,
        )).called(1);
  });
}
