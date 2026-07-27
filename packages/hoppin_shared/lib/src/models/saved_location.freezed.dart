// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'saved_location.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SavedLocation {

 String get id;@JsonKey(name: 'user_id') String? get userId; String get label; double get lat; double get lng;
/// Create a copy of SavedLocation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SavedLocationCopyWith<SavedLocation> get copyWith => _$SavedLocationCopyWithImpl<SavedLocation>(this as SavedLocation, _$identity);

  /// Serializes this SavedLocation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SavedLocation&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.label, label) || other.label == label)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,label,lat,lng);

@override
String toString() {
  return 'SavedLocation(id: $id, userId: $userId, label: $label, lat: $lat, lng: $lng)';
}


}

/// @nodoc
abstract mixin class $SavedLocationCopyWith<$Res>  {
  factory $SavedLocationCopyWith(SavedLocation value, $Res Function(SavedLocation) _then) = _$SavedLocationCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String? userId, String label, double lat, double lng
});




}
/// @nodoc
class _$SavedLocationCopyWithImpl<$Res>
    implements $SavedLocationCopyWith<$Res> {
  _$SavedLocationCopyWithImpl(this._self, this._then);

  final SavedLocation _self;
  final $Res Function(SavedLocation) _then;

/// Create a copy of SavedLocation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = freezed,Object? label = null,Object? lat = null,Object? lng = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String?,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [SavedLocation].
extension SavedLocationPatterns on SavedLocation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SavedLocation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SavedLocation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SavedLocation value)  $default,){
final _that = this;
switch (_that) {
case _SavedLocation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SavedLocation value)?  $default,){
final _that = this;
switch (_that) {
case _SavedLocation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String? userId,  String label,  double lat,  double lng)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SavedLocation() when $default != null:
return $default(_that.id,_that.userId,_that.label,_that.lat,_that.lng);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String? userId,  String label,  double lat,  double lng)  $default,) {final _that = this;
switch (_that) {
case _SavedLocation():
return $default(_that.id,_that.userId,_that.label,_that.lat,_that.lng);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'user_id')  String? userId,  String label,  double lat,  double lng)?  $default,) {final _that = this;
switch (_that) {
case _SavedLocation() when $default != null:
return $default(_that.id,_that.userId,_that.label,_that.lat,_that.lng);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SavedLocation implements SavedLocation {
  const _SavedLocation({required this.id, @JsonKey(name: 'user_id') this.userId, required this.label, required this.lat, required this.lng});
  factory _SavedLocation.fromJson(Map<String, dynamic> json) => _$SavedLocationFromJson(json);

@override final  String id;
@override@JsonKey(name: 'user_id') final  String? userId;
@override final  String label;
@override final  double lat;
@override final  double lng;

/// Create a copy of SavedLocation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SavedLocationCopyWith<_SavedLocation> get copyWith => __$SavedLocationCopyWithImpl<_SavedLocation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SavedLocationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SavedLocation&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.label, label) || other.label == label)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,label,lat,lng);

@override
String toString() {
  return 'SavedLocation(id: $id, userId: $userId, label: $label, lat: $lat, lng: $lng)';
}


}

/// @nodoc
abstract mixin class _$SavedLocationCopyWith<$Res> implements $SavedLocationCopyWith<$Res> {
  factory _$SavedLocationCopyWith(_SavedLocation value, $Res Function(_SavedLocation) _then) = __$SavedLocationCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String? userId, String label, double lat, double lng
});




}
/// @nodoc
class __$SavedLocationCopyWithImpl<$Res>
    implements _$SavedLocationCopyWith<$Res> {
  __$SavedLocationCopyWithImpl(this._self, this._then);

  final _SavedLocation _self;
  final $Res Function(_SavedLocation) _then;

/// Create a copy of SavedLocation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = freezed,Object? label = null,Object? lat = null,Object? lng = null,}) {
  return _then(_SavedLocation(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String?,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
