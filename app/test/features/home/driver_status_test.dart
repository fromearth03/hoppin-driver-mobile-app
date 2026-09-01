import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/home/data/driver_status_repository.dart';
import 'package:hoppin_driver/features/home/data/models/driver_status.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late DriverStatusRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = DriverStatusRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  group('DriverStatus model', () {
    test('parses an unblocked online driver', () {
      final s = DriverStatus.fromJson({
        'presence': 'online',
        'last_location_at': '2026-08-30T10:00:00Z',
        'stale_after_seconds': 90,
        'dispatchable': true,
        'blocked_reason': null,
        'active_ride_id': null,
      });

      expect(s.presence, Presence.online);
      expect(s.isBlocked, isFalse);
      expect(s.dispatchable, isTrue);
      expect(s.blockingDocumentTypes, isEmpty);
    });

    test('parses a blocked driver with the documents at fault', () {
      final s = DriverStatus.fromJson({
        'presence': 'offline',
        'stale_after_seconds': 90,
        'dispatchable': false,
        'blocked_reason': 'DOCS_EXPIRED',
        'blocking_document_types': ['vehicle_insurance', 'dbs_check'],
        'active_ride_id': null,
      });

      expect(s.isBlocked, isTrue);
      expect(s.blockedReason, 'DOCS_EXPIRED');
      expect(s.blockingDocumentTypes, ['vehicle_insurance', 'dbs_check']);
    });

    test('maps an unknown presence to offline rather than throwing', () {
      final s = DriverStatus.fromJson({
        'presence': 'something_new',
        'stale_after_seconds': 90,
        'dispatchable': false,
      });
      expect(s.presence, Presence.offline);
    });

    test('carries the active ride so Home can hand off to the trip screen', () {
      final s = DriverStatus.fromJson({
        'presence': 'online',
        'stale_after_seconds': 90,
        'dispatchable': true,
        'active_ride_id': 'ride-1',
      });
      expect(s.activeRideId, 'ride-1');
    });
  });

  group('DriverStatusRepository', () {
    test('reads status', () async {
      when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
          body(
              '{"presence":"online","stale_after_seconds":90,"dispatchable":true}',
              200));

      final r = await repo.status();

      expect(r.valueOrNull!.presence, Presence.online);
    });

    test('goOnline surfaces NOT_ELIGIBLE with its reason and documents',
        () async {
      when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
          '{"code":"NOT_ELIGIBLE","error":"blocked","reason":"DOCS_MISSING",'
          '"blocking_document_types":["private_hire_licence"]}',
          403));

      final r = await repo.goOnline();

      expect(r.errorOrNull!.code, 'NOT_ELIGIBLE');
      expect(r.errorOrNull!.fields['reason'], 'DOCS_MISSING');
      expect(r.errorOrNull!.fields['blocking_document_types'],
          ['private_hire_licence']);
    });

    test("goOnline succeeds on the live shape — an acknowledgement, not a status",
        () async {
      // The handler answers {"message","status"} with NO presence key.
      // Parsing that as a DriverStatus reads as offline — which painted the
      // toggle off on the very success that turned the driver online.
      when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
          body('{"message":"online","status":"online"}', 200));

      final r = await repo.goOnline();

      expect(r.isOk, isTrue);
    });

    test('goOnline surfaces PAYOUT_NOT_READY', () async {
      when(() => adapter.fetch(any(), any(), any())).thenAnswer(
          (_) async => body('{"code":"PAYOUT_NOT_READY","error":"setup"}', 403));

      final r = await repo.goOnline();

      expect(r.errorOrNull!.code, 'PAYOUT_NOT_READY');
    });
  });
}
