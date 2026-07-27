// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'fare_estimate.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Quote {

 double get base; double get distance; double get time;@JsonKey(name: 'service_fee') double get serviceFee; double get subtotal; double get multiplier; double get surge; double get gross; double get minimum; double get total;
/// Create a copy of Quote
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuoteCopyWith<Quote> get copyWith => _$QuoteCopyWithImpl<Quote>(this as Quote, _$identity);

  /// Serializes this Quote to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Quote&&(identical(other.base, base) || other.base == base)&&(identical(other.distance, distance) || other.distance == distance)&&(identical(other.time, time) || other.time == time)&&(identical(other.serviceFee, serviceFee) || other.serviceFee == serviceFee)&&(identical(other.subtotal, subtotal) || other.subtotal == subtotal)&&(identical(other.multiplier, multiplier) || other.multiplier == multiplier)&&(identical(other.surge, surge) || other.surge == surge)&&(identical(other.gross, gross) || other.gross == gross)&&(identical(other.minimum, minimum) || other.minimum == minimum)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,base,distance,time,serviceFee,subtotal,multiplier,surge,gross,minimum,total);

@override
String toString() {
  return 'Quote(base: $base, distance: $distance, time: $time, serviceFee: $serviceFee, subtotal: $subtotal, multiplier: $multiplier, surge: $surge, gross: $gross, minimum: $minimum, total: $total)';
}


}

