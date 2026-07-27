// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'receipt.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Receipt {

@JsonKey(name: 'ride_id') String get rideId;@JsonKey(name: 'ride_category') String? get rideCategory;@JsonKey(name: 'fare_pence') int get farePence;@JsonKey(name: 'waiting_pence') int get waitingPence;@JsonKey(name: 'total_pence') int get totalPence;@JsonKey(name: 'platform_commission_pence') int? get platformCommissionPence; String get currency; String? get status;@JsonKey(name: 'distance_miles') double? get distanceMiles;@JsonKey(name: 'pickup_time') DateTime? get pickupTime;@JsonKey(name: 'dropoff_time') DateTime? get dropoffTime;@JsonKey(name: 'provider_payment_id') String? get providerPaymentId;
/// Create a copy of Receipt
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReceiptCopyWith<Receipt> get copyWith => _$ReceiptCopyWithImpl<Receipt>(this as Receipt, _$identity);

  /// Serializes this Receipt to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Receipt&&(identical(other.rideId, rideId) || other.rideId == rideId)&&(identical(other.rideCategory, rideCategory) || other.rideCategory == rideCategory)&&(identical(other.farePence, farePence) || other.farePence == farePence)&&(identical(other.waitingPence, waitingPence) || other.waitingPence == waitingPence)&&(identical(other.totalPence, totalPence) || other.totalPence == totalPence)&&(identical(other.platformCommissionPence, platformCommissionPence) || other.platformCommissionPence == platformCommissionPence)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.status, status) || other.status == status)&&(identical(other.distanceMiles, distanceMiles) || other.distanceMiles == distanceMiles)&&(identical(other.pickupTime, pickupTime) || other.pickupTime == pickupTime)&&(identical(other.dropoffTime, dropoffTime) || other.dropoffTime == dropoffTime)&&(identical(other.providerPaymentId, providerPaymentId) || other.providerPaymentId == providerPaymentId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,rideId,rideCategory,farePence,waitingPence,totalPence,platformCommissionPence,currency,status,distanceMiles,pickupTime,dropoffTime,providerPaymentId);

@override
String toString() {
  return 'Receipt(rideId: $rideId, rideCategory: $rideCategory, farePence: $farePence, waitingPence: $waitingPence, totalPence: $totalPence, platformCommissionPence: $platformCommissionPence, currency: $currency, status: $status, distanceMiles: $distanceMiles, pickupTime: $pickupTime, dropoffTime: $dropoffTime, providerPaymentId: $providerPaymentId)';
}


}

