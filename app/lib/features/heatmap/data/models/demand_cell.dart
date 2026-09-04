/// One ~110 m grid square of recent pickup demand.
///
/// [weight] is a raw count of requests in the window, so it is only
/// meaningful against the [DemandHeatmap.maxWeight] it came with — see
/// [DemandHeatmap.intensityOf].
class DemandCell {
  final double lat;
  final double lng;
  final int weight;

  const DemandCell({
    required this.lat,
    required this.lng,
    required this.weight,
  });

  factory DemandCell.fromJson(Map<String, dynamic> json) => DemandCell(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        weight: (json['weight'] as num?)?.toInt() ?? 0,
      );
}

/// The demand picture for one time window, from `GET /demand-heatmap`.
///
/// Advisory only. The Scope Lock Document is explicit that the heatmap "does
/// not override dispatch logic", so nothing here may gate what a driver is
/// offered — it exists to help them choose where to wait.
class DemandHeatmap {
  final List<DemandCell> cells;
  final int maxWeight;
  final int windowHours;

  const DemandHeatmap({
    this.cells = const [],
    this.maxWeight = 0,
    this.windowHours = 0,
  });

  bool get isEmpty => cells.isEmpty;

  /// [cell]'s weight as 0–1 against the busiest cell in the same response.
  ///
  /// The service sends `max_weight` precisely so the colour scale is relative
  /// to the window rather than to an absolute count that means nothing: three
  /// requests is a hotspot at 6am and background noise on a Friday night.
  /// Guards a zero max, which is what an empty window returns.
  double intensityOf(DemandCell cell) {
    if (maxWeight <= 0) return 0;
    final ratio = cell.weight / maxWeight;
    return ratio.clamp(0.0, 1.0);
  }

  factory DemandHeatmap.fromJson(Map<String, dynamic> json) => DemandHeatmap(
        cells: ((json['cells'] as List?) ?? const [])
            .map((e) => DemandCell.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        maxWeight: (json['max_weight'] as num?)?.toInt() ?? 0,
        windowHours: (json['window_hours'] as num?)?.toInt() ?? 0,
      );
}
