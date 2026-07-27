// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'emergency_contact.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EmergencyContact {

 String get id;@JsonKey(name: 'contact_name') String get contactName;@JsonKey(name: 'phone_number') String get phoneNumber; String? get relationship;@JsonKey(name: 'auto_share_night_trips') bool get autoShareNightTrips;
/// Create a copy of EmergencyContact
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EmergencyContactCopyWith<EmergencyContact> get copyWith => _$EmergencyContactCopyWithImpl<EmergencyContact>(this as EmergencyContact, _$identity);

  /// Serializes this EmergencyContact to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EmergencyContact&&(identical(other.id, id) || other.id == id)&&(identical(other.contactName, contactName) || other.contactName == contactName)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.relationship, relationship) || other.relationship == relationship)&&(identical(other.autoShareNightTrips, autoShareNightTrips) || other.autoShareNightTrips == autoShareNightTrips));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,contactName,phoneNumber,relationship,autoShareNightTrips);

@override
String toString() {
  return 'EmergencyContact(id: $id, contactName: $contactName, phoneNumber: $phoneNumber, relationship: $relationship, autoShareNightTrips: $autoShareNightTrips)';
}


}

/// @nodoc
abstract mixin class $EmergencyContactCopyWith<$Res>  {
  factory $EmergencyContactCopyWith(EmergencyContact value, $Res Function(EmergencyContact) _then) = _$EmergencyContactCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'contact_name') String contactName,@JsonKey(name: 'phone_number') String phoneNumber, String? relationship,@JsonKey(name: 'auto_share_night_trips') bool autoShareNightTrips
});




}
/// @nodoc
class _$EmergencyContactCopyWithImpl<$Res>
    implements $EmergencyContactCopyWith<$Res> {
  _$EmergencyContactCopyWithImpl(this._self, this._then);

  final EmergencyContact _self;
  final $Res Function(EmergencyContact) _then;

/// Create a copy of EmergencyContact
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? contactName = null,Object? phoneNumber = null,Object? relationship = freezed,Object? autoShareNightTrips = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,contactName: null == contactName ? _self.contactName : contactName // ignore: cast_nullable_to_non_nullable
as String,phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,relationship: freezed == relationship ? _self.relationship : relationship // ignore: cast_nullable_to_non_nullable
as String?,autoShareNightTrips: null == autoShareNightTrips ? _self.autoShareNightTrips : autoShareNightTrips // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [EmergencyContact].
extension EmergencyContactPatterns on EmergencyContact {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EmergencyContact value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EmergencyContact() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EmergencyContact value)  $default,){
final _that = this;
switch (_that) {
case _EmergencyContact():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EmergencyContact value)?  $default,){
final _that = this;
switch (_that) {
case _EmergencyContact() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'contact_name')  String contactName, @JsonKey(name: 'phone_number')  String phoneNumber,  String? relationship, @JsonKey(name: 'auto_share_night_trips')  bool autoShareNightTrips)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EmergencyContact() when $default != null:
return $default(_that.id,_that.contactName,_that.phoneNumber,_that.relationship,_that.autoShareNightTrips);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'contact_name')  String contactName, @JsonKey(name: 'phone_number')  String phoneNumber,  String? relationship, @JsonKey(name: 'auto_share_night_trips')  bool autoShareNightTrips)  $default,) {final _that = this;
switch (_that) {
case _EmergencyContact():
return $default(_that.id,_that.contactName,_that.phoneNumber,_that.relationship,_that.autoShareNightTrips);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'contact_name')  String contactName, @JsonKey(name: 'phone_number')  String phoneNumber,  String? relationship, @JsonKey(name: 'auto_share_night_trips')  bool autoShareNightTrips)?  $default,) {final _that = this;
switch (_that) {
case _EmergencyContact() when $default != null:
return $default(_that.id,_that.contactName,_that.phoneNumber,_that.relationship,_that.autoShareNightTrips);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EmergencyContact implements EmergencyContact {
  const _EmergencyContact({required this.id, @JsonKey(name: 'contact_name') required this.contactName, @JsonKey(name: 'phone_number') required this.phoneNumber, this.relationship, @JsonKey(name: 'auto_share_night_trips') this.autoShareNightTrips = false});
  factory _EmergencyContact.fromJson(Map<String, dynamic> json) => _$EmergencyContactFromJson(json);

@override final  String id;
@override@JsonKey(name: 'contact_name') final  String contactName;
@override@JsonKey(name: 'phone_number') final  String phoneNumber;
@override final  String? relationship;
@override@JsonKey(name: 'auto_share_night_trips') final  bool autoShareNightTrips;

/// Create a copy of EmergencyContact
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EmergencyContactCopyWith<_EmergencyContact> get copyWith => __$EmergencyContactCopyWithImpl<_EmergencyContact>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EmergencyContactToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EmergencyContact&&(identical(other.id, id) || other.id == id)&&(identical(other.contactName, contactName) || other.contactName == contactName)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.relationship, relationship) || other.relationship == relationship)&&(identical(other.autoShareNightTrips, autoShareNightTrips) || other.autoShareNightTrips == autoShareNightTrips));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,contactName,phoneNumber,relationship,autoShareNightTrips);

@override
String toString() {
  return 'EmergencyContact(id: $id, contactName: $contactName, phoneNumber: $phoneNumber, relationship: $relationship, autoShareNightTrips: $autoShareNightTrips)';
}


}

/// @nodoc
abstract mixin class _$EmergencyContactCopyWith<$Res> implements $EmergencyContactCopyWith<$Res> {
  factory _$EmergencyContactCopyWith(_EmergencyContact value, $Res Function(_EmergencyContact) _then) = __$EmergencyContactCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'contact_name') String contactName,@JsonKey(name: 'phone_number') String phoneNumber, String? relationship,@JsonKey(name: 'auto_share_night_trips') bool autoShareNightTrips
});




}
/// @nodoc
class __$EmergencyContactCopyWithImpl<$Res>
    implements _$EmergencyContactCopyWith<$Res> {
  __$EmergencyContactCopyWithImpl(this._self, this._then);

  final _EmergencyContact _self;
  final $Res Function(_EmergencyContact) _then;

/// Create a copy of EmergencyContact
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? contactName = null,Object? phoneNumber = null,Object? relationship = freezed,Object? autoShareNightTrips = null,}) {
  return _then(_EmergencyContact(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,contactName: null == contactName ? _self.contactName : contactName // ignore: cast_nullable_to_non_nullable
as String,phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,relationship: freezed == relationship ? _self.relationship : relationship // ignore: cast_nullable_to_non_nullable
as String?,autoShareNightTrips: null == autoShareNightTrips ? _self.autoShareNightTrips : autoShareNightTrips // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
