// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ride.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Ride {

 String get id;@JsonKey(name: 'rider_id') String get riderId;@JsonKey(name: 'driver_id') String? get driverId;@JsonKey(name: 'vehicle_id') String? get vehicleId;@JsonKey(name: 'fare_id') String? get fareId;@JsonKey(name: 'ride_category') String? get rideCategory;@JsonKey(unknownEnumValue: RideStatus.unknown) RideStatus get status;@JsonKey(name: 'idempotency_key') String? get idempotencyKey;@JsonKey(name: 'created_at') DateTime? get createdAt;@JsonKey(name: 'updated_at') DateTime? get updatedAt;
/// Create a copy of Ride
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RideCopyWith<Ride> get copyWith => _$RideCopyWithImpl<Ride>(this as Ride, _$identity);

  /// Serializes this Ride to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Ride&&(identical(other.id, id) || other.id == id)&&(identical(other.riderId, riderId) || other.riderId == riderId)&&(identical(other.driverId, driverId) || other.driverId == driverId)&&(identical(other.vehicleId, vehicleId) || other.vehicleId == vehicleId)&&(identical(other.fareId, fareId) || other.fareId == fareId)&&(identical(other.rideCategory, rideCategory) || other.rideCategory == rideCategory)&&(identical(other.status, status) || other.status == status)&&(identical(other.idempotencyKey, idempotencyKey) || other.idempotencyKey == idempotencyKey)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,riderId,driverId,vehicleId,fareId,rideCategory,status,idempotencyKey,createdAt,updatedAt);

