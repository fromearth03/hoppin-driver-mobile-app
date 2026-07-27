// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'driver_position.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DriverPosition {

 double get lat; double get lng;/// Degrees clockwise from north, `[0, 360)`; null when the source has no
/// heading (consumers fall back to the track segment's bearing).
 double? get heading;@JsonKey(name: 'updated_at') DateTime get updatedAt;
/// Create a copy of DriverPosition
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DriverPositionCopyWith<DriverPosition> get copyWith => _$DriverPositionCopyWithImpl<DriverPosition>(this as DriverPosition, _$identity);

  /// Serializes this DriverPosition to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DriverPosition&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.heading, heading) || other.heading == heading)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,lat,lng,heading,updatedAt);

@override
String toString() {
  return 'DriverPosition(lat: $lat, lng: $lng, heading: $heading, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $DriverPositionCopyWith<$Res>  {
  factory $DriverPositionCopyWith(DriverPosition value, $Res Function(DriverPosition) _then) = _$DriverPositionCopyWithImpl;
@useResult
$Res call({
 double lat, double lng, double? heading,@JsonKey(name: 'updated_at') DateTime updatedAt
});




}
/// @nodoc
class _$DriverPositionCopyWithImpl<$Res>
    implements $DriverPositionCopyWith<$Res> {
  _$DriverPositionCopyWithImpl(this._self, this._then);

  final DriverPosition _self;
  final $Res Function(DriverPosition) _then;

/// Create a copy of DriverPosition
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lat = null,Object? lng = null,Object? heading = freezed,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,heading: freezed == heading ? _self.heading : heading // ignore: cast_nullable_to_non_nullable
as double?,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [DriverPosition].
extension DriverPositionPatterns on DriverPosition {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DriverPosition value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DriverPosition() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DriverPosition value)  $default,){
final _that = this;
switch (_that) {
case _DriverPosition():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DriverPosition value)?  $default,){
final _that = this;
switch (_that) {
case _DriverPosition() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double lat,  double lng,  double? heading, @JsonKey(name: 'updated_at')  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DriverPosition() when $default != null:
return $default(_that.lat,_that.lng,_that.heading,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double lat,  double lng,  double? heading, @JsonKey(name: 'updated_at')  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _DriverPosition():
return $default(_that.lat,_that.lng,_that.heading,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double lat,  double lng,  double? heading, @JsonKey(name: 'updated_at')  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _DriverPosition() when $default != null:
return $default(_that.lat,_that.lng,_that.heading,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DriverPosition implements DriverPosition {
  const _DriverPosition({required this.lat, required this.lng, this.heading, @JsonKey(name: 'updated_at') required this.updatedAt});
  factory _DriverPosition.fromJson(Map<String, dynamic> json) => _$DriverPositionFromJson(json);

@override final  double lat;
@override final  double lng;
/// Degrees clockwise from north, `[0, 360)`; null when the source has no
/// heading (consumers fall back to the track segment's bearing).
@override final  double? heading;
@override@JsonKey(name: 'updated_at') final  DateTime updatedAt;

/// Create a copy of DriverPosition
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DriverPositionCopyWith<_DriverPosition> get copyWith => __$DriverPositionCopyWithImpl<_DriverPosition>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DriverPositionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DriverPosition&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.heading, heading) || other.heading == heading)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,lat,lng,heading,updatedAt);

@override
String toString() {
  return 'DriverPosition(lat: $lat, lng: $lng, heading: $heading, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$DriverPositionCopyWith<$Res> implements $DriverPositionCopyWith<$Res> {
  factory _$DriverPositionCopyWith(_DriverPosition value, $Res Function(_DriverPosition) _then) = __$DriverPositionCopyWithImpl;
@override @useResult
$Res call({
 double lat, double lng, double? heading,@JsonKey(name: 'updated_at') DateTime updatedAt
});




}
/// @nodoc
class __$DriverPositionCopyWithImpl<$Res>
    implements _$DriverPositionCopyWith<$Res> {
  __$DriverPositionCopyWithImpl(this._self, this._then);

  final _DriverPosition _self;
  final $Res Function(_DriverPosition) _then;

/// Create a copy of DriverPosition
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lat = null,Object? lng = null,Object? heading = freezed,Object? updatedAt = null,}) {
  return _then(_DriverPosition(
lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,heading: freezed == heading ? _self.heading : heading // ignore: cast_nullable_to_non_nullable
as double?,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