/// @nodoc
abstract mixin class $QuoteCopyWith<$Res>  {
  factory $QuoteCopyWith(Quote value, $Res Function(Quote) _then) = _$QuoteCopyWithImpl;
@useResult
$Res call({
 double base, double distance, double time,@JsonKey(name: 'service_fee') double serviceFee, double subtotal, double multiplier, double surge, double gross, double minimum, double total
});




}
/// @nodoc
class _$QuoteCopyWithImpl<$Res>
    implements $QuoteCopyWith<$Res> {
  _$QuoteCopyWithImpl(this._self, this._then);

  final Quote _self;
  final $Res Function(Quote) _then;

/// Create a copy of Quote
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? base = null,Object? distance = null,Object? time = null,Object? serviceFee = null,Object? subtotal = null,Object? multiplier = null,Object? surge = null,Object? gross = null,Object? minimum = null,Object? total = null,}) {
  return _then(_self.copyWith(
base: null == base ? _self.base : base // ignore: cast_nullable_to_non_nullable
as double,distance: null == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double,time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as double,serviceFee: null == serviceFee ? _self.serviceFee : serviceFee // ignore: cast_nullable_to_non_nullable
as double,subtotal: null == subtotal ? _self.subtotal : subtotal // ignore: cast_nullable_to_non_nullable
as double,multiplier: null == multiplier ? _self.multiplier : multiplier // ignore: cast_nullable_to_non_nullable
as double,surge: null == surge ? _self.surge : surge // ignore: cast_nullable_to_non_nullable
as double,gross: null == gross ? _self.gross : gross // ignore: cast_nullable_to_non_nullable
as double,minimum: null == minimum ? _self.minimum : minimum // ignore: cast_nullable_to_non_nullable
as double,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [Quote].
extension QuotePatterns on Quote {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Quote value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Quote() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Quote value)  $default,){
final _that = this;
switch (_that) {
case _Quote():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Quote value)?  $default,){
final _that = this;
switch (_that) {
case _Quote() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double base,  double distance,  double time, @JsonKey(name: 'service_fee')  double serviceFee,  double subtotal,  double multiplier,  double surge,  double gross,  double minimum,  double total)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Quote() when $default != null:
return $default(_that.base,_that.distance,_that.time,_that.serviceFee,_that.subtotal,_that.multiplier,_that.surge,_that.gross,_that.minimum,_that.total);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double base,  double distance,  double time, @JsonKey(name: 'service_fee')  double serviceFee,  double subtotal,  double multiplier,  double surge,  double gross,  double minimum,  double total)  $default,) {final _that = this;
switch (_that) {
case _Quote():
return $default(_that.base,_that.distance,_that.time,_that.serviceFee,_that.subtotal,_that.multiplier,_that.surge,_that.gross,_that.minimum,_that.total);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double base,  double distance,  double time, @JsonKey(name: 'service_fee')  double serviceFee,  double subtotal,  double multiplier,  double surge,  double gross,  double minimum,  double total)?  $default,) {final _that = this;
switch (_that) {
case _Quote() when $default != null:
return $default(_that.base,_that.distance,_that.time,_that.serviceFee,_that.subtotal,_that.multiplier,_that.surge,_that.gross,_that.minimum,_that.total);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Quote implements Quote {
  const _Quote({required this.base, required this.distance, required this.time, @JsonKey(name: 'service_fee') required this.serviceFee, required this.subtotal, required this.multiplier, required this.surge, required this.gross, required this.minimum, required this.total});
  factory _Quote.fromJson(Map<String, dynamic> json) => _$QuoteFromJson(json);

@override final  double base;
@override final  double distance;
@override final  double time;
@override@JsonKey(name: 'service_fee') final  double serviceFee;
@override final  double subtotal;
@override final  double multiplier;
@override final  double surge;
@override final  double gross;
@override final  double minimum;
@override final  double total;

/// Create a copy of Quote
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuoteCopyWith<_Quote> get copyWith => __$QuoteCopyWithImpl<_Quote>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QuoteToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Quote&&(identical(other.base, base) || other.base == base)&&(identical(other.distance, distance) || other.distance == distance)&&(identical(other.time, time) || other.time == time)&&(identical(other.serviceFee, serviceFee) || other.serviceFee == serviceFee)&&(identical(other.subtotal, subtotal) || other.subtotal == subtotal)&&(identical(other.multiplier, multiplier) || other.multiplier == multiplier)&&(identical(other.surge, surge) || other.surge == surge)&&(identical(other.gross, gross) || other.gross == gross)&&(identical(other.minimum, minimum) || other.minimum == minimum)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,base,distance,time,serviceFee,subtotal,multiplier,surge,gross,minimum,total);

@override
String toString() {
  return 'Quote(base: $base, distance: $distance, time: $time, serviceFee: $serviceFee, subtotal: $subtotal, multiplier: $multiplier, surge: $surge, gross: $gross, minimum: $minimum, total: $total)';
}


}

/// @nodoc
abstract mixin class _$QuoteCopyWith<$Res> implements $QuoteCopyWith<$Res> {
  factory _$QuoteCopyWith(_Quote value, $Res Function(_Quote) _then) = __$QuoteCopyWithImpl;
@override @useResult
$Res call({
 double base, double distance, double time,@JsonKey(name: 'service_fee') double serviceFee, double subtotal, double multiplier, double surge, double gross, double minimum, double total
});




}
/// @nodoc
class __$QuoteCopyWithImpl<$Res>
    implements _$QuoteCopyWith<$Res> {
  __$QuoteCopyWithImpl(this._self, this._then);

  final _Quote _self;
  final $Res Function(_Quote) _then;

/// Create a copy of Quote
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? base = null,Object? distance = null,Object? time = null,Object? serviceFee = null,Object? subtotal = null,Object? multiplier = null,Object? surge = null,Object? gross = null,Object? minimum = null,Object? total = null,}) {
  return _then(_Quote(
base: null == base ? _self.base : base // ignore: cast_nullable_to_non_nullable
as double,distance: null == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double,time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as double,serviceFee: null == serviceFee ? _self.serviceFee : serviceFee // ignore: cast_nullable_to_non_nullable
as double,subtotal: null == subtotal ? _self.subtotal : subtotal // ignore: cast_nullable_to_non_nullable
as double,multiplier: null == multiplier ? _self.multiplier : multiplier // ignore: cast_nullable_to_non_nullable
as double,surge: null == surge ? _self.surge : surge // ignore: cast_nullable_to_non_nullable
as double,gross: null == gross ? _self.gross : gross // ignore: cast_nullable_to_non_nullable
as double,minimum: null == minimum ? _self.minimum : minimum // ignore: cast_nullable_to_non_nullable
as double,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$FareEstimate {

 Quote get estimate;@JsonKey(name: 'distance_meters') int get distanceMeters;@JsonKey(name: 'duration_seconds') int get durationSeconds;@JsonKey(name: 'vehicle_category_id') String? get vehicleCategoryId;
/// Create a copy of FareEstimate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FareEstimateCopyWith<FareEstimate> get copyWith => _$FareEstimateCopyWithImpl<FareEstimate>(this as FareEstimate, _$identity);

  /// Serializes this FareEstimate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FareEstimate&&(identical(other.estimate, estimate) || other.estimate == estimate)&&(identical(other.distanceMeters, distanceMeters) || other.distanceMeters == distanceMeters)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds)&&(identical(other.vehicleCategoryId, vehicleCategoryId) || other.vehicleCategoryId == vehicleCategoryId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,estimate,distanceMeters,durationSeconds,vehicleCategoryId);

@override
String toString() {
  return 'FareEstimate(estimate: $estimate, distanceMeters: $distanceMeters, durationSeconds: $durationSeconds, vehicleCategoryId: $vehicleCategoryId)';
}


}

/// @nodoc
abstract mixin class $FareEstimateCopyWith<$Res>  {
  factory $FareEstimateCopyWith(FareEstimate value, $Res Function(FareEstimate) _then) = _$FareEstimateCopyWithImpl;
@useResult
$Res call({
 Quote estimate,@JsonKey(name: 'distance_meters') int distanceMeters,@JsonKey(name: 'duration_seconds') int durationSeconds,@JsonKey(name: 'vehicle_category_id') String? vehicleCategoryId
});


$QuoteCopyWith<$Res> get estimate;

}
/// @nodoc
class _$FareEstimateCopyWithImpl<$Res>
    implements $FareEstimateCopyWith<$Res> {
  _$FareEstimateCopyWithImpl(this._self, this._then);

  final FareEstimate _self;
  final $Res Function(FareEstimate) _then;

/// Create a copy of FareEstimate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? estimate = null,Object? distanceMeters = null,Object? durationSeconds = null,Object? vehicleCategoryId = freezed,}) {
  return _then(_self.copyWith(
estimate: null == estimate ? _self.estimate : estimate // ignore: cast_nullable_to_non_nullable
as Quote,distanceMeters: null == distanceMeters ? _self.distanceMeters : distanceMeters // ignore: cast_nullable_to_non_nullable
as int,durationSeconds: null == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int,vehicleCategoryId: freezed == vehicleCategoryId ? _self.vehicleCategoryId : vehicleCategoryId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of FareEstimate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$QuoteCopyWith<$Res> get estimate {
  
  return $QuoteCopyWith<$Res>(_self.estimate, (value) {
    return _then(_self.copyWith(estimate: value));
  });
}
}


/// Adds pattern-matching-related methods to [FareEstimate].
extension FareEstimatePatterns on FareEstimate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FareEstimate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FareEstimate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FareEstimate value)  $default,){
final _that = this;
switch (_that) {
case _FareEstimate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FareEstimate value)?  $default,){
final _that = this;
switch (_that) {
case _FareEstimate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Quote estimate, @JsonKey(name: 'distance_meters')  int distanceMeters, @JsonKey(name: 'duration_seconds')  int durationSeconds, @JsonKey(name: 'vehicle_category_id')  String? vehicleCategoryId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FareEstimate() when $default != null:
return $default(_that.estimate,_that.distanceMeters,_that.durationSeconds,_that.vehicleCategoryId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Quote estimate, @JsonKey(name: 'distance_meters')  int distanceMeters, @JsonKey(name: 'duration_seconds')  int durationSeconds, @JsonKey(name: 'vehicle_category_id')  String? vehicleCategoryId)  $default,) {final _that = this;
switch (_that) {
case _FareEstimate():
return $default(_that.estimate,_that.distanceMeters,_that.durationSeconds,_that.vehicleCategoryId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Quote estimate, @JsonKey(name: 'distance_meters')  int distanceMeters, @JsonKey(name: 'duration_seconds')  int durationSeconds, @JsonKey(name: 'vehicle_category_id')  String? vehicleCategoryId)?  $default,) {final _that = this;
switch (_that) {
case _FareEstimate() when $default != null:
return $default(_that.estimate,_that.distanceMeters,_that.durationSeconds,_that.vehicleCategoryId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FareEstimate implements FareEstimate {
  const _FareEstimate({required this.estimate, @JsonKey(name: 'distance_meters') required this.distanceMeters, @JsonKey(name: 'duration_seconds') required this.durationSeconds, @JsonKey(name: 'vehicle_category_id') this.vehicleCategoryId});
  factory _FareEstimate.fromJson(Map<String, dynamic> json) => _$FareEstimateFromJson(json);

@override final  Quote estimate;
@override@JsonKey(name: 'distance_meters') final  int distanceMeters;
@override@JsonKey(name: 'duration_seconds') final  int durationSeconds;
@override@JsonKey(name: 'vehicle_category_id') final  String? vehicleCategoryId;

/// Create a copy of FareEstimate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FareEstimateCopyWith<_FareEstimate> get copyWith => __$FareEstimateCopyWithImpl<_FareEstimate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FareEstimateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FareEstimate&&(identical(other.estimate, estimate) || other.estimate == estimate)&&(identical(other.distanceMeters, distanceMeters) || other.distanceMeters == distanceMeters)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds)&&(identical(other.vehicleCategoryId, vehicleCategoryId) || other.vehicleCategoryId == vehicleCategoryId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,estimate,distanceMeters,durationSeconds,vehicleCategoryId);

@override
String toString() {
  return 'FareEstimate(estimate: $estimate, distanceMeters: $distanceMeters, durationSeconds: $durationSeconds, vehicleCategoryId: $vehicleCategoryId)';
}


}

/// @nodoc
abstract mixin class _$FareEstimateCopyWith<$Res> implements $FareEstimateCopyWith<$Res> {
  factory _$FareEstimateCopyWith(_FareEstimate value, $Res Function(_FareEstimate) _then) = __$FareEstimateCopyWithImpl;
@override @useResult
$Res call({
 Quote estimate,@JsonKey(name: 'distance_meters') int distanceMeters,@JsonKey(name: 'duration_seconds') int durationSeconds,@JsonKey(name: 'vehicle_category_id') String? vehicleCategoryId
});


@override $QuoteCopyWith<$Res> get estimate;

}
/// @nodoc
class __$FareEstimateCopyWithImpl<$Res>
    implements _$FareEstimateCopyWith<$Res> {
  __$FareEstimateCopyWithImpl(this._self, this._then);

  final _FareEstimate _self;
  final $Res Function(_FareEstimate) _then;

/// Create a copy of FareEstimate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? estimate = null,Object? distanceMeters = null,Object? durationSeconds = null,Object? vehicleCategoryId = freezed,}) {
  return _then(_FareEstimate(
estimate: null == estimate ? _self.estimate : estimate // ignore: cast_nullable_to_non_nullable
as Quote,distanceMeters: null == distanceMeters ? _self.distanceMeters : distanceMeters // ignore: cast_nullable_to_non_nullable
as int,durationSeconds: null == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int,vehicleCategoryId: freezed == vehicleCategoryId ? _self.vehicleCategoryId : vehicleCategoryId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of FareEstimate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$QuoteCopyWith<$Res> get estimate {
  
  return $QuoteCopyWith<$Res>(_self.estimate, (value) {
    return _then(_self.copyWith(estimate: value));
  });
}
}

// dart format on
