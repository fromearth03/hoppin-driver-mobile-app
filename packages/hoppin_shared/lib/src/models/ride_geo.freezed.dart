// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ride_geo.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GeoPoint {

 double get lat; double get lng;
/// Create a copy of GeoPoint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GeoPointCopyWith<GeoPoint> get copyWith => _$GeoPointCopyWithImpl<GeoPoint>(this as GeoPoint, _$identity);

  /// Serializes this GeoPoint to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GeoPoint&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,lat,lng);

@override
String toString() {
  return 'GeoPoint(lat: $lat, lng: $lng)';
}


}

/// @nodoc
abstract mixin class $GeoPointCopyWith<$Res>  {
  factory $GeoPointCopyWith(GeoPoint value, $Res Function(GeoPoint) _then) = _$GeoPointCopyWithImpl;
@useResult
$Res call({
 double lat, double lng
});




}
/// @nodoc
class _$GeoPointCopyWithImpl<$Res>
    implements $GeoPointCopyWith<$Res> {
  _$GeoPointCopyWithImpl(this._self, this._then);

  final GeoPoint _self;
  final $Res Function(GeoPoint) _then;

/// Create a copy of GeoPoint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lat = null,Object? lng = null,}) {
  return _then(_self.copyWith(
lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [GeoPoint].
extension GeoPointPatterns on GeoPoint {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GeoPoint value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GeoPoint() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GeoPoint value)  $default,){
final _that = this;
switch (_that) {
case _GeoPoint():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GeoPoint value)?  $default,){
final _that = this;
switch (_that) {
case _GeoPoint() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double lat,  double lng)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GeoPoint() when $default != null:
return $default(_that.lat,_that.lng);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double lat,  double lng)  $default,) {final _that = this;
switch (_that) {
case _GeoPoint():
return $default(_that.lat,_that.lng);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double lat,  double lng)?  $default,) {final _that = this;
switch (_that) {
case _GeoPoint() when $default != null:
return $default(_that.lat,_that.lng);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GeoPoint implements GeoPoint {
  const _GeoPoint({required this.lat, required this.lng});
  factory _GeoPoint.fromJson(Map<String, dynamic> json) => _$GeoPointFromJson(json);

@override final  double lat;
@override final  double lng;

/// Create a copy of GeoPoint
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GeoPointCopyWith<_GeoPoint> get copyWith => __$GeoPointCopyWithImpl<_GeoPoint>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GeoPointToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GeoPoint&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,lat,lng);

@override
String toString() {
  return 'GeoPoint(lat: $lat, lng: $lng)';
}


}

/// @nodoc
abstract mixin class _$GeoPointCopyWith<$Res> implements $GeoPointCopyWith<$Res> {
  factory _$GeoPointCopyWith(_GeoPoint value, $Res Function(_GeoPoint) _then) = __$GeoPointCopyWithImpl;
@override @useResult
$Res call({
 double lat, double lng
});




}
/// @nodoc
class __$GeoPointCopyWithImpl<$Res>
    implements _$GeoPointCopyWith<$Res> {
  __$GeoPointCopyWithImpl(this._self, this._then);

  final _GeoPoint _self;
  final $Res Function(_GeoPoint) _then;

/// Create a copy of GeoPoint
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lat = null,Object? lng = null,}) {
  return _then(_GeoPoint(
lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$RideGeo {

@JsonKey(name: 'pickup_lat') double get pickupLat;@JsonKey(name: 'pickup_lng') double get pickupLng;@JsonKey(name: 'dropoff_lat') double get dropoffLat;@JsonKey(name: 'dropoff_lng') double get dropoffLng;/// The pickup→dropoff route polyline, ordered.
 List<GeoPoint> get route;/// The driver-start→pickup approach polyline; null when unknown.
 List<GeoPoint>? get approach;
/// Create a copy of RideGeo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RideGeoCopyWith<RideGeo> get copyWith => _$RideGeoCopyWithImpl<RideGeo>(this as RideGeo, _$identity);

  /// Serializes this RideGeo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RideGeo&&(identical(other.pickupLat, pickupLat) || other.pickupLat == pickupLat)&&(identical(other.pickupLng, pickupLng) || other.pickupLng == pickupLng)&&(identical(other.dropoffLat, dropoffLat) || other.dropoffLat == dropoffLat)&&(identical(other.dropoffLng, dropoffLng) || other.dropoffLng == dropoffLng)&&const DeepCollectionEquality().equals(other.route, route)&&const DeepCollectionEquality().equals(other.approach, approach));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pickupLat,pickupLng,dropoffLat,dropoffLng,const DeepCollectionEquality().hash(route),const DeepCollectionEquality().hash(approach));

@override
String toString() {
  return 'RideGeo(pickupLat: $pickupLat, pickupLng: $pickupLng, dropoffLat: $dropoffLat, dropoffLng: $dropoffLng, route: $route, approach: $approach)';
}


}

/// @nodoc
abstract mixin class $RideGeoCopyWith<$Res>  {
  factory $RideGeoCopyWith(RideGeo value, $Res Function(RideGeo) _then) = _$RideGeoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'pickup_lat') double pickupLat,@JsonKey(name: 'pickup_lng') double pickupLng,@JsonKey(name: 'dropoff_lat') double dropoffLat,@JsonKey(name: 'dropoff_lng') double dropoffLng, List<GeoPoint> route, List<GeoPoint>? approach
});




}
/// @nodoc
class _$RideGeoCopyWithImpl<$Res>
    implements $RideGeoCopyWith<$Res> {
  _$RideGeoCopyWithImpl(this._self, this._then);

  final RideGeo _self;
  final $Res Function(RideGeo) _then;

/// Create a copy of RideGeo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pickupLat = null,Object? pickupLng = null,Object? dropoffLat = null,Object? dropoffLng = null,Object? route = null,Object? approach = freezed,}) {
  return _then(_self.copyWith(
pickupLat: null == pickupLat ? _self.pickupLat : pickupLat // ignore: cast_nullable_to_non_nullable
as double,pickupLng: null == pickupLng ? _self.pickupLng : pickupLng // ignore: cast_nullable_to_non_nullable
as double,dropoffLat: null == dropoffLat ? _self.dropoffLat : dropoffLat // ignore: cast_nullable_to_non_nullable
as double,dropoffLng: null == dropoffLng ? _self.dropoffLng : dropoffLng // ignore: cast_nullable_to_non_nullable
as double,route: null == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as List<GeoPoint>,approach: freezed == approach ? _self.approach : approach // ignore: cast_nullable_to_non_nullable
as List<GeoPoint>?,
  ));
}

}


