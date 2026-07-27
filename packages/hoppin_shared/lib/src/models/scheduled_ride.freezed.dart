// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scheduled_ride.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ScheduledRide {

 String get id;@JsonKey(name: 'rider_id') String? get riderId;@JsonKey(name: 'requested_pickup_time') DateTime get requestedPickupTime;@JsonKey(name: 'estimated_fare_id') String? get estimatedFareId; String get status;@JsonKey(name: 'active_ride_id') String? get activeRideId;
/// Create a copy of ScheduledRide
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduledRideCopyWith<ScheduledRide> get copyWith => _$ScheduledRideCopyWithImpl<ScheduledRide>(this as ScheduledRide, _$identity);

  /// Serializes this ScheduledRide to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledRide&&(identical(other.id, id) || other.id == id)&&(identical(other.riderId, riderId) || other.riderId == riderId)&&(identical(other.requestedPickupTime, requestedPickupTime) || other.requestedPickupTime == requestedPickupTime)&&(identical(other.estimatedFareId, estimatedFareId) || other.estimatedFareId == estimatedFareId)&&(identical(other.status, status) || other.status == status)&&(identical(other.activeRideId, activeRideId) || other.activeRideId == activeRideId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,riderId,requestedPickupTime,estimatedFareId,status,activeRideId);

@override
String toString() {
  return 'ScheduledRide(id: $id, riderId: $riderId, requestedPickupTime: $requestedPickupTime, estimatedFareId: $estimatedFareId, status: $status, activeRideId: $activeRideId)';
}


}

