import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/documents/data/documents_repository.dart';
import 'package:hoppin_driver/features/documents/data/models/driver_document.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late DocumentsRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = DocumentsRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  group('DriverDocument', () {
    test('carries the rejection reason so a re-upload can succeed', () {
      final d = DriverDocument.fromJson({
        'id': 'd1',
        'document_type': 'vehicle_insurance',
        'verification_status': 'rejected',
        'uploaded_at': '2026-08-01T10:00:00Z',
        'rejection_reason': 'The photo was too blurry to read the expiry date.',
      });

      expect(d.status, DocumentStatus.rejected);
      // Without this the driver re-uploads the same file and is rejected
      // again — the loop A21 existed to break.
      expect(d.rejectionReason,
          'The photo was too blurry to read the expiry date.');
      expect(d.needsAction, isTrue);
    });

    test('an approved document needs nothing', () {
      final d = DriverDocument.fromJson({
        'id': 'd2',
        'document_type': 'dbs_check',
        'verification_status': 'approved',
        'uploaded_at': '2026-08-01T10:00:00Z',
        'expires_at': '2027-08-01T10:00:00Z',
      });

      expect(d.needsAction, isFalse);
      expect(d.isExpiringSoon, isFalse);
    });

    test('flags a document expiring within thirty days', () {
      final soon = DateTime.now().add(const Duration(days: 20));
      final d = DriverDocument.fromJson({
        'id': 'd3',
        'document_type': 'mot_certificate',
        'verification_status': 'approved',
        'uploaded_at': '2026-01-01T10:00:00Z',
        'expires_at': soon.toIso8601String(),
      });

      expect(d.isExpiringSoon, isTrue);
    });

    test('treats an already-expired document as needing action', () {
      final past = DateTime.now().subtract(const Duration(days: 1));
      final d = DriverDocument.fromJson({
        'id': 'd4',
        'document_type': 'vehicle_insurance',
        'verification_status': 'approved',
        'uploaded_at': '2026-01-01T10:00:00Z',
        'expires_at': past.toIso8601String(),
      });

      expect(d.status, DocumentStatus.expired);
      expect(d.needsAction, isTrue);
    });

    test('an unknown status degrades to pending rather than throwing', () {
      final d = DriverDocument.fromJson({
        'id': 'd5',
        'document_type': 'x',
        'verification_status': 'something_new',
        'uploaded_at': '2026-01-01T10:00:00Z',
      });

      expect(d.status, DocumentStatus.pending);
    });
  });

  group('DocumentsRepository', () {
    test('pairs every known type with the driver upload, if any', () async {
      var call = 0;
      when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async {
        call++;
        return call == 1
            ? body(
                '[{"code":"vehicle_insurance","label":"Vehicle Insurance",'
                '"uploadable":true,"expires":true},'
                '{"code":"nr3s_background_check","label":"Background Check",'
                '"uploadable":false,"expires":false}]',
                200)
            : body(
                '[{"id":"d1","document_type":"vehicle_insurance",'
                '"verification_status":"approved",'
                '"uploaded_at":"2026-08-01T10:00:00Z"}]',
                200);
      });

      final r = await repo.slots();

      expect(r.valueOrNull, hasLength(2));
      expect(r.valueOrNull!.first.document, isNotNull);
      // A type the driver has never uploaded still gets a slot, so the grid
      // shows what is missing rather than silently omitting it.
      expect(r.valueOrNull!.last.document, isNull);
      expect(r.valueOrNull!.last.type.uploadable, isFalse);
    });

    test('an operator-run type is not uploadable', () async {
      when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
          body(
              '[{"code":"nr3s_background_check","label":"Background Check",'
              '"uploadable":false,"expires":false}]',
              200));

      final r = await repo.types();

      expect(r.valueOrNull!.single.uploadable, isFalse);
    });

    test('surfaces STORAGE_DISABLED as retryable', () async {
      when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
          body('{"code":"STORAGE_DISABLED","error":"bucket down"}', 503));

      final r = await repo.uploadUrl('vehicle_insurance');

      expect(r.errorOrNull!.code, 'STORAGE_DISABLED');
      expect(r.errorOrNull!.isRetryable, isTrue);
    });
  });
}
