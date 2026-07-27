// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sos_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SosEvent {

 String get id;@JsonKey(name: 'ride_id') String? get rideId;@JsonKey(name: 'triggered_by') String? get triggeredBy; String get status; double? get lat; double? get lng;@JsonKey(name: 'live_share_url') String? get liveShareUrl; String? get note;@JsonKey(name: 'created_at') DateTime? get createdAt;
/// Create a copy of SosEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SosEventCopyWith<SosEvent> get copyWith => _$SosEventCopyWithImpl<SosEvent>(this as SosEvent, _$identity);

  /// Serializes this SosEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SosEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.rideId, rideId) || other.rideId == rideId)&&(identical(other.triggeredBy, triggeredBy) || other.triggeredBy == triggeredBy)&&(identical(other.status, status) || other.status == status)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.liveShareUrl, liveShareUrl) || other.liveShareUrl == liveShareUrl)&&(identical(other.note, note) || other.note == note)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,rideId,triggeredBy,status,lat,lng,liveShareUrl,note,createdAt);

@override
String toString() {
  return 'SosEvent(id: $id, rideId: $rideId, triggeredBy: $triggeredBy, status: $status, lat: $lat, lng: $lng, liveShareUrl: $liveShareUrl, note: $note, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $SosEventCopyWith<$Res>  {
  factory $SosEventCopyWith(SosEvent value, $Res Function(SosEvent) _then) = _$SosEventCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'ride_id') String? rideId,@JsonKey(name: 'triggered_by') String? triggeredBy, String status, double? lat, double? lng,@JsonKey(name: 'live_share_url') String? liveShareUrl, String? note,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class _$SosEventCopyWithImpl<$Res>
    implements $SosEventCopyWith<$Res> {
  _$SosEventCopyWithImpl(this._self, this._then);

  final SosEvent _self;
  final $Res Function(SosEvent) _then;

/// Create a copy of SosEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? rideId = freezed,Object? triggeredBy = freezed,Object? status = null,Object? lat = freezed,Object? lng = freezed,Object? liveShareUrl = freezed,Object? note = freezed,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,rideId: freezed == rideId ? _self.rideId : rideId // ignore: cast_nullable_to_non_nullable
as String?,triggeredBy: freezed == triggeredBy ? _self.triggeredBy : triggeredBy // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,lat: freezed == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double?,lng: freezed == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double?,liveShareUrl: freezed == liveShareUrl ? _self.liveShareUrl : liveShareUrl // ignore: cast_nullable_to_non_nullable
as String?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [SosEvent].
extension SosEventPatterns on SosEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SosEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SosEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SosEvent value)  $default,){
final _that = this;
switch (_that) {
case _SosEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SosEvent value)?  $default,){
final _that = this;
switch (_that) {
case _SosEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'ride_id')  String? rideId, @JsonKey(name: 'triggered_by')  String? triggeredBy,  String status,  double? lat,  double? lng, @JsonKey(name: 'live_share_url')  String? liveShareUrl,  String? note, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SosEvent() when $default != null:
return $default(_that.id,_that.rideId,_that.triggeredBy,_that.status,_that.lat,_that.lng,_that.liveShareUrl,_that.note,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'ride_id')  String? rideId, @JsonKey(name: 'triggered_by')  String? triggeredBy,  String status,  double? lat,  double? lng, @JsonKey(name: 'live_share_url')  String? liveShareUrl,  String? note, @JsonKey(name: 'created_at')  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _SosEvent():
return $default(_that.id,_that.rideId,_that.triggeredBy,_that.status,_that.lat,_that.lng,_that.liveShareUrl,_that.note,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'ride_id')  String? rideId, @JsonKey(name: 'triggered_by')  String? triggeredBy,  String status,  double? lat,  double? lng, @JsonKey(name: 'live_share_url')  String? liveShareUrl,  String? note, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _SosEvent() when $default != null:
return $default(_that.id,_that.rideId,_that.triggeredBy,_that.status,_that.lat,_that.lng,_that.liveShareUrl,_that.note,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SosEvent implements SosEvent {
  const _SosEvent({required this.id, @JsonKey(name: 'ride_id') this.rideId, @JsonKey(name: 'triggered_by') this.triggeredBy, required this.status, this.lat, this.lng, @JsonKey(name: 'live_share_url') this.liveShareUrl, this.note, @JsonKey(name: 'created_at') this.createdAt});
  factory _SosEvent.fromJson(Map<String, dynamic> json) => _$SosEventFromJson(json);

@override final  String id;
@override@JsonKey(name: 'ride_id') final  String? rideId;
@override@JsonKey(name: 'triggered_by') final  String? triggeredBy;
@override final  String status;
@override final  double? lat;
@override final  double? lng;
@override@JsonKey(name: 'live_share_url') final  String? liveShareUrl;
@override final  String? note;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;

/// Create a copy of SosEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SosEventCopyWith<_SosEvent> get copyWith => __$SosEventCopyWithImpl<_SosEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SosEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SosEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.rideId, rideId) || other.rideId == rideId)&&(identical(other.triggeredBy, triggeredBy) || other.triggeredBy == triggeredBy)&&(identical(other.status, status) || other.status == status)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.liveShareUrl, liveShareUrl) || other.liveShareUrl == liveShareUrl)&&(identical(other.note, note) || other.note == note)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,rideId,triggeredBy,status,lat,lng,liveShareUrl,note,createdAt);

@override
String toString() {
  return 'SosEvent(id: $id, rideId: $rideId, triggeredBy: $triggeredBy, status: $status, lat: $lat, lng: $lng, liveShareUrl: $liveShareUrl, note: $note, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$SosEventCopyWith<$Res> implements $SosEventCopyWith<$Res> {
  factory _$SosEventCopyWith(_SosEvent value, $Res Function(_SosEvent) _then) = __$SosEventCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'ride_id') String? rideId,@JsonKey(name: 'triggered_by') String? triggeredBy, String status, double? lat, double? lng,@JsonKey(name: 'live_share_url') String? liveShareUrl, String? note,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class __$SosEventCopyWithImpl<$Res>
    implements _$SosEventCopyWith<$Res> {
  __$SosEventCopyWithImpl(this._self, this._then);

  final _SosEvent _self;
  final $Res Function(_SosEvent) _then;

/// Create a copy of SosEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? rideId = freezed,Object? triggeredBy = freezed,Object? status = null,Object? lat = freezed,Object? lng = freezed,Object? liveShareUrl = freezed,Object? note = freezed,Object? createdAt = freezed,}) {
  return _then(_SosEvent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,rideId: freezed == rideId ? _self.rideId : rideId // ignore: cast_nullable_to_non_nullable
as String?,triggeredBy: freezed == triggeredBy ? _self.triggeredBy : triggeredBy // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,lat: freezed == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double?,lng: freezed == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double?,liveShareUrl: freezed == liveShareUrl ? _self.liveShareUrl : liveShareUrl // ignore: cast_nullable_to_non_nullable
as String?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