/// @nodoc
abstract mixin class $ReceiptCopyWith<$Res>  {
  factory $ReceiptCopyWith(Receipt value, $Res Function(Receipt) _then) = _$ReceiptCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'ride_id') String rideId,@JsonKey(name: 'ride_category') String? rideCategory,@JsonKey(name: 'fare_pence') int farePence,@JsonKey(name: 'waiting_pence') int waitingPence,@JsonKey(name: 'total_pence') int totalPence,@JsonKey(name: 'platform_commission_pence') int? platformCommissionPence, String currency, String? status,@JsonKey(name: 'distance_miles') double? distanceMiles,@JsonKey(name: 'pickup_time') DateTime? pickupTime,@JsonKey(name: 'dropoff_time') DateTime? dropoffTime,@JsonKey(name: 'provider_payment_id') String? providerPaymentId
});




}
/// @nodoc
class _$ReceiptCopyWithImpl<$Res>
    implements $ReceiptCopyWith<$Res> {
  _$ReceiptCopyWithImpl(this._self, this._then);

  final Receipt _self;
  final $Res Function(Receipt) _then;

/// Create a copy of Receipt
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rideId = null,Object? rideCategory = freezed,Object? farePence = null,Object? waitingPence = null,Object? totalPence = null,Object? platformCommissionPence = freezed,Object? currency = null,Object? status = freezed,Object? distanceMiles = freezed,Object? pickupTime = freezed,Object? dropoffTime = freezed,Object? providerPaymentId = freezed,}) {
  return _then(_self.copyWith(
rideId: null == rideId ? _self.rideId : rideId // ignore: cast_nullable_to_non_nullable
as String,rideCategory: freezed == rideCategory ? _self.rideCategory : rideCategory // ignore: cast_nullable_to_non_nullable
as String?,farePence: null == farePence ? _self.farePence : farePence // ignore: cast_nullable_to_non_nullable
as int,waitingPence: null == waitingPence ? _self.waitingPence : waitingPence // ignore: cast_nullable_to_non_nullable
as int,totalPence: null == totalPence ? _self.totalPence : totalPence // ignore: cast_nullable_to_non_nullable
as int,platformCommissionPence: freezed == platformCommissionPence ? _self.platformCommissionPence : platformCommissionPence // ignore: cast_nullable_to_non_nullable
as int?,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,distanceMiles: freezed == distanceMiles ? _self.distanceMiles : distanceMiles // ignore: cast_nullable_to_non_nullable
as double?,pickupTime: freezed == pickupTime ? _self.pickupTime : pickupTime // ignore: cast_nullable_to_non_nullable
as DateTime?,dropoffTime: freezed == dropoffTime ? _self.dropoffTime : dropoffTime // ignore: cast_nullable_to_non_nullable
as DateTime?,providerPaymentId: freezed == providerPaymentId ? _self.providerPaymentId : providerPaymentId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Receipt].
extension ReceiptPatterns on Receipt {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Receipt value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Receipt() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Receipt value)  $default,){
final _that = this;
switch (_that) {
case _Receipt():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Receipt value)?  $default,){
final _that = this;
switch (_that) {
case _Receipt() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'ride_id')  String rideId, @JsonKey(name: 'ride_category')  String? rideCategory, @JsonKey(name: 'fare_pence')  int farePence, @JsonKey(name: 'waiting_pence')  int waitingPence, @JsonKey(name: 'total_pence')  int totalPence, @JsonKey(name: 'platform_commission_pence')  int? platformCommissionPence,  String currency,  String? status, @JsonKey(name: 'distance_miles')  double? distanceMiles, @JsonKey(name: 'pickup_time')  DateTime? pickupTime, @JsonKey(name: 'dropoff_time')  DateTime? dropoffTime, @JsonKey(name: 'provider_payment_id')  String? providerPaymentId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Receipt() when $default != null:
return $default(_that.rideId,_that.rideCategory,_that.farePence,_that.waitingPence,_that.totalPence,_that.platformCommissionPence,_that.currency,_that.status,_that.distanceMiles,_that.pickupTime,_that.dropoffTime,_that.providerPaymentId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'ride_id')  String rideId, @JsonKey(name: 'ride_category')  String? rideCategory, @JsonKey(name: 'fare_pence')  int farePence, @JsonKey(name: 'waiting_pence')  int waitingPence, @JsonKey(name: 'total_pence')  int totalPence, @JsonKey(name: 'platform_commission_pence')  int? platformCommissionPence,  String currency,  String? status, @JsonKey(name: 'distance_miles')  double? distanceMiles, @JsonKey(name: 'pickup_time')  DateTime? pickupTime, @JsonKey(name: 'dropoff_time')  DateTime? dropoffTime, @JsonKey(name: 'provider_payment_id')  String? providerPaymentId)  $default,) {final _that = this;
switch (_that) {
case _Receipt():
return $default(_that.rideId,_that.rideCategory,_that.farePence,_that.waitingPence,_that.totalPence,_that.platformCommissionPence,_that.currency,_that.status,_that.distanceMiles,_that.pickupTime,_that.dropoffTime,_that.providerPaymentId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'ride_id')  String rideId, @JsonKey(name: 'ride_category')  String? rideCategory, @JsonKey(name: 'fare_pence')  int farePence, @JsonKey(name: 'waiting_pence')  int waitingPence, @JsonKey(name: 'total_pence')  int totalPence, @JsonKey(name: 'platform_commission_pence')  int? platformCommissionPence,  String currency,  String? status, @JsonKey(name: 'distance_miles')  double? distanceMiles, @JsonKey(name: 'pickup_time')  DateTime? pickupTime, @JsonKey(name: 'dropoff_time')  DateTime? dropoffTime, @JsonKey(name: 'provider_payment_id')  String? providerPaymentId)?  $default,) {final _that = this;
switch (_that) {
case _Receipt() when $default != null:
return $default(_that.rideId,_that.rideCategory,_that.farePence,_that.waitingPence,_that.totalPence,_that.platformCommissionPence,_that.currency,_that.status,_that.distanceMiles,_that.pickupTime,_that.dropoffTime,_that.providerPaymentId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Receipt implements Receipt {
  const _Receipt({@JsonKey(name: 'ride_id') required this.rideId, @JsonKey(name: 'ride_category') this.rideCategory, @JsonKey(name: 'fare_pence') required this.farePence, @JsonKey(name: 'waiting_pence') this.waitingPence = 0, @JsonKey(name: 'total_pence') required this.totalPence, @JsonKey(name: 'platform_commission_pence') this.platformCommissionPence, this.currency = 'GBP', this.status, @JsonKey(name: 'distance_miles') this.distanceMiles, @JsonKey(name: 'pickup_time') this.pickupTime, @JsonKey(name: 'dropoff_time') this.dropoffTime, @JsonKey(name: 'provider_payment_id') this.providerPaymentId});
  factory _Receipt.fromJson(Map<String, dynamic> json) => _$ReceiptFromJson(json);

@override@JsonKey(name: 'ride_id') final  String rideId;
@override@JsonKey(name: 'ride_category') final  String? rideCategory;
@override@JsonKey(name: 'fare_pence') final  int farePence;
@override@JsonKey(name: 'waiting_pence') final  int waitingPence;
@override@JsonKey(name: 'total_pence') final  int totalPence;
@override@JsonKey(name: 'platform_commission_pence') final  int? platformCommissionPence;
@override@JsonKey() final  String currency;
@override final  String? status;
@override@JsonKey(name: 'distance_miles') final  double? distanceMiles;
@override@JsonKey(name: 'pickup_time') final  DateTime? pickupTime;
@override@JsonKey(name: 'dropoff_time') final  DateTime? dropoffTime;
@override@JsonKey(name: 'provider_payment_id') final  String? providerPaymentId;

/// Create a copy of Receipt
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReceiptCopyWith<_Receipt> get copyWith => __$ReceiptCopyWithImpl<_Receipt>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReceiptToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Receipt&&(identical(other.rideId, rideId) || other.rideId == rideId)&&(identical(other.rideCategory, rideCategory) || other.rideCategory == rideCategory)&&(identical(other.farePence, farePence) || other.farePence == farePence)&&(identical(other.waitingPence, waitingPence) || other.waitingPence == waitingPence)&&(identical(other.totalPence, totalPence) || other.totalPence == totalPence)&&(identical(other.platformCommissionPence, platformCommissionPence) || other.platformCommissionPence == platformCommissionPence)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.status, status) || other.status == status)&&(identical(other.distanceMiles, distanceMiles) || other.distanceMiles == distanceMiles)&&(identical(other.pickupTime, pickupTime) || other.pickupTime == pickupTime)&&(identical(other.dropoffTime, dropoffTime) || other.dropoffTime == dropoffTime)&&(identical(other.providerPaymentId, providerPaymentId) || other.providerPaymentId == providerPaymentId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,rideId,rideCategory,farePence,waitingPence,totalPence,platformCommissionPence,currency,status,distanceMiles,pickupTime,dropoffTime,providerPaymentId);

@override
String toString() {
  return 'Receipt(rideId: $rideId, rideCategory: $rideCategory, farePence: $farePence, waitingPence: $waitingPence, totalPence: $totalPence, platformCommissionPence: $platformCommissionPence, currency: $currency, status: $status, distanceMiles: $distanceMiles, pickupTime: $pickupTime, dropoffTime: $dropoffTime, providerPaymentId: $providerPaymentId)';
}


}

/// @nodoc
abstract mixin class _$ReceiptCopyWith<$Res> implements $ReceiptCopyWith<$Res> {
  factory _$ReceiptCopyWith(_Receipt value, $Res Function(_Receipt) _then) = __$ReceiptCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'ride_id') String rideId,@JsonKey(name: 'ride_category') String? rideCategory,@JsonKey(name: 'fare_pence') int farePence,@JsonKey(name: 'waiting_pence') int waitingPence,@JsonKey(name: 'total_pence') int totalPence,@JsonKey(name: 'platform_commission_pence') int? platformCommissionPence, String currency, String? status,@JsonKey(name: 'distance_miles') double? distanceMiles,@JsonKey(name: 'pickup_time') DateTime? pickupTime,@JsonKey(name: 'dropoff_time') DateTime? dropoffTime,@JsonKey(name: 'provider_payment_id') String? providerPaymentId
});




}
/// @nodoc
class __$ReceiptCopyWithImpl<$Res>
    implements _$ReceiptCopyWith<$Res> {
  __$ReceiptCopyWithImpl(this._self, this._then);

  final _Receipt _self;
  final $Res Function(_Receipt) _then;

/// Create a copy of Receipt
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rideId = null,Object? rideCategory = freezed,Object? farePence = null,Object? waitingPence = null,Object? totalPence = null,Object? platformCommissionPence = freezed,Object? currency = null,Object? status = freezed,Object? distanceMiles = freezed,Object? pickupTime = freezed,Object? dropoffTime = freezed,Object? providerPaymentId = freezed,}) {
  return _then(_Receipt(
rideId: null == rideId ? _self.rideId : rideId // ignore: cast_nullable_to_non_nullable
as String,rideCategory: freezed == rideCategory ? _self.rideCategory : rideCategory // ignore: cast_nullable_to_non_nullable
as String?,farePence: null == farePence ? _self.farePence : farePence // ignore: cast_nullable_to_non_nullable
as int,waitingPence: null == waitingPence ? _self.waitingPence : waitingPence // ignore: cast_nullable_to_non_nullable
as int,totalPence: null == totalPence ? _self.totalPence : totalPence // ignore: cast_nullable_to_non_nullable
as int,platformCommissionPence: freezed == platformCommissionPence ? _self.platformCommissionPence : platformCommissionPence // ignore: cast_nullable_to_non_nullable
as int?,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,distanceMiles: freezed == distanceMiles ? _self.distanceMiles : distanceMiles // ignore: cast_nullable_to_non_nullable
as double?,pickupTime: freezed == pickupTime ? _self.pickupTime : pickupTime // ignore: cast_nullable_to_non_nullable
as DateTime?,dropoffTime: freezed == dropoffTime ? _self.dropoffTime : dropoffTime // ignore: cast_nullable_to_non_nullable
as DateTime?,providerPaymentId: freezed == providerPaymentId ? _self.providerPaymentId : providerPaymentId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
