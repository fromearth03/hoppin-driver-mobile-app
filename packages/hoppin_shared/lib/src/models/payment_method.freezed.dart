// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment_method.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PaymentMethod {

 String get paymentMethodId; String? get brand; String? get last4; int? get expMonth; int? get expYear; bool get isDefault;
/// Create a copy of PaymentMethod
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentMethodCopyWith<PaymentMethod> get copyWith => _$PaymentMethodCopyWithImpl<PaymentMethod>(this as PaymentMethod, _$identity);

  /// Serializes this PaymentMethod to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentMethod&&(identical(other.paymentMethodId, paymentMethodId) || other.paymentMethodId == paymentMethodId)&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.last4, last4) || other.last4 == last4)&&(identical(other.expMonth, expMonth) || other.expMonth == expMonth)&&(identical(other.expYear, expYear) || other.expYear == expYear)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,paymentMethodId,brand,last4,expMonth,expYear,isDefault);

@override
String toString() {
  return 'PaymentMethod(paymentMethodId: $paymentMethodId, brand: $brand, last4: $last4, expMonth: $expMonth, expYear: $expYear, isDefault: $isDefault)';
}


}

/// @nodoc
abstract mixin class $PaymentMethodCopyWith<$Res>  {
  factory $PaymentMethodCopyWith(PaymentMethod value, $Res Function(PaymentMethod) _then) = _$PaymentMethodCopyWithImpl;
@useResult
$Res call({
 String paymentMethodId, String? brand, String? last4, int? expMonth, int? expYear, bool isDefault
});




}
/// @nodoc
class _$PaymentMethodCopyWithImpl<$Res>
    implements $PaymentMethodCopyWith<$Res> {
  _$PaymentMethodCopyWithImpl(this._self, this._then);

  final PaymentMethod _self;
  final $Res Function(PaymentMethod) _then;

/// Create a copy of PaymentMethod
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? paymentMethodId = null,Object? brand = freezed,Object? last4 = freezed,Object? expMonth = freezed,Object? expYear = freezed,Object? isDefault = null,}) {
  return _then(_self.copyWith(
paymentMethodId: null == paymentMethodId ? _self.paymentMethodId : paymentMethodId // ignore: cast_nullable_to_non_nullable
as String,brand: freezed == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as String?,last4: freezed == last4 ? _self.last4 : last4 // ignore: cast_nullable_to_non_nullable
as String?,expMonth: freezed == expMonth ? _self.expMonth : expMonth // ignore: cast_nullable_to_non_nullable
as int?,expYear: freezed == expYear ? _self.expYear : expYear // ignore: cast_nullable_to_non_nullable
as int?,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PaymentMethod].
extension PaymentMethodPatterns on PaymentMethod {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentMethod value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentMethod() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentMethod value)  $default,){
final _that = this;
switch (_that) {
case _PaymentMethod():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentMethod value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentMethod() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String paymentMethodId,  String? brand,  String? last4,  int? expMonth,  int? expYear,  bool isDefault)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentMethod() when $default != null:
return $default(_that.paymentMethodId,_that.brand,_that.last4,_that.expMonth,_that.expYear,_that.isDefault);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String paymentMethodId,  String? brand,  String? last4,  int? expMonth,  int? expYear,  bool isDefault)  $default,) {final _that = this;
switch (_that) {
case _PaymentMethod():
return $default(_that.paymentMethodId,_that.brand,_that.last4,_that.expMonth,_that.expYear,_that.isDefault);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String paymentMethodId,  String? brand,  String? last4,  int? expMonth,  int? expYear,  bool isDefault)?  $default,) {final _that = this;
switch (_that) {
case _PaymentMethod() when $default != null:
return $default(_that.paymentMethodId,_that.brand,_that.last4,_that.expMonth,_that.expYear,_that.isDefault);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PaymentMethod implements PaymentMethod {
  const _PaymentMethod({required this.paymentMethodId, this.brand, this.last4, this.expMonth, this.expYear, this.isDefault = false});
  factory _PaymentMethod.fromJson(Map<String, dynamic> json) => _$PaymentMethodFromJson(json);

@override final  String paymentMethodId;
@override final  String? brand;
@override final  String? last4;
@override final  int? expMonth;
@override final  int? expYear;
@override@JsonKey() final  bool isDefault;

/// Create a copy of PaymentMethod
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentMethodCopyWith<_PaymentMethod> get copyWith => __$PaymentMethodCopyWithImpl<_PaymentMethod>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaymentMethodToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentMethod&&(identical(other.paymentMethodId, paymentMethodId) || other.paymentMethodId == paymentMethodId)&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.last4, last4) || other.last4 == last4)&&(identical(other.expMonth, expMonth) || other.expMonth == expMonth)&&(identical(other.expYear, expYear) || other.expYear == expYear)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,paymentMethodId,brand,last4,expMonth,expYear,isDefault);