@override
String toString() {
  return 'Ride(id: $id, riderId: $riderId, driverId: $driverId, vehicleId: $vehicleId, fareId: $fareId, rideCategory: $rideCategory, status: $status, idempotencyKey: $idempotencyKey, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $RideCopyWith<$Res>  {
  factory $RideCopyWith(Ride value, $Res Function(Ride) _then) = _$RideCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'rider_id') String riderId,@JsonKey(name: 'driver_id') String? driverId,@JsonKey(name: 'vehicle_id') String? vehicleId,@JsonKey(name: 'fare_id') String? fareId,@JsonKey(name: 'ride_category') String? rideCategory,@JsonKey(unknownEnumValue: RideStatus.unknown) RideStatus status,@JsonKey(name: 'idempotency_key') String? idempotencyKey,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class _$RideCopyWithImpl<$Res>
    implements $RideCopyWith<$Res> {
  _$RideCopyWithImpl(this._self, this._then);

  final Ride _self;
  final $Res Function(Ride) _then;

/// Create a copy of Ride
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? riderId = null,Object? driverId = freezed,Object? vehicleId = freezed,Object? fareId = freezed,Object? rideCategory = freezed,Object? status = null,Object? idempotencyKey = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,riderId: null == riderId ? _self.riderId : riderId // ignore: cast_nullable_to_non_nullable
as String,driverId: freezed == driverId ? _self.driverId : driverId // ignore: cast_nullable_to_non_nullable
as String?,vehicleId: freezed == vehicleId ? _self.vehicleId : vehicleId // ignore: cast_nullable_to_non_nullable
as String?,fareId: freezed == fareId ? _self.fareId : fareId // ignore: cast_nullable_to_non_nullable
as String?,rideCategory: freezed == rideCategory ? _self.rideCategory : rideCategory // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as RideStatus,idempotencyKey: freezed == idempotencyKey ? _self.idempotencyKey : idempotencyKey // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Ride].
extension RidePatterns on Ride {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Ride value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Ride() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Ride value)  $default,){
final _that = this;
switch (_that) {
case _Ride():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Ride value)?  $default,){
final _that = this;
switch (_that) {
case _Ride() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'rider_id')  String riderId, @JsonKey(name: 'driver_id')  String? driverId, @JsonKey(name: 'vehicle_id')  String? vehicleId, @JsonKey(name: 'fare_id')  String? fareId, @JsonKey(name: 'ride_category')  String? rideCategory, @JsonKey(unknownEnumValue: RideStatus.unknown)  RideStatus status, @JsonKey(name: 'idempotency_key')  String? idempotencyKey, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Ride() when $default != null:
return $default(_that.id,_that.riderId,_that.driverId,_that.vehicleId,_that.fareId,_that.rideCategory,_that.status,_that.idempotencyKey,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'rider_id')  String riderId, @JsonKey(name: 'driver_id')  String? driverId, @JsonKey(name: 'vehicle_id')  String? vehicleId, @JsonKey(name: 'fare_id')  String? fareId, @JsonKey(name: 'ride_category')  String? rideCategory, @JsonKey(unknownEnumValue: RideStatus.unknown)  RideStatus status, @JsonKey(name: 'idempotency_key')  String? idempotencyKey, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Ride():
return $default(_that.id,_that.riderId,_that.driverId,_that.vehicleId,_that.fareId,_that.rideCategory,_that.status,_that.idempotencyKey,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'rider_id')  String riderId, @JsonKey(name: 'driver_id')  String? driverId, @JsonKey(name: 'vehicle_id')  String? vehicleId, @JsonKey(name: 'fare_id')  String? fareId, @JsonKey(name: 'ride_category')  String? rideCategory, @JsonKey(unknownEnumValue: RideStatus.unknown)  RideStatus status, @JsonKey(name: 'idempotency_key')  String? idempotencyKey, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Ride() when $default != null:
return $default(_that.id,_that.riderId,_that.driverId,_that.vehicleId,_that.fareId,_that.rideCategory,_that.status,_that.idempotencyKey,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Ride implements Ride {
  const _Ride({required this.id, @JsonKey(name: 'rider_id') required this.riderId, @JsonKey(name: 'driver_id') this.driverId, @JsonKey(name: 'vehicle_id') this.vehicleId, @JsonKey(name: 'fare_id') this.fareId, @JsonKey(name: 'ride_category') this.rideCategory, @JsonKey(unknownEnumValue: RideStatus.unknown) required this.status, @JsonKey(name: 'idempotency_key') this.idempotencyKey, @JsonKey(name: 'created_at') this.createdAt, @JsonKey(name: 'updated_at') this.updatedAt});
  factory _Ride.fromJson(Map<String, dynamic> json) => _$RideFromJson(json);

@override final  String id;
@override@JsonKey(name: 'rider_id') final  String riderId;
@override@JsonKey(name: 'driver_id') final  String? driverId;
@override@JsonKey(name: 'vehicle_id') final  String? vehicleId;
@override@JsonKey(name: 'fare_id') final  String? fareId;
@override@JsonKey(name: 'ride_category') final  String? rideCategory;
@override@JsonKey(unknownEnumValue: RideStatus.unknown) final  RideStatus status;
@override@JsonKey(name: 'idempotency_key') final  String? idempotencyKey;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;
@override@JsonKey(name: 'updated_at') final  DateTime? updatedAt;

/// Create a copy of Ride
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RideCopyWith<_Ride> get copyWith => __$RideCopyWithImpl<_Ride>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RideToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Ride&&(identical(other.id, id) || other.id == id)&&(identical(other.riderId, riderId) || other.riderId == riderId)&&(identical(other.driverId, driverId) || other.driverId == driverId)&&(identical(other.vehicleId, vehicleId) || other.vehicleId == vehicleId)&&(identical(other.fareId, fareId) || other.fareId == fareId)&&(identical(other.rideCategory, rideCategory) || other.rideCategory == rideCategory)&&(identical(other.status, status) || other.status == status)&&(identical(other.idempotencyKey, idempotencyKey) || other.idempotencyKey == idempotencyKey)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,riderId,driverId,vehicleId,fareId,rideCategory,status,idempotencyKey,createdAt,updatedAt);

@override
String toString() {
  return 'Ride(id: $id, riderId: $riderId, driverId: $driverId, vehicleId: $vehicleId, fareId: $fareId, rideCategory: $rideCategory, status: $status, idempotencyKey: $idempotencyKey, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$RideCopyWith<$Res> implements $RideCopyWith<$Res> {
  factory _$RideCopyWith(_Ride value, $Res Function(_Ride) _then) = __$RideCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'rider_id') String riderId,@JsonKey(name: 'driver_id') String? driverId,@JsonKey(name: 'vehicle_id') String? vehicleId,@JsonKey(name: 'fare_id') String? fareId,@JsonKey(name: 'ride_category') String? rideCategory,@JsonKey(unknownEnumValue: RideStatus.unknown) RideStatus status,@JsonKey(name: 'idempotency_key') String? idempotencyKey,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class __$RideCopyWithImpl<$Res>
    implements _$RideCopyWith<$Res> {
  __$RideCopyWithImpl(this._self, this._then);

  final _Ride _self;
  final $Res Function(_Ride) _then;

/// Create a copy of Ride
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? riderId = null,Object? driverId = freezed,Object? vehicleId = freezed,Object? fareId = freezed,Object? rideCategory = freezed,Object? status = null,Object? idempotencyKey = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_Ride(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,riderId: null == riderId ? _self.riderId : riderId // ignore: cast_nullable_to_non_nullable
as String,driverId: freezed == driverId ? _self.driverId : driverId // ignore: cast_nullable_to_non_nullable
as String?,vehicleId: freezed == vehicleId ? _self.vehicleId : vehicleId // ignore: cast_nullable_to_non_nullable
as String?,fareId: freezed == fareId ? _self.fareId : fareId // ignore: cast_nullable_to_non_nullable
as String?,rideCategory: freezed == rideCategory ? _self.rideCategory : rideCategory // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as RideStatus,idempotencyKey: freezed == idempotencyKey ? _self.idempotencyKey : idempotencyKey // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
