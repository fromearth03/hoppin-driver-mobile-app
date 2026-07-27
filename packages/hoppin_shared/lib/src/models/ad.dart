import 'package:freezed_annotation/freezed_annotation.dart';

part 'ad.freezed.dart';
part 'ad.g.dart';

/// An in-app advertisement banner — `GET /ads` (docs/04). Audience-matched
/// server-side from the JWT role (driver → drivers, else riders). Impressions
/// and clicks are reported back and feed the admin CTR/reach metrics.
@freezed
abstract class Ad with _$Ad {
  const factory Ad({
    required String id,
    required String title,
    String? body,
    @JsonKey(name: 'image_url') String? imageUrl,
    @JsonKey(name: 'target_url') String? targetUrl,
    String? audience,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'starts_at') DateTime? startsAt,
    @JsonKey(name: 'ends_at') DateTime? endsAt,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _Ad;

  factory Ad.fromJson(Map<String, dynamic> json) => _$AdFromJson(json);
}
