// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ride_offer.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RideOffer {

@JsonKey(name: 'offer_id') String get offerId;@JsonKey(name: 'ride_id') String get rideId;@JsonKey(name: 'pickup_lat') double get pickupLat;@JsonKey(name: 'pickup_lng') double get pickupLng;@JsonKey(name: 'dropoff_lat') double get dropoffLat;@JsonKey(name: 'dropoff_lng') double get dropoffLng; double get fare;@JsonKey(name: 'estimated_miles') double get estimatedMiles;@JsonKey(name: 'expires_at') DateTime get expiresAt;@JsonKey(name: 'offered_at') DateTime get offeredAt;
/// Create a copy of RideOffer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RideOfferCopyWith<RideOffer> get copyWith => _$RideOfferCopyWithImpl<RideOffer>(this as RideOffer, _$identity);

  /// Serializes this RideOffer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RideOffer&&(identical(other.offerId, offerId) || other.offerId == offerId)&&(identical(other.rideId, rideId) || other.rideId == rideId)&&(identical(other.pickupLat, pickupLat) || other.pickupLat == pickupLat)&&(identical(other.pickupLng, pickupLng) || other.pickupLng == pickupLng)&&(identical(other.dropoffLat, dropoffLat) || other.dropoffLat == dropoffLat)&&(identical(other.dropoffLng, dropoffLng) || other.dropoffLng == dropoffLng)&&(identical(other.fare, fare) || other.fare == fare)&&(identical(other.estimatedMiles, estimatedMiles) || other.estimatedMiles == estimatedMiles)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.offeredAt, offeredAt) || other.offeredAt == offeredAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,offerId,rideId,pickupLat,pickupLng,dropoffLat,dropoffLng,fare,estimatedMiles,expiresAt,offeredAt);

@override
String toString() {
  return 'RideOffer(offerId: $offerId, rideId: $rideId, pickupLat: $pickupLat, pickupLng: $pickupLng, dropoffLat: $dropoffLat, dropoffLng: $dropoffLng, fare: $fare, estimatedMiles: $estimatedMiles, expiresAt: $expiresAt, offeredAt: $offeredAt)';
}


}