/// @nodoc
abstract mixin class $ScheduledRideCopyWith<$Res>  {
  factory $ScheduledRideCopyWith(ScheduledRide value, $Res Function(ScheduledRide) _then) = _$ScheduledRideCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'rider_id') String? riderId,@JsonKey(name: 'requested_pickup_time') DateTime requestedPickupTime,@JsonKey(name: 'estimated_fare_id') String? estimatedFareId, String status,@JsonKey(name: 'active_ride_id') String? activeRideId
});




}
/// @nodoc
class _$ScheduledRideCopyWithImpl<$Res>
    implements $ScheduledRideCopyWith<$Res> {
  _$ScheduledRideCopyWithImpl(this._self, this._then);

  final ScheduledRide _self;
  final $Res Function(ScheduledRide) _then;

/// Create a copy of ScheduledRide
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? riderId = freezed,Object? requestedPickupTime = null,Object? estimatedFareId = freezed,Object? status = null,Object? activeRideId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,riderId: freezed == riderId ? _self.riderId : riderId // ignore: cast_nullable_to_non_nullable
as String?,requestedPickupTime: null == requestedPickupTime ? _self.requestedPickupTime : requestedPickupTime // ignore: cast_nullable_to_non_nullable
as DateTime,estimatedFareId: freezed == estimatedFareId ? _self.estimatedFareId : estimatedFareId // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,activeRideId: freezed == activeRideId ? _self.activeRideId : activeRideId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ScheduledRide].
extension ScheduledRidePatterns on ScheduledRide {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScheduledRide value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScheduledRide() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScheduledRide value)  $default,){
final _that = this;
switch (_that) {
case _ScheduledRide():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScheduledRide value)?  $default,){
final _that = this;
switch (_that) {
case _ScheduledRide() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'rider_id')  String? riderId, @JsonKey(name: 'requested_pickup_time')  DateTime requestedPickupTime, @JsonKey(name: 'estimated_fare_id')  String? estimatedFareId,  String status, @JsonKey(name: 'active_ride_id')  String? activeRideId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScheduledRide() when $default != null:
return $default(_that.id,_that.riderId,_that.requestedPickupTime,_that.estimatedFareId,_that.status,_that.activeRideId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'rider_id')  String? riderId, @JsonKey(name: 'requested_pickup_time')  DateTime requestedPickupTime, @JsonKey(name: 'estimated_fare_id')  String? estimatedFareId,  String status, @JsonKey(name: 'active_ride_id')  String? activeRideId)  $default,) {final _that = this;
switch (_that) {
case _ScheduledRide():
return $default(_that.id,_that.riderId,_that.requestedPickupTime,_that.estimatedFareId,_that.status,_that.activeRideId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'rider_id')  String? riderId, @JsonKey(name: 'requested_pickup_time')  DateTime requestedPickupTime, @JsonKey(name: 'estimated_fare_id')  String? estimatedFareId,  String status, @JsonKey(name: 'active_ride_id')  String? activeRideId)?  $default,) {final _that = this;
switch (_that) {
case _ScheduledRide() when $default != null:
return $default(_that.id,_that.riderId,_that.requestedPickupTime,_that.estimatedFareId,_that.status,_that.activeRideId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ScheduledRide implements ScheduledRide {
  const _ScheduledRide({required this.id, @JsonKey(name: 'rider_id') this.riderId, @JsonKey(name: 'requested_pickup_time') required this.requestedPickupTime, @JsonKey(name: 'estimated_fare_id') this.estimatedFareId, this.status = 'pending', @JsonKey(name: 'active_ride_id') this.activeRideId});
  factory _ScheduledRide.fromJson(Map<String, dynamic> json) => _$ScheduledRideFromJson(json);

@override final  String id;
@override@JsonKey(name: 'rider_id') final  String? riderId;
@override@JsonKey(name: 'requested_pickup_time') final  DateTime requestedPickupTime;
@override@JsonKey(name: 'estimated_fare_id') final  String? estimatedFareId;
@override@JsonKey() final  String status;
@override@JsonKey(name: 'active_ride_id') final  String? activeRideId;

/// Create a copy of ScheduledRide
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScheduledRideCopyWith<_ScheduledRide> get copyWith => __$ScheduledRideCopyWithImpl<_ScheduledRide>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScheduledRideToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScheduledRide&&(identical(other.id, id) || other.id == id)&&(identical(other.riderId, riderId) || other.riderId == riderId)&&(identical(other.requestedPickupTime, requestedPickupTime) || other.requestedPickupTime == requestedPickupTime)&&(identical(other.estimatedFareId, estimatedFareId) || other.estimatedFareId == estimatedFareId)&&(identical(other.status, status) || other.status == status)&&(identical(other.activeRideId, activeRideId) || other.activeRideId == activeRideId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,riderId,requestedPickupTime,estimatedFareId,status,activeRideId);

@override
String toString() {
  return 'ScheduledRide(id: $id, riderId: $riderId, requestedPickupTime: $requestedPickupTime, estimatedFareId: $estimatedFareId, status: $status, activeRideId: $activeRideId)';
}


}

/// @nodoc
abstract mixin class _$ScheduledRideCopyWith<$Res> implements $ScheduledRideCopyWith<$Res> {
  factory _$ScheduledRideCopyWith(_ScheduledRide value, $Res Function(_ScheduledRide) _then) = __$ScheduledRideCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'rider_id') String? riderId,@JsonKey(name: 'requested_pickup_time') DateTime requestedPickupTime,@JsonKey(name: 'estimated_fare_id') String? estimatedFareId, String status,@JsonKey(name: 'active_ride_id') String? activeRideId
});




}
/// @nodoc
class __$ScheduledRideCopyWithImpl<$Res>
    implements _$ScheduledRideCopyWith<$Res> {
  __$ScheduledRideCopyWithImpl(this._self, this._then);

  final _ScheduledRide _self;
  final $Res Function(_ScheduledRide) _then;

/// Create a copy of ScheduledRide
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? riderId = freezed,Object? requestedPickupTime = null,Object? estimatedFareId = freezed,Object? status = null,Object? activeRideId = freezed,}) {
  return _then(_ScheduledRide(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,riderId: freezed == riderId ? _self.riderId : riderId // ignore: cast_nullable_to_non_nullable
as String?,requestedPickupTime: null == requestedPickupTime ? _self.requestedPickupTime : requestedPickupTime // ignore: cast_nullable_to_non_nullable
as DateTime,estimatedFareId: freezed == estimatedFareId ? _self.estimatedFareId : estimatedFareId // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,activeRideId: freezed == activeRideId ? _self.activeRideId : activeRideId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
