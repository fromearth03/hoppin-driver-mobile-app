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

class MockUploader extends Mock implements FileUploader {}

void main() {
  setUpAll(() => registerFallbackValue(Uint8List(0)));

  late MockDocsRepo repo;
  late MockUploader uploader;

  setUp(() {
    repo = MockDocsRepo();
    uploader = MockUploader();
  });

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      documentsRepositoryProvider.overrideWithValue(repo),
      fileUploaderProvider.overrideWithValue(uploader),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  final bytes = Uint8List.fromList([1, 2, 3]);

  test('presigns, uploads, then confirms — in that order', () async {
    when(() => repo.uploadUrl(any())).thenAnswer((_) async => const Ok({
          'upload_url': 'https://storage/put',
          'file_url': 'https://storage/file.jpg',
        }));
    when(() => uploader.put(any(), any(), any()))
        .thenAnswer((_) async => const Ok(null));
    when(() => repo.confirm(
            documentType: any(named: 'documentType'),
            fileUrl: any(named: 'fileUrl'),
            expiresAt: any(named: 'expiresAt')))
        .thenAnswer((_) async => const Ok(DriverDocument(
            id: 'd1',
            documentType: 'vehicle_insurance',
            status: DocumentStatus.pending)));

    final c = container();
    final r = await c
        .read(uploadControllerProvider.notifier)
        .upload('vehicle_insurance', bytes, 'insurance.jpg');

    expect(r.isOk, isTrue);
    verifyInOrder([
      () => repo.uploadUrl('vehicle_insurance'),
      () => uploader.put('https://storage/put', bytes, any()),
      () => repo.confirm(
          documentType: 'vehicle_insurance',
          fileUrl: 'https://storage/file.jpg',
          expiresAt: any(named: 'expiresAt')),
    ]);
  });

  test('does not confirm when the file never reached storage', () async {
    when(() => repo.uploadUrl(any())).thenAnswer((_) async => const Ok({
          'upload_url': 'https://storage/put',
          'file_url': 'https://storage/file.jpg',
        }));
    when(() => uploader.put(any(), any(), any()))
        .thenAnswer((_) async => Err(ApiException('INTERNAL', 'network', 0)));

    final c = container();
    final r = await c
        .read(uploadControllerProvider.notifier)
        .upload('vehicle_insurance', bytes, 'insurance.jpg');

    expect(r.isOk, isFalse);
    // Confirming a file that is not there would leave the driver looking
    // compliant with nothing uploaded.
    verifyNever(() => repo.confirm(
        documentType: any(named: 'documentType'),
        fileUrl: any(named: 'fileUrl'),
        expiresAt: any(named: 'expiresAt')));
  });

  test('surfaces STORAGE_DISABLED without attempting an upload', () async {
    when(() => repo.uploadUrl(any()))
        .thenAnswer((_) async => Err(ApiException('STORAGE_DISABLED', '', 503)));

    final c = container();
    final r = await c
        .read(uploadControllerProvider.notifier)
        .upload('vehicle_insurance', bytes, 'insurance.jpg');

    expect(r.errorOrNull!.code, 'STORAGE_DISABLED');
    verifyNever(() => uploader.put(any(), any(), any()));
  });

  test('passes an expiry date through to the confirm call', () async {
    final expires = DateTime.utc(2027, 6, 1);
    when(() => repo.uploadUrl(any())).thenAnswer((_) async => const Ok({
          'upload_url': 'https://storage/put',
          'file_url': 'https://storage/file.jpg',
        }));
    when(() => uploader.put(any(), any(), any()))
        .thenAnswer((_) async => const Ok(null));
    when(() => repo.confirm(
            documentType: any(named: 'documentType'),
            fileUrl: any(named: 'fileUrl'),
            expiresAt: any(named: 'expiresAt')))
        .thenAnswer((_) async => const Ok(DriverDocument(
            id: 'd1',
            documentType: 'vehicle_insurance',
            status: DocumentStatus.pending)));

    final c = container();
    await c
        .read(uploadControllerProvider.notifier)
        .upload('vehicle_insurance', bytes, 'insurance.jpg', expiresAt: expires);

    verify(() => repo.confirm(
        documentType: 'vehicle_insurance',
        fileUrl: 'https://storage/file.jpg',
        expiresAt: expires)).called(1);
  });
}