@override
String toString() {
  return 'PaymentMethod(paymentMethodId: $paymentMethodId, brand: $brand, last4: $last4, expMonth: $expMonth, expYear: $expYear, isDefault: $isDefault)';
}


}

/// @nodoc
abstract mixin class _$PaymentMethodCopyWith<$Res> implements $PaymentMethodCopyWith<$Res> {
  factory _$PaymentMethodCopyWith(_PaymentMethod value, $Res Function(_PaymentMethod) _then) = __$PaymentMethodCopyWithImpl;
@override @useResult
$Res call({
 String paymentMethodId, String? brand, String? last4, int? expMonth, int? expYear, bool isDefault
});




}
/// @nodoc
class __$PaymentMethodCopyWithImpl<$Res>
    implements _$PaymentMethodCopyWith<$Res> {
  __$PaymentMethodCopyWithImpl(this._self, this._then);

  final _PaymentMethod _self;
  final $Res Function(_PaymentMethod) _then;

/// Create a copy of PaymentMethod
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? paymentMethodId = null,Object? brand = freezed,Object? last4 = freezed,Object? expMonth = freezed,Object? expYear = freezed,Object? isDefault = null,}) {
  return _then(_PaymentMethod(
paymentMethodId: null == paymentMethodId ? _self.paymentMethodId : paymentMethodId // ignore: cast_nullable_to_non_nullable
as String,brand: freezed == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as String?,last4: freezed == last4 ? _self.last4 : last4 // ignore: cast_nullable_to_non_nullable
as String?,expMonth: freezed == expMonth ? _self.expMonth : expMonth // ignore: cast_nullable_to_non_nullable
as int?,expYear: freezed == expYear ? _self.expYear : expYear // ignore: cast_nullable_to_non_nullable
as int?,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$SetupIntentInfo {

 String get setupIntentId; String get clientSecret; String? get customerId; String? get provider;
/// Create a copy of SetupIntentInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SetupIntentInfoCopyWith<SetupIntentInfo> get copyWith => _$SetupIntentInfoCopyWithImpl<SetupIntentInfo>(this as SetupIntentInfo, _$identity);

  /// Serializes this SetupIntentInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SetupIntentInfo&&(identical(other.setupIntentId, setupIntentId) || other.setupIntentId == setupIntentId)&&(identical(other.clientSecret, clientSecret) || other.clientSecret == clientSecret)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.provider, provider) || other.provider == provider));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,setupIntentId,clientSecret,customerId,provider);

@override
String toString() {
  return 'SetupIntentInfo(setupIntentId: $setupIntentId, clientSecret: $clientSecret, customerId: $customerId, provider: $provider)';
}


}

/// @nodoc
abstract mixin class $SetupIntentInfoCopyWith<$Res>  {
  factory $SetupIntentInfoCopyWith(SetupIntentInfo value, $Res Function(SetupIntentInfo) _then) = _$SetupIntentInfoCopyWithImpl;
@useResult
$Res call({
 String setupIntentId, String clientSecret, String? customerId, String? provider
});




}
/// @nodoc
class _$SetupIntentInfoCopyWithImpl<$Res>
    implements $SetupIntentInfoCopyWith<$Res> {
  _$SetupIntentInfoCopyWithImpl(this._self, this._then);

  final SetupIntentInfo _self;
  final $Res Function(SetupIntentInfo) _then;

/// Create a copy of SetupIntentInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? setupIntentId = null,Object? clientSecret = null,Object? customerId = freezed,Object? provider = freezed,}) {
  return _then(_self.copyWith(
setupIntentId: null == setupIntentId ? _self.setupIntentId : setupIntentId // ignore: cast_nullable_to_non_nullable
as String,clientSecret: null == clientSecret ? _self.clientSecret : clientSecret // ignore: cast_nullable_to_non_nullable
as String,customerId: freezed == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String?,provider: freezed == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SetupIntentInfo].
extension SetupIntentInfoPatterns on SetupIntentInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SetupIntentInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SetupIntentInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SetupIntentInfo value)  $default,){
final _that = this;
switch (_that) {
case _SetupIntentInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SetupIntentInfo value)?  $default,){
final _that = this;
switch (_that) {
case _SetupIntentInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String setupIntentId,  String clientSecret,  String? customerId,  String? provider)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SetupIntentInfo() when $default != null:
return $default(_that.setupIntentId,_that.clientSecret,_that.customerId,_that.provider);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String setupIntentId,  String clientSecret,  String? customerId,  String? provider)  $default,) {final _that = this;
switch (_that) {
case _SetupIntentInfo():
return $default(_that.setupIntentId,_that.clientSecret,_that.customerId,_that.provider);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String setupIntentId,  String clientSecret,  String? customerId,  String? provider)?  $default,) {final _that = this;
switch (_that) {
case _SetupIntentInfo() when $default != null:
return $default(_that.setupIntentId,_that.clientSecret,_that.customerId,_that.provider);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SetupIntentInfo implements SetupIntentInfo {
  const _SetupIntentInfo({required this.setupIntentId, required this.clientSecret, this.customerId, this.provider});
  factory _SetupIntentInfo.fromJson(Map<String, dynamic> json) => _$SetupIntentInfoFromJson(json);

@override final  String setupIntentId;
@override final  String clientSecret;
@override final  String? customerId;
@override final  String? provider;

/// Create a copy of SetupIntentInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SetupIntentInfoCopyWith<_SetupIntentInfo> get copyWith => __$SetupIntentInfoCopyWithImpl<_SetupIntentInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SetupIntentInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SetupIntentInfo&&(identical(other.setupIntentId, setupIntentId) || other.setupIntentId == setupIntentId)&&(identical(other.clientSecret, clientSecret) || other.clientSecret == clientSecret)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.provider, provider) || other.provider == provider));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,setupIntentId,clientSecret,customerId,provider);

@override
String toString() {
  return 'SetupIntentInfo(setupIntentId: $setupIntentId, clientSecret: $clientSecret, customerId: $customerId, provider: $provider)';
}


}

/// @nodoc
abstract mixin class _$SetupIntentInfoCopyWith<$Res> implements $SetupIntentInfoCopyWith<$Res> {
  factory _$SetupIntentInfoCopyWith(_SetupIntentInfo value, $Res Function(_SetupIntentInfo) _then) = __$SetupIntentInfoCopyWithImpl;
@override @useResult
$Res call({
 String setupIntentId, String clientSecret, String? customerId, String? provider
});




}
/// @nodoc
class __$SetupIntentInfoCopyWithImpl<$Res>
    implements _$SetupIntentInfoCopyWith<$Res> {
  __$SetupIntentInfoCopyWithImpl(this._self, this._then);

  final _SetupIntentInfo _self;
  final $Res Function(_SetupIntentInfo) _then;

/// Create a copy of SetupIntentInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? setupIntentId = null,Object? clientSecret = null,Object? customerId = freezed,Object? provider = freezed,}) {
  return _then(_SetupIntentInfo(
setupIntentId: null == setupIntentId ? _self.setupIntentId : setupIntentId // ignore: cast_nullable_to_non_nullable
as String,clientSecret: null == clientSecret ? _self.clientSecret : clientSecret // ignore: cast_nullable_to_non_nullable
as String,customerId: freezed == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String?,provider: freezed == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
