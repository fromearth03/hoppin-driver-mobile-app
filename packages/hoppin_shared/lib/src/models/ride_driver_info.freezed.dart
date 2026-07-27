// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ride_driver_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RideDriverInfo {

@JsonKey(name: 'full_name') String get fullName;@JsonKey(name: 'photo_url') String? get photoUrl; double get rating;@JsonKey(name: 'trips_count') int get tripsCount;@JsonKey(name: 'vehicle_make') String get vehicleMake;@JsonKey(name: 'vehicle_model') String get vehicleModel;@JsonKey(name: 'vehicle_colour') String get vehicleColour; String get plate;/// Seconds until the driver reaches the pickup — non-null only while a
/// live ride is en route (the demo serves the world's clock-delta value).
@JsonKey(name: 'eta_seconds') int? get etaSeconds;/// Journey origin label (e.g. 'Wolverhampton Rail Station'); null when
/// the route cannot be resolved to a named place.
@JsonKey(name: 'origin_label') String? get originLabel;/// Journey destination label; null when unresolvable.
@JsonKey(name: 'destination_label') String? get destinationLabel;
/// Create a copy of RideDriverInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RideDriverInfoCopyWith<RideDriverInfo> get copyWith => _$RideDriverInfoCopyWithImpl<RideDriverInfo>(this as RideDriverInfo, _$identity);

  /// Serializes this RideDriverInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RideDriverInfo&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.tripsCount, tripsCount) || other.tripsCount == tripsCount)&&(identical(other.vehicleMake, vehicleMake) || other.vehicleMake == vehicleMake)&&(identical(other.vehicleModel, vehicleModel) || other.vehicleModel == vehicleModel)&&(identical(other.vehicleColour, vehicleColour) || other.vehicleColour == vehicleColour)&&(identical(other.plate, plate) || other.plate == plate)&&(identical(other.etaSeconds, etaSeconds) || other.etaSeconds == etaSeconds)&&(identical(other.originLabel, originLabel) || other.originLabel == originLabel)&&(identical(other.destinationLabel, destinationLabel) || other.destinationLabel == destinationLabel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fullName,photoUrl,rating,tripsCount,vehicleMake,vehicleModel,vehicleColour,plate,etaSeconds,originLabel,destinationLabel);

@override
String toString() {
  return 'RideDriverInfo(fullName: $fullName, photoUrl: $photoUrl, rating: $rating, tripsCount: $tripsCount, vehicleMake: $vehicleMake, vehicleModel: $vehicleModel, vehicleColour: $vehicleColour, plate: $plate, etaSeconds: $etaSeconds, originLabel: $originLabel, destinationLabel: $destinationLabel)';
}


}

