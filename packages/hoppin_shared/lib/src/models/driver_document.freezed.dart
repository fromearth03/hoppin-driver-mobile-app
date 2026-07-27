// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'driver_document.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DriverDocument {

 String get id;@JsonKey(name: 'document_type') String get documentType;@JsonKey(name: 'verification_status') String get verificationStatus;@JsonKey(name: 'uploaded_at') DateTime get uploadedAt;@JsonKey(name: 'expires_at') DateTime? get expiresAt;
/// Create a copy of DriverDocument
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DriverDocumentCopyWith<DriverDocument> get copyWith => _$DriverDocumentCopyWithImpl<DriverDocument>(this as DriverDocument, _$identity);

  /// Serializes this DriverDocument to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DriverDocument&&(identical(other.id, id) || other.id == id)&&(identical(other.documentType, documentType) || other.documentType == documentType)&&(identical(other.verificationStatus, verificationStatus) || other.verificationStatus == verificationStatus)&&(identical(other.uploadedAt, uploadedAt) || other.uploadedAt == uploadedAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,documentType,verificationStatus,uploadedAt,expiresAt);

@override
String toString() {
  return 'DriverDocument(id: $id, documentType: $documentType, verificationStatus: $verificationStatus, uploadedAt: $uploadedAt, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class $DriverDocumentCopyWith<$Res>  {
  factory $DriverDocumentCopyWith(DriverDocument value, $Res Function(DriverDocument) _then) = _$DriverDocumentCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'document_type') String documentType,@JsonKey(name: 'verification_status') String verificationStatus,@JsonKey(name: 'uploaded_at') DateTime uploadedAt,@JsonKey(name: 'expires_at') DateTime? expiresAt
});




}
/// @nodoc
class _$DriverDocumentCopyWithImpl<$Res>
    implements $DriverDocumentCopyWith<$Res> {
  _$DriverDocumentCopyWithImpl(this._self, this._then);

  final DriverDocument _self;
  final $Res Function(DriverDocument) _then;

/// Create a copy of DriverDocument
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? documentType = null,Object? verificationStatus = null,Object? uploadedAt = null,Object? expiresAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,documentType: null == documentType ? _self.documentType : documentType // ignore: cast_nullable_to_non_nullable
as String,verificationStatus: null == verificationStatus ? _self.verificationStatus : verificationStatus // ignore: cast_nullable_to_non_nullable
as String,uploadedAt: null == uploadedAt ? _self.uploadedAt : uploadedAt // ignore: cast_nullable_to_non_nullable
as DateTime,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [DriverDocument].
extension DriverDocumentPatterns on DriverDocument {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DriverDocument value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DriverDocument() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DriverDocument value)  $default,){
final _that = this;
switch (_that) {
case _DriverDocument():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DriverDocument value)?  $default,){
final _that = this;
switch (_that) {
case _DriverDocument() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'document_type')  String documentType, @JsonKey(name: 'verification_status')  String verificationStatus, @JsonKey(name: 'uploaded_at')  DateTime uploadedAt, @JsonKey(name: 'expires_at')  DateTime? expiresAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DriverDocument() when $default != null:
return $default(_that.id,_that.documentType,_that.verificationStatus,_that.uploadedAt,_that.expiresAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'document_type')  String documentType, @JsonKey(name: 'verification_status')  String verificationStatus, @JsonKey(name: 'uploaded_at')  DateTime uploadedAt, @JsonKey(name: 'expires_at')  DateTime? expiresAt)  $default,) {final _that = this;
switch (_that) {
case _DriverDocument():
return $default(_that.id,_that.documentType,_that.verificationStatus,_that.uploadedAt,_that.expiresAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'document_type')  String documentType, @JsonKey(name: 'verification_status')  String verificationStatus, @JsonKey(name: 'uploaded_at')  DateTime uploadedAt, @JsonKey(name: 'expires_at')  DateTime? expiresAt)?  $default,) {final _that = this;
switch (_that) {
case _DriverDocument() when $default != null:
return $default(_that.id,_that.documentType,_that.verificationStatus,_that.uploadedAt,_that.expiresAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DriverDocument implements DriverDocument {
  const _DriverDocument({required this.id, @JsonKey(name: 'document_type') required this.documentType, @JsonKey(name: 'verification_status') required this.verificationStatus, @JsonKey(name: 'uploaded_at') required this.uploadedAt, @JsonKey(name: 'expires_at') this.expiresAt});
  factory _DriverDocument.fromJson(Map<String, dynamic> json) => _$DriverDocumentFromJson(json);

@override final  String id;
@override@JsonKey(name: 'document_type') final  String documentType;
@override@JsonKey(name: 'verification_status') final  String verificationStatus;
@override@JsonKey(name: 'uploaded_at') final  DateTime uploadedAt;
@override@JsonKey(name: 'expires_at') final  DateTime? expiresAt;

/// Create a copy of DriverDocument
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DriverDocumentCopyWith<_DriverDocument> get copyWith => __$DriverDocumentCopyWithImpl<_DriverDocument>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DriverDocumentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DriverDocument&&(identical(other.id, id) || other.id == id)&&(identical(other.documentType, documentType) || other.documentType == documentType)&&(identical(other.verificationStatus, verificationStatus) || other.verificationStatus == verificationStatus)&&(identical(other.uploadedAt, uploadedAt) || other.uploadedAt == uploadedAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,documentType,verificationStatus,uploadedAt,expiresAt);

@override
String toString() {
  return 'DriverDocument(id: $id, documentType: $documentType, verificationStatus: $verificationStatus, uploadedAt: $uploadedAt, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class _$DriverDocumentCopyWith<$Res> implements $DriverDocumentCopyWith<$Res> {
  factory _$DriverDocumentCopyWith(_DriverDocument value, $Res Function(_DriverDocument) _then) = __$DriverDocumentCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'document_type') String documentType,@JsonKey(name: 'verification_status') String verificationStatus,@JsonKey(name: 'uploaded_at') DateTime uploadedAt,@JsonKey(name: 'expires_at') DateTime? expiresAt
});




}
/// @nodoc
class __$DriverDocumentCopyWithImpl<$Res>
    implements _$DriverDocumentCopyWith<$Res> {
  __$DriverDocumentCopyWithImpl(this._self, this._then);

  final _DriverDocument _self;
  final $Res Function(_DriverDocument) _then;

/// Create a copy of DriverDocument
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? documentType = null,Object? verificationStatus = null,Object? uploadedAt = null,Object? expiresAt = freezed,}) {
  return _then(_DriverDocument(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,documentType: null == documentType ? _self.documentType : documentType // ignore: cast_nullable_to_non_nullable
as String,verificationStatus: null == verificationStatus ? _self.verificationStatus : verificationStatus // ignore: cast_nullable_to_non_nullable
as String,uploadedAt: null == uploadedAt ? _self.uploadedAt : uploadedAt // ignore: cast_nullable_to_non_nullable
as DateTime,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