/// Adds pattern-matching-related methods to [RideGeo].
extension RideGeoPatterns on RideGeo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RideGeo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RideGeo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RideGeo value)  $default,){
final _that = this;
switch (_that) {
case _RideGeo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RideGeo value)?  $default,){
final _that = this;
switch (_that) {
case _RideGeo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'pickup_lat')  double pickupLat, @JsonKey(name: 'pickup_lng')  double pickupLng, @JsonKey(name: 'dropoff_lat')  double dropoffLat, @JsonKey(name: 'dropoff_lng')  double dropoffLng,  List<GeoPoint> route,  List<GeoPoint>? approach)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RideGeo() when $default != null:
return $default(_that.pickupLat,_that.pickupLng,_that.dropoffLat,_that.dropoffLng,_that.route,_that.approach);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'pickup_lat')  double pickupLat, @JsonKey(name: 'pickup_lng')  double pickupLng, @JsonKey(name: 'dropoff_lat')  double dropoffLat, @JsonKey(name: 'dropoff_lng')  double dropoffLng,  List<GeoPoint> route,  List<GeoPoint>? approach)  $default,) {final _that = this;
switch (_that) {
case _RideGeo():
return $default(_that.pickupLat,_that.pickupLng,_that.dropoffLat,_that.dropoffLng,_that.route,_that.approach);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'pickup_lat')  double pickupLat, @JsonKey(name: 'pickup_lng')  double pickupLng, @JsonKey(name: 'dropoff_lat')  double dropoffLat, @JsonKey(name: 'dropoff_lng')  double dropoffLng,  List<GeoPoint> route,  List<GeoPoint>? approach)?  $default,) {final _that = this;
switch (_that) {
case _RideGeo() when $default != null:
return $default(_that.pickupLat,_that.pickupLng,_that.dropoffLat,_that.dropoffLng,_that.route,_that.approach);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RideGeo implements RideGeo {
  const _RideGeo({@JsonKey(name: 'pickup_lat') required this.pickupLat, @JsonKey(name: 'pickup_lng') required this.pickupLng, @JsonKey(name: 'dropoff_lat') required this.dropoffLat, @JsonKey(name: 'dropoff_lng') required this.dropoffLng, required final  List<GeoPoint> route, final  List<GeoPoint>? approach}): _route = route,_approach = approach;
  factory _RideGeo.fromJson(Map<String, dynamic> json) => _$RideGeoFromJson(json);

@override@JsonKey(name: 'pickup_lat') final  double pickupLat;
@override@JsonKey(name: 'pickup_lng') final  double pickupLng;
@override@JsonKey(name: 'dropoff_lat') final  double dropoffLat;
@override@JsonKey(name: 'dropoff_lng') final  double dropoffLng;
/// The pickup→dropoff route polyline, ordered.
 final  List<GeoPoint> _route;
/// The pickup→dropoff route polyline, ordered.
@override List<GeoPoint> get route {
  if (_route is EqualUnmodifiableListView) return _route;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_route);
}

/// The driver-start→pickup approach polyline; null when unknown.
 final  List<GeoPoint>? _approach;
/// The driver-start→pickup approach polyline; null when unknown.
@override List<GeoPoint>? get approach {
  final value = _approach;
  if (value == null) return null;
  if (_approach is EqualUnmodifiableListView) return _approach;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of RideGeo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RideGeoCopyWith<_RideGeo> get copyWith => __$RideGeoCopyWithImpl<_RideGeo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RideGeoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RideGeo&&(identical(other.pickupLat, pickupLat) || other.pickupLat == pickupLat)&&(identical(other.pickupLng, pickupLng) || other.pickupLng == pickupLng)&&(identical(other.dropoffLat, dropoffLat) || other.dropoffLat == dropoffLat)&&(identical(other.dropoffLng, dropoffLng) || other.dropoffLng == dropoffLng)&&const DeepCollectionEquality().equals(other._route, _route)&&const DeepCollectionEquality().equals(other._approach, _approach));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pickupLat,pickupLng,dropoffLat,dropoffLng,const DeepCollectionEquality().hash(_route),const DeepCollectionEquality().hash(_approach));

@override
String toString() {
  return 'RideGeo(pickupLat: $pickupLat, pickupLng: $pickupLng, dropoffLat: $dropoffLat, dropoffLng: $dropoffLng, route: $route, approach: $approach)';
}


}