/// @nodoc
abstract mixin class $RideOfferCopyWith<$Res>  {
  factory $RideOfferCopyWith(RideOffer value, $Res Function(RideOffer) _then) = _$RideOfferCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'offer_id') String offerId,@JsonKey(name: 'ride_id') String rideId,@JsonKey(name: 'pickup_lat') double pickupLat,@JsonKey(name: 'pickup_lng') double pickupLng,@JsonKey(name: 'dropoff_lat') double dropoffLat,@JsonKey(name: 'dropoff_lng') double dropoffLng, double fare,@JsonKey(name: 'estimated_miles') double estimatedMiles,@JsonKey(name: 'expires_at') DateTime expiresAt,@JsonKey(name: 'offered_at') DateTime offeredAt
});




}
/// @nodoc
class _$RideOfferCopyWithImpl<$Res>
    implements $RideOfferCopyWith<$Res> {
  _$RideOfferCopyWithImpl(this._self, this._then);

  final RideOffer _self;
  final $Res Function(RideOffer) _then;

/// Create a copy of RideOffer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? offerId = null,Object? rideId = null,Object? pickupLat = null,Object? pickupLng = null,Object? dropoffLat = null,Object? dropoffLng = null,Object? fare = null,Object? estimatedMiles = null,Object? expiresAt = null,Object? offeredAt = null,}) {
  return _then(_self.copyWith(
offerId: null == offerId ? _self.offerId : offerId // ignore: cast_nullable_to_non_nullable
as String,rideId: null == rideId ? _self.rideId : rideId // ignore: cast_nullable_to_non_nullable
as String,pickupLat: null == pickupLat ? _self.pickupLat : pickupLat // ignore: cast_nullable_to_non_nullable
as double,pickupLng: null == pickupLng ? _self.pickupLng : pickupLng // ignore: cast_nullable_to_non_nullable
as double,dropoffLat: null == dropoffLat ? _self.dropoffLat : dropoffLat // ignore: cast_nullable_to_non_nullable
as double,dropoffLng: null == dropoffLng ? _self.dropoffLng : dropoffLng // ignore: cast_nullable_to_non_nullable
as double,fare: null == fare ? _self.fare : fare // ignore: cast_nullable_to_non_nullable
as double,estimatedMiles: null == estimatedMiles ? _self.estimatedMiles : estimatedMiles // ignore: cast_nullable_to_non_nullable
as double,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,offeredAt: null == offeredAt ? _self.offeredAt : offeredAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [RideOffer].
extension RideOfferPatterns on RideOffer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RideOffer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RideOffer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RideOffer value)  $default,){
final _that = this;
switch (_that) {
case _RideOffer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RideOffer value)?  $default,){
final _that = this;
switch (_that) {
case _RideOffer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'offer_id')  String offerId, @JsonKey(name: 'ride_id')  String rideId, @JsonKey(name: 'pickup_lat')  double pickupLat, @JsonKey(name: 'pickup_lng')  double pickupLng, @JsonKey(name: 'dropoff_lat')  double dropoffLat, @JsonKey(name: 'dropoff_lng')  double dropoffLng,  double fare, @JsonKey(name: 'estimated_miles')  double estimatedMiles, @JsonKey(name: 'expires_at')  DateTime expiresAt, @JsonKey(name: 'offered_at')  DateTime offeredAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RideOffer() when $default != null:
return $default(_that.offerId,_that.rideId,_that.pickupLat,_that.pickupLng,_that.dropoffLat,_that.dropoffLng,_that.fare,_that.estimatedMiles,_that.expiresAt,_that.offeredAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'offer_id')  String offerId, @JsonKey(name: 'ride_id')  String rideId, @JsonKey(name: 'pickup_lat')  double pickupLat, @JsonKey(name: 'pickup_lng')  double pickupLng, @JsonKey(name: 'dropoff_lat')  double dropoffLat, @JsonKey(name: 'dropoff_lng')  double dropoffLng,  double fare, @JsonKey(name: 'estimated_miles')  double estimatedMiles, @JsonKey(name: 'expires_at')  DateTime expiresAt, @JsonKey(name: 'offered_at')  DateTime offeredAt)  $default,) {final _that = this;
switch (_that) {
case _RideOffer():
return $default(_that.offerId,_that.rideId,_that.pickupLat,_that.pickupLng,_that.dropoffLat,_that.dropoffLng,_that.fare,_that.estimatedMiles,_that.expiresAt,_that.offeredAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'offer_id')  String offerId, @JsonKey(name: 'ride_id')  String rideId, @JsonKey(name: 'pickup_lat')  double pickupLat, @JsonKey(name: 'pickup_lng')  double pickupLng, @JsonKey(name: 'dropoff_lat')  double dropoffLat, @JsonKey(name: 'dropoff_lng')  double dropoffLng,  double fare, @JsonKey(name: 'estimated_miles')  double estimatedMiles, @JsonKey(name: 'expires_at')  DateTime expiresAt, @JsonKey(name: 'offered_at')  DateTime offeredAt)?  $default,) {final _that = this;
switch (_that) {
case _RideOffer() when $default != null:
return $default(_that.offerId,_that.rideId,_that.pickupLat,_that.pickupLng,_that.dropoffLat,_that.dropoffLng,_that.fare,_that.estimatedMiles,_that.expiresAt,_that.offeredAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RideOffer implements RideOffer {
  const _RideOffer({@JsonKey(name: 'offer_id') required this.offerId, @JsonKey(name: 'ride_id') required this.rideId, @JsonKey(name: 'pickup_lat') required this.pickupLat, @JsonKey(name: 'pickup_lng') required this.pickupLng, @JsonKey(name: 'dropoff_lat') required this.dropoffLat, @JsonKey(name: 'dropoff_lng') required this.dropoffLng, required this.fare, @JsonKey(name: 'estimated_miles') required this.estimatedMiles, @JsonKey(name: 'expires_at') required this.expiresAt, @JsonKey(name: 'offered_at') required this.offeredAt});
  factory _RideOffer.fromJson(Map<String, dynamic> json) => _$RideOfferFromJson(json);

@override@JsonKey(name: 'offer_id') final  String offerId;
@override@JsonKey(name: 'ride_id') final  String rideId;
@override@JsonKey(name: 'pickup_lat') final  double pickupLat;
@override@JsonKey(name: 'pickup_lng') final  double pickupLng;
@override@JsonKey(name: 'dropoff_lat') final  double dropoffLat;
@override@JsonKey(name: 'dropoff_lng') final  double dropoffLng;
@override final  double fare;
@override@JsonKey(name: 'estimated_miles') final  double estimatedMiles;
@override@JsonKey(name: 'expires_at') final  DateTime expiresAt;
@override@JsonKey(name: 'offered_at') final  DateTime offeredAt;

/// Create a copy of RideOffer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RideOfferCopyWith<_RideOffer> get copyWith => __$RideOfferCopyWithImpl<_RideOffer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RideOfferToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RideOffer&&(identical(other.offerId, offerId) || other.offerId == offerId)&&(identical(other.rideId, rideId) || other.rideId == rideId)&&(identical(other.pickupLat, pickupLat) || other.pickupLat == pickupLat)&&(identical(other.pickupLng, pickupLng) || other.pickupLng == pickupLng)&&(identical(other.dropoffLat, dropoffLat) || other.dropoffLat == dropoffLat)&&(identical(other.dropoffLng, dropoffLng) || other.dropoffLng == dropoffLng)&&(identical(other.fare, fare) || other.fare == fare)&&(identical(other.estimatedMiles, estimatedMiles) || other.estimatedMiles == estimatedMiles)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.offeredAt, offeredAt) || other.offeredAt == offeredAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,offerId,rideId,pickupLat,pickupLng,dropoffLat,dropoffLng,fare,estimatedMiles,expiresAt,offeredAt);

@override
String toString() {
  return 'RideOffer(offerId: $offerId, rideId: $rideId, pickupLat: $pickupLat, pickupLng: $pickupLng, dropoffLat: $dropoffLat, dropoffLng: $dropoffLng, fare: $fare, estimatedMiles: $estimatedMiles, expiresAt: $expiresAt, offeredAt: $offeredAt)';
}


}

/// @nodoc
abstract mixin class _$RideOfferCopyWith<$Res> implements $RideOfferCopyWith<$Res> {
  factory _$RideOfferCopyWith(_RideOffer value, $Res Function(_RideOffer) _then) = __$RideOfferCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'offer_id') String offerId,@JsonKey(name: 'ride_id') String rideId,@JsonKey(name: 'pickup_lat') double pickupLat,@JsonKey(name: 'pickup_lng') double pickupLng,@JsonKey(name: 'dropoff_lat') double dropoffLat,@JsonKey(name: 'dropoff_lng') double dropoffLng, double fare,@JsonKey(name: 'estimated_miles') double estimatedMiles,@JsonKey(name: 'expires_at') DateTime expiresAt,@JsonKey(name: 'offered_at') DateTime offeredAt
});




}
/// @nodoc
class __$RideOfferCopyWithImpl<$Res>
    implements _$RideOfferCopyWith<$Res> {
  __$RideOfferCopyWithImpl(this._self, this._then);

  final _RideOffer _self;
  final $Res Function(_RideOffer) _then;

/// Create a copy of RideOffer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? offerId = null,Object? rideId = null,Object? pickupLat = null,Object? pickupLng = null,Object? dropoffLat = null,Object? dropoffLng = null,Object? fare = null,Object? estimatedMiles = null,Object? expiresAt = null,Object? offeredAt = null,}) {
  return _then(_RideOffer(
offerId: null == offerId ? _self.offerId : offerId // ignore: cast_nullable_to_non_nullable
as String,rideId: null == rideId ? _self.rideId : rideId // ignore: cast_nullable_to_non_nullable
as String,pickupLat: null == pickupLat ? _self.pickupLat : pickupLat // ignore: cast_nullable_to_non_nullable
as double,pickupLng: null == pickupLng ? _self.pickupLng : pickupLng // ignore: cast_nullable_to_non_nullable
as double,dropoffLat: null == dropoffLat ? _self.dropoffLat : dropoffLat // ignore: cast_nullable_to_non_nullable
as double,dropoffLng: null == dropoffLng ? _self.dropoffLng : dropoffLng // ignore: cast_nullable_to_non_nullable
as double,fare: null == fare ? _self.fare : fare // ignore: cast_nullable_to_non_nullable
as double,estimatedMiles: null == estimatedMiles ? _self.estimatedMiles : estimatedMiles // ignore: cast_nullable_to_non_nullable
as double,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,offeredAt: null == offeredAt ? _self.offeredAt : offeredAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
