// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'promo_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PromoResult {

@JsonKey(name: 'promo_code') String get promoCode;@JsonKey(name: 'discount_type') String? get discountType;@JsonKey(name: 'original_fare') double get originalFare;@JsonKey(name: 'discount_amount') double get discountAmount;@JsonKey(name: 'new_fare') double get newFare;
/// Create a copy of PromoResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PromoResultCopyWith<PromoResult> get copyWith => _$PromoResultCopyWithImpl<PromoResult>(this as PromoResult, _$identity);

  /// Serializes this PromoResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PromoResult&&(identical(other.promoCode, promoCode) || other.promoCode == promoCode)&&(identical(other.discountType, discountType) || other.discountType == discountType)&&(identical(other.originalFare, originalFare) || other.originalFare == originalFare)&&(identical(other.discountAmount, discountAmount) || other.discountAmount == discountAmount)&&(identical(other.newFare, newFare) || other.newFare == newFare));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,promoCode,discountType,originalFare,discountAmount,newFare);

@override
String toString() {
  return 'PromoResult(promoCode: $promoCode, discountType: $discountType, originalFare: $originalFare, discountAmount: $discountAmount, newFare: $newFare)';
}


}

/// @nodoc
abstract mixin class $PromoResultCopyWith<$Res>  {
  factory $PromoResultCopyWith(PromoResult value, $Res Function(PromoResult) _then) = _$PromoResultCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'promo_code') String promoCode,@JsonKey(name: 'discount_type') String? discountType,@JsonKey(name: 'original_fare') double originalFare,@JsonKey(name: 'discount_amount') double discountAmount,@JsonKey(name: 'new_fare') double newFare
});




}
/// @nodoc
class _$PromoResultCopyWithImpl<$Res>
    implements $PromoResultCopyWith<$Res> {
  _$PromoResultCopyWithImpl(this._self, this._then);

  final PromoResult _self;
  final $Res Function(PromoResult) _then;

/// Create a copy of PromoResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? promoCode = null,Object? discountType = freezed,Object? originalFare = null,Object? discountAmount = null,Object? newFare = null,}) {
  return _then(_self.copyWith(
promoCode: null == promoCode ? _self.promoCode : promoCode // ignore: cast_nullable_to_non_nullable
as String,discountType: freezed == discountType ? _self.discountType : discountType // ignore: cast_nullable_to_non_nullable
as String?,originalFare: null == originalFare ? _self.originalFare : originalFare // ignore: cast_nullable_to_non_nullable
as double,discountAmount: null == discountAmount ? _self.discountAmount : discountAmount // ignore: cast_nullable_to_non_nullable
as double,newFare: null == newFare ? _self.newFare : newFare // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [PromoResult].
extension PromoResultPatterns on PromoResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PromoResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PromoResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PromoResult value)  $default,){
final _that = this;
switch (_that) {
case _PromoResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PromoResult value)?  $default,){
final _that = this;
switch (_that) {
case _PromoResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'promo_code')  String promoCode, @JsonKey(name: 'discount_type')  String? discountType, @JsonKey(name: 'original_fare')  double originalFare, @JsonKey(name: 'discount_amount')  double discountAmount, @JsonKey(name: 'new_fare')  double newFare)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PromoResult() when $default != null:
return $default(_that.promoCode,_that.discountType,_that.originalFare,_that.discountAmount,_that.newFare);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'promo_code')  String promoCode, @JsonKey(name: 'discount_type')  String? discountType, @JsonKey(name: 'original_fare')  double originalFare, @JsonKey(name: 'discount_amount')  double discountAmount, @JsonKey(name: 'new_fare')  double newFare)  $default,) {final _that = this;
switch (_that) {
case _PromoResult():
return $default(_that.promoCode,_that.discountType,_that.originalFare,_that.discountAmount,_that.newFare);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'promo_code')  String promoCode, @JsonKey(name: 'discount_type')  String? discountType, @JsonKey(name: 'original_fare')  double originalFare, @JsonKey(name: 'discount_amount')  double discountAmount, @JsonKey(name: 'new_fare')  double newFare)?  $default,) {final _that = this;
switch (_that) {
case _PromoResult() when $default != null:
return $default(_that.promoCode,_that.discountType,_that.originalFare,_that.discountAmount,_that.newFare);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PromoResult implements PromoResult {
  const _PromoResult({@JsonKey(name: 'promo_code') required this.promoCode, @JsonKey(name: 'discount_type') this.discountType, @JsonKey(name: 'original_fare') required this.originalFare, @JsonKey(name: 'discount_amount') required this.discountAmount, @JsonKey(name: 'new_fare') required this.newFare});
  factory _PromoResult.fromJson(Map<String, dynamic> json) => _$PromoResultFromJson(json);

@override@JsonKey(name: 'promo_code') final  String promoCode;
@override@JsonKey(name: 'discount_type') final  String? discountType;
@override@JsonKey(name: 'original_fare') final  double originalFare;
@override@JsonKey(name: 'discount_amount') final  double discountAmount;
@override@JsonKey(name: 'new_fare') final  double newFare;

/// Create a copy of PromoResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PromoResultCopyWith<_PromoResult> get copyWith => __$PromoResultCopyWithImpl<_PromoResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PromoResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PromoResult&&(identical(other.promoCode, promoCode) || other.promoCode == promoCode)&&(identical(other.discountType, discountType) || other.discountType == discountType)&&(identical(other.originalFare, originalFare) || other.originalFare == originalFare)&&(identical(other.discountAmount, discountAmount) || other.discountAmount == discountAmount)&&(identical(other.newFare, newFare) || other.newFare == newFare));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,promoCode,discountType,originalFare,discountAmount,newFare);

@override
String toString() {
  return 'PromoResult(promoCode: $promoCode, discountType: $discountType, originalFare: $originalFare, discountAmount: $discountAmount, newFare: $newFare)';
}


}

/// @nodoc
abstract mixin class _$PromoResultCopyWith<$Res> implements $PromoResultCopyWith<$Res> {
  factory _$PromoResultCopyWith(_PromoResult value, $Res Function(_PromoResult) _then) = __$PromoResultCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'promo_code') String promoCode,@JsonKey(name: 'discount_type') String? discountType,@JsonKey(name: 'original_fare') double originalFare,@JsonKey(name: 'discount_amount') double discountAmount,@JsonKey(name: 'new_fare') double newFare
});




}
/// @nodoc
class __$PromoResultCopyWithImpl<$Res>
    implements _$PromoResultCopyWith<$Res> {
  __$PromoResultCopyWithImpl(this._self, this._then);

  final _PromoResult _self;
  final $Res Function(_PromoResult) _then;

/// Create a copy of PromoResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? promoCode = null,Object? discountType = freezed,Object? originalFare = null,Object? discountAmount = null,Object? newFare = null,}) {
  return _then(_PromoResult(
promoCode: null == promoCode ? _self.promoCode : promoCode // ignore: cast_nullable_to_non_nullable
as String,discountType: freezed == discountType ? _self.discountType : discountType // ignore: cast_nullable_to_non_nullable
as String?,originalFare: null == originalFare ? _self.originalFare : originalFare // ignore: cast_nullable_to_non_nullable
as double,discountAmount: null == discountAmount ? _self.discountAmount : discountAmount // ignore: cast_nullable_to_non_nullable
as double,newFare: null == newFare ? _self.newFare : newFare // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