/// @nodoc
abstract mixin class $RideDriverInfoCopyWith<$Res>  {
  factory $RideDriverInfoCopyWith(RideDriverInfo value, $Res Function(RideDriverInfo) _then) = _$RideDriverInfoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'full_name') String fullName,@JsonKey(name: 'photo_url') String? photoUrl, double rating,@JsonKey(name: 'trips_count') int tripsCount,@JsonKey(name: 'vehicle_make') String vehicleMake,@JsonKey(name: 'vehicle_model') String vehicleModel,@JsonKey(name: 'vehicle_colour') String vehicleColour, String plate,@JsonKey(name: 'eta_seconds') int? etaSeconds,@JsonKey(name: 'origin_label') String? originLabel,@JsonKey(name: 'destination_label') String? destinationLabel
});




}
/// @nodoc
class _$RideDriverInfoCopyWithImpl<$Res>
    implements $RideDriverInfoCopyWith<$Res> {
  _$RideDriverInfoCopyWithImpl(this._self, this._then);

  final RideDriverInfo _self;
  final $Res Function(RideDriverInfo) _then;

/// Create a copy of RideDriverInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fullName = null,Object? photoUrl = freezed,Object? rating = null,Object? tripsCount = null,Object? vehicleMake = null,Object? vehicleModel = null,Object? vehicleColour = null,Object? plate = null,Object? etaSeconds = freezed,Object? originLabel = freezed,Object? destinationLabel = freezed,}) {
  return _then(_self.copyWith(
fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double,tripsCount: null == tripsCount ? _self.tripsCount : tripsCount // ignore: cast_nullable_to_non_nullable
as int,vehicleMake: null == vehicleMake ? _self.vehicleMake : vehicleMake // ignore: cast_nullable_to_non_nullable
as String,vehicleModel: null == vehicleModel ? _self.vehicleModel : vehicleModel // ignore: cast_nullable_to_non_nullable
as String,vehicleColour: null == vehicleColour ? _self.vehicleColour : vehicleColour // ignore: cast_nullable_to_non_nullable
as String,plate: null == plate ? _self.plate : plate // ignore: cast_nullable_to_non_nullable
as String,etaSeconds: freezed == etaSeconds ? _self.etaSeconds : etaSeconds // ignore: cast_nullable_to_non_nullable
as int?,originLabel: freezed == originLabel ? _self.originLabel : originLabel // ignore: cast_nullable_to_non_nullable
as String?,destinationLabel: freezed == destinationLabel ? _self.destinationLabel : destinationLabel // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RideDriverInfo].
extension RideDriverInfoPatterns on RideDriverInfo {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RideDriverInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RideDriverInfo() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RideDriverInfo value)  $default,){
final _that = this;
switch (_that) {
case _RideDriverInfo():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RideDriverInfo value)?  $default,){
final _that = this;
switch (_that) {
case _RideDriverInfo() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'full_name')  String fullName, @JsonKey(name: 'photo_url')  String? photoUrl,  double rating, @JsonKey(name: 'trips_count')  int tripsCount, @JsonKey(name: 'vehicle_make')  String vehicleMake, @JsonKey(name: 'vehicle_model')  String vehicleModel, @JsonKey(name: 'vehicle_colour')  String vehicleColour,  String plate, @JsonKey(name: 'eta_seconds')  int? etaSeconds, @JsonKey(name: 'origin_label')  String? originLabel, @JsonKey(name: 'destination_label')  String? destinationLabel)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RideDriverInfo() when $default != null:
return $default(_that.fullName,_that.photoUrl,_that.rating,_that.tripsCount,_that.vehicleMake,_that.vehicleModel,_that.vehicleColour,_that.plate,_that.etaSeconds,_that.originLabel,_that.destinationLabel);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'full_name')  String fullName, @JsonKey(name: 'photo_url')  String? photoUrl,  double rating, @JsonKey(name: 'trips_count')  int tripsCount, @JsonKey(name: 'vehicle_make')  String vehicleMake, @JsonKey(name: 'vehicle_model')  String vehicleModel, @JsonKey(name: 'vehicle_colour')  String vehicleColour,  String plate, @JsonKey(name: 'eta_seconds')  int? etaSeconds, @JsonKey(name: 'origin_label')  String? originLabel, @JsonKey(name: 'destination_label')  String? destinationLabel)  $default,) {final _that = this;
switch (_that) {
case _RideDriverInfo():
return $default(_that.fullName,_that.photoUrl,_that.rating,_that.tripsCount,_that.vehicleMake,_that.vehicleModel,_that.vehicleColour,_that.plate,_that.etaSeconds,_that.originLabel,_that.destinationLabel);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'full_name')  String fullName, @JsonKey(name: 'photo_url')  String? photoUrl,  double rating, @JsonKey(name: 'trips_count')  int tripsCount, @JsonKey(name: 'vehicle_make')  String vehicleMake, @JsonKey(name: 'vehicle_model')  String vehicleModel, @JsonKey(name: 'vehicle_colour')  String vehicleColour,  String plate, @JsonKey(name: 'eta_seconds')  int? etaSeconds, @JsonKey(name: 'origin_label')  String? originLabel, @JsonKey(name: 'destination_label')  String? destinationLabel)?  $default,) {final _that = this;
switch (_that) {
case _RideDriverInfo() when $default != null:
return $default(_that.fullName,_that.photoUrl,_that.rating,_that.tripsCount,_that.vehicleMake,_that.vehicleModel,_that.vehicleColour,_that.plate,_that.etaSeconds,_that.originLabel,_that.destinationLabel);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RideDriverInfo extends RideDriverInfo {
  const _RideDriverInfo({@JsonKey(name: 'full_name') required this.fullName, @JsonKey(name: 'photo_url') this.photoUrl, required this.rating, @JsonKey(name: 'trips_count') required this.tripsCount, @JsonKey(name: 'vehicle_make') required this.vehicleMake, @JsonKey(name: 'vehicle_model') required this.vehicleModel, @JsonKey(name: 'vehicle_colour') required this.vehicleColour, required this.plate, @JsonKey(name: 'eta_seconds') this.etaSeconds, @JsonKey(name: 'origin_label') this.originLabel, @JsonKey(name: 'destination_label') this.destinationLabel}): super._();
  factory _RideDriverInfo.fromJson(Map<String, dynamic> json) => _$RideDriverInfoFromJson(json);

@override@JsonKey(name: 'full_name') final  String fullName;
@override@JsonKey(name: 'photo_url') final  String? photoUrl;
@override final  double rating;
@override@JsonKey(name: 'trips_count') final  int tripsCount;
@override@JsonKey(name: 'vehicle_make') final  String vehicleMake;
@override@JsonKey(name: 'vehicle_model') final  String vehicleModel;
@override@JsonKey(name: 'vehicle_colour') final  String vehicleColour;
@override final  String plate;
/// Seconds until the driver reaches the pickup — non-null only while a
/// live ride is en route (the demo serves the world's clock-delta value).
@override@JsonKey(name: 'eta_seconds') final  int? etaSeconds;
/// Journey origin label (e.g. 'Wolverhampton Rail Station'); null when
/// the route cannot be resolved to a named place.
@override@JsonKey(name: 'origin_label') final  String? originLabel;
/// Journey destination label; null when unresolvable.
@override@JsonKey(name: 'destination_label') final  String? destinationLabel;

/// Create a copy of RideDriverInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RideDriverInfoCopyWith<_RideDriverInfo> get copyWith => __$RideDriverInfoCopyWithImpl<_RideDriverInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RideDriverInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RideDriverInfo&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.tripsCount, tripsCount) || other.tripsCount == tripsCount)&&(identical(other.vehicleMake, vehicleMake) || other.vehicleMake == vehicleMake)&&(identical(other.vehicleModel, vehicleModel) || other.vehicleModel == vehicleModel)&&(identical(other.vehicleColour, vehicleColour) || other.vehicleColour == vehicleColour)&&(identical(other.plate, plate) || other.plate == plate)&&(identical(other.etaSeconds, etaSeconds) || other.etaSeconds == etaSeconds)&&(identical(other.originLabel, originLabel) || other.originLabel == originLabel)&&(identical(other.destinationLabel, destinationLabel) || other.destinationLabel == destinationLabel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fullName,photoUrl,rating,tripsCount,vehicleMake,vehicleModel,vehicleColour,plate,etaSeconds,originLabel,destinationLabel);

@override
String toString() {
  return 'RideDriverInfo(fullName: $fullName, photoUrl: $photoUrl, rating: $rating, tripsCount: $tripsCount, vehicleMake: $vehicleMake, vehicleModel: $vehicleModel, vehicleColour: $vehicleColour, plate: $plate, etaSeconds: $etaSeconds, originLabel: $originLabel, destinationLabel: $destinationLabel)';
}


}

/// @nodoc
abstract mixin class _$RideDriverInfoCopyWith<$Res> implements $RideDriverInfoCopyWith<$Res> {
  factory _$RideDriverInfoCopyWith(_RideDriverInfo value, $Res Function(_RideDriverInfo) _then) = __$RideDriverInfoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'full_name') String fullName,@JsonKey(name: 'photo_url') String? photoUrl, double rating,@JsonKey(name: 'trips_count') int tripsCount,@JsonKey(name: 'vehicle_make') String vehicleMake,@JsonKey(name: 'vehicle_model') String vehicleModel,@JsonKey(name: 'vehicle_colour') String vehicleColour, String plate,@JsonKey(name: 'eta_seconds') int? etaSeconds,@JsonKey(name: 'origin_label') String? originLabel,@JsonKey(name: 'destination_label') String? destinationLabel
});




}
/// @nodoc
class __$RideDriverInfoCopyWithImpl<$Res>
    implements _$RideDriverInfoCopyWith<$Res> {
  __$RideDriverInfoCopyWithImpl(this._self, this._then);

  final _RideDriverInfo _self;
  final $Res Function(_RideDriverInfo) _then;

/// Create a copy of RideDriverInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fullName = null,Object? photoUrl = freezed,Object? rating = null,Object? tripsCount = null,Object? vehicleMake = null,Object? vehicleModel = null,Object? vehicleColour = null,Object? plate = null,Object? etaSeconds = freezed,Object? originLabel = freezed,Object? destinationLabel = freezed,}) {
  return _then(_RideDriverInfo(
fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double,tripsCount: null == tripsCount ? _self.tripsCount : tripsCount // ignore: cast_nullable_to_non_nullable
as int,vehicleMake: null == vehicleMake ? _self.vehicleMake : vehicleMake // ignore: cast_nullable_to_non_nullable
as String,vehicleModel: null == vehicleModel ? _self.vehicleModel : vehicleModel // ignore: cast_nullable_to_non_nullable
as String,vehicleColour: null == vehicleColour ? _self.vehicleColour : vehicleColour // ignore: cast_nullable_to_non_nullable
as String,plate: null == plate ? _self.plate : plate // ignore: cast_nullable_to_non_nullable
as String,etaSeconds: freezed == etaSeconds ? _self.etaSeconds : etaSeconds // ignore: cast_nullable_to_non_nullable
as int?,originLabel: freezed == originLabel ? _self.originLabel : originLabel // ignore: cast_nullable_to_non_nullable
as String?,destinationLabel: freezed == destinationLabel ? _self.destinationLabel : destinationLabel // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