/// @nodoc
abstract mixin class _$RideGeoCopyWith<$Res> implements $RideGeoCopyWith<$Res> {
  factory _$RideGeoCopyWith(_RideGeo value, $Res Function(_RideGeo) _then) = __$RideGeoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'pickup_lat') double pickupLat,@JsonKey(name: 'pickup_lng') double pickupLng,@JsonKey(name: 'dropoff_lat') double dropoffLat,@JsonKey(name: 'dropoff_lng') double dropoffLng, List<GeoPoint> route, List<GeoPoint>? approach
});




}
/// @nodoc
class __$RideGeoCopyWithImpl<$Res>
    implements _$RideGeoCopyWith<$Res> {
  __$RideGeoCopyWithImpl(this._self, this._then);

  final _RideGeo _self;
  final $Res Function(_RideGeo) _then;

/// Create a copy of RideGeo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pickupLat = null,Object? pickupLng = null,Object? dropoffLat = null,Object? dropoffLng = null,Object? route = null,Object? approach = freezed,}) {
  return _then(_RideGeo(
pickupLat: null == pickupLat ? _self.pickupLat : pickupLat // ignore: cast_nullable_to_non_nullable
as double,pickupLng: null == pickupLng ? _self.pickupLng : pickupLng // ignore: cast_nullable_to_non_nullable
as double,dropoffLat: null == dropoffLat ? _self.dropoffLat : dropoffLat // ignore: cast_nullable_to_non_nullable
as double,dropoffLng: null == dropoffLng ? _self.dropoffLng : dropoffLng // ignore: cast_nullable_to_non_nullable
as double,route: null == route ? _self._route : route // ignore: cast_nullable_to_non_nullable
as List<GeoPoint>,approach: freezed == approach ? _self._approach : approach // ignore: cast_nullable_to_non_nullable
as List<GeoPoint>?,
  ));
}


}

// dart format on
