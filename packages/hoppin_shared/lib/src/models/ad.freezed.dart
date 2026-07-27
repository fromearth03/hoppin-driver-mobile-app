// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ad.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Ad {

 String get id; String get title; String? get body;@JsonKey(name: 'image_url') String? get imageUrl;@JsonKey(name: 'target_url') String? get targetUrl; String? get audience;@JsonKey(name: 'is_active') bool get isActive;@JsonKey(name: 'starts_at') DateTime? get startsAt;@JsonKey(name: 'ends_at') DateTime? get endsAt;@JsonKey(name: 'created_at') DateTime? get createdAt;
/// Create a copy of Ad
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdCopyWith<Ad> get copyWith => _$AdCopyWithImpl<Ad>(this as Ad, _$identity);

  /// Serializes this Ad to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Ad&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.targetUrl, targetUrl) || other.targetUrl == targetUrl)&&(identical(other.audience, audience) || other.audience == audience)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,body,imageUrl,targetUrl,audience,isActive,startsAt,endsAt,createdAt);

@override
String toString() {
  return 'Ad(id: $id, title: $title, body: $body, imageUrl: $imageUrl, targetUrl: $targetUrl, audience: $audience, isActive: $isActive, startsAt: $startsAt, endsAt: $endsAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $AdCopyWith<$Res>  {
  factory $AdCopyWith(Ad value, $Res Function(Ad) _then) = _$AdCopyWithImpl;
@useResult
$Res call({
 String id, String title, String? body,@JsonKey(name: 'image_url') String? imageUrl,@JsonKey(name: 'target_url') String? targetUrl, String? audience,@JsonKey(name: 'is_active') bool isActive,@JsonKey(name: 'starts_at') DateTime? startsAt,@JsonKey(name: 'ends_at') DateTime? endsAt,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class _$AdCopyWithImpl<$Res>
    implements $AdCopyWith<$Res> {
  _$AdCopyWithImpl(this._self, this._then);

  final Ad _self;
  final $Res Function(Ad) _then;

/// Create a copy of Ad
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? body = freezed,Object? imageUrl = freezed,Object? targetUrl = freezed,Object? audience = freezed,Object? isActive = null,Object? startsAt = freezed,Object? endsAt = freezed,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,targetUrl: freezed == targetUrl ? _self.targetUrl : targetUrl // ignore: cast_nullable_to_non_nullable
as String?,audience: freezed == audience ? _self.audience : audience // ignore: cast_nullable_to_non_nullable
as String?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,startsAt: freezed == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,endsAt: freezed == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Ad].
extension AdPatterns on Ad {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Ad value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Ad() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Ad value)  $default,){
final _that = this;
switch (_that) {
case _Ad():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Ad value)?  $default,){
final _that = this;
switch (_that) {
case _Ad() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String? body, @JsonKey(name: 'image_url')  String? imageUrl, @JsonKey(name: 'target_url')  String? targetUrl,  String? audience, @JsonKey(name: 'is_active')  bool isActive, @JsonKey(name: 'starts_at')  DateTime? startsAt, @JsonKey(name: 'ends_at')  DateTime? endsAt, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Ad() when $default != null:
return $default(_that.id,_that.title,_that.body,_that.imageUrl,_that.targetUrl,_that.audience,_that.isActive,_that.startsAt,_that.endsAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String? body, @JsonKey(name: 'image_url')  String? imageUrl, @JsonKey(name: 'target_url')  String? targetUrl,  String? audience, @JsonKey(name: 'is_active')  bool isActive, @JsonKey(name: 'starts_at')  DateTime? startsAt, @JsonKey(name: 'ends_at')  DateTime? endsAt, @JsonKey(name: 'created_at')  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _Ad():
return $default(_that.id,_that.title,_that.body,_that.imageUrl,_that.targetUrl,_that.audience,_that.isActive,_that.startsAt,_that.endsAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String? body, @JsonKey(name: 'image_url')  String? imageUrl, @JsonKey(name: 'target_url')  String? targetUrl,  String? audience, @JsonKey(name: 'is_active')  bool isActive, @JsonKey(name: 'starts_at')  DateTime? startsAt, @JsonKey(name: 'ends_at')  DateTime? endsAt, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Ad() when $default != null:
return $default(_that.id,_that.title,_that.body,_that.imageUrl,_that.targetUrl,_that.audience,_that.isActive,_that.startsAt,_that.endsAt,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Ad implements Ad {
  const _Ad({required this.id, required this.title, this.body, @JsonKey(name: 'image_url') this.imageUrl, @JsonKey(name: 'target_url') this.targetUrl, this.audience, @JsonKey(name: 'is_active') this.isActive = true, @JsonKey(name: 'starts_at') this.startsAt, @JsonKey(name: 'ends_at') this.endsAt, @JsonKey(name: 'created_at') this.createdAt});
  factory _Ad.fromJson(Map<String, dynamic> json) => _$AdFromJson(json);

@override final  String id;
@override final  String title;
@override final  String? body;
@override@JsonKey(name: 'image_url') final  String? imageUrl;
@override@JsonKey(name: 'target_url') final  String? targetUrl;
@override final  String? audience;
@override@JsonKey(name: 'is_active') final  bool isActive;
@override@JsonKey(name: 'starts_at') final  DateTime? startsAt;
@override@JsonKey(name: 'ends_at') final  DateTime? endsAt;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;

/// Create a copy of Ad
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdCopyWith<_Ad> get copyWith => __$AdCopyWithImpl<_Ad>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Ad&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.targetUrl, targetUrl) || other.targetUrl == targetUrl)&&(identical(other.audience, audience) || other.audience == audience)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,body,imageUrl,targetUrl,audience,isActive,startsAt,endsAt,createdAt);

@override
String toString() {
  return 'Ad(id: $id, title: $title, body: $body, imageUrl: $imageUrl, targetUrl: $targetUrl, audience: $audience, isActive: $isActive, startsAt: $startsAt, endsAt: $endsAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$AdCopyWith<$Res> implements $AdCopyWith<$Res> {
  factory _$AdCopyWith(_Ad value, $Res Function(_Ad) _then) = __$AdCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String? body,@JsonKey(name: 'image_url') String? imageUrl,@JsonKey(name: 'target_url') String? targetUrl, String? audience,@JsonKey(name: 'is_active') bool isActive,@JsonKey(name: 'starts_at') DateTime? startsAt,@JsonKey(name: 'ends_at') DateTime? endsAt,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class __$AdCopyWithImpl<$Res>
    implements _$AdCopyWith<$Res> {
  __$AdCopyWithImpl(this._self, this._then);

  final _Ad _self;
  final $Res Function(_Ad) _then;

/// Create a copy of Ad
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? body = freezed,Object? imageUrl = freezed,Object? targetUrl = freezed,Object? audience = freezed,Object? isActive = null,Object? startsAt = freezed,Object? endsAt = freezed,Object? createdAt = freezed,}) {
  return _then(_Ad(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,targetUrl: freezed == targetUrl ? _self.targetUrl : targetUrl // ignore: cast_nullable_to_non_nullable
as String?,audience: freezed == audience ? _self.audience : audience // ignore: cast_nullable_to_non_nullable
as String?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,startsAt: freezed == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,endsAt: freezed == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
