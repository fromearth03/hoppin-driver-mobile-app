import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/heatmap/data/heatmap_repository.dart';
import 'package:hoppin_driver/features/heatmap/data/models/demand_cell.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

/// Shapes confirmed against production on 2026-09-04:
/// `?hours=168` returned 12 cells with `max_weight: 12`, while `?hours=24`
/// returned `{"cells":[],"max_weight":0}` — an empty window is ordinary, not
/// an error, so it must render as "quiet" rather than as a failure.
void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late HeatmapRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = HeatmapRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  test('reads cells, max weight and the window back', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"cells":[{"lat":52.585,"lng":-2.126,"weight":12},'
        '{"lat":52.586,"lng":-2.126,"weight":7}],'
        '"cell_count":2,"max_weight":12,"window_hours":168}',
        200));

    final r = await repo.demand(hours: 168);

    expect(r.valueOrNull!.cells.length, 2);
    expect(r.valueOrNull!.maxWeight, 12);
    expect(r.valueOrNull!.windowHours, 168);
  });

  test('asks for a day by default, not the service default of two hours',
      () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer(
        (_) async => body('{"cells":[],"max_weight":0,"window_hours":24}', 200));

    await repo.demand();

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .single as RequestOptions;
    expect(sent.queryParameters['hours'], 24);
    expect(sent.queryParameters.containsKey('bbox'), isFalse);
  });

  test('passes a viewport through when given one', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer(
        (_) async => body('{"cells":[],"max_weight":0,"window_hours":24}', 200));

    await repo.demand(bbox: '-2.2,52.5,-2.0,52.7');

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .single as RequestOptions;
    expect(sent.queryParameters['bbox'], '-2.2,52.5,-2.0,52.7');
  });

  test('an empty window is a valid, quiet answer', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
        body('{"cell_count":0,"cells":[],"max_weight":0,"window_hours":24}',
            200));

    final r = await repo.demand();

    expect(r.isOk, isTrue);
    expect(r.valueOrNull!.isEmpty, isTrue);
  });

  group('intensity', () {
    test('scales against the busiest cell in the same window', () {
      const map = DemandHeatmap(
        cells: [
          DemandCell(lat: 0, lng: 0, weight: 12),
          DemandCell(lat: 0, lng: 0, weight: 6),
        ],
        maxWeight: 12,
      );

      expect(map.intensityOf(map.cells[0]), 1.0);
      expect(map.intensityOf(map.cells[1]), 0.5);
    });

    test('a zero max cannot divide by zero', () {
      const map = DemandHeatmap(
        cells: [DemandCell(lat: 0, lng: 0, weight: 0)],
        maxWeight: 0,
      );

      expect(map.intensityOf(map.cells.single), 0);
    });

    test('a weight above the stated max still clamps to one', () {
      const map = DemandHeatmap(
        cells: [DemandCell(lat: 0, lng: 0, weight: 20)],
        maxWeight: 12,
      );

      expect(map.intensityOf(map.cells.single), 1.0);
    });
  });
}
