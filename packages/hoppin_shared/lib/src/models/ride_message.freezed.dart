// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ride_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RideMessage {

 String get id;@JsonKey(name: 'ride_id') String? get rideId;@JsonKey(name: 'sender_id') String get senderId;@JsonKey(name: 'sender_role') String? get senderRole; String get body;@JsonKey(name: 'created_at') DateTime? get createdAt;
/// Create a copy of RideMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RideMessageCopyWith<RideMessage> get copyWith => _$RideMessageCopyWithImpl<RideMessage>(this as RideMessage, _$identity);

  /// Serializes this RideMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RideMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.rideId, rideId) || other.rideId == rideId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.senderRole, senderRole) || other.senderRole == senderRole)&&(identical(other.body, body) || other.body == body)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,rideId,senderId,senderRole,body,createdAt);

@override
String toString() {
  return 'RideMessage(id: $id, rideId: $rideId, senderId: $senderId, senderRole: $senderRole, body: $body, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $RideMessageCopyWith<$Res>  {
  factory $RideMessageCopyWith(RideMessage value, $Res Function(RideMessage) _then) = _$RideMessageCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'ride_id') String? rideId,@JsonKey(name: 'sender_id') String senderId,@JsonKey(name: 'sender_role') String? senderRole, String body,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class _$RideMessageCopyWithImpl<$Res>
    implements $RideMessageCopyWith<$Res> {
  _$RideMessageCopyWithImpl(this._self, this._then);

  final RideMessage _self;
  final $Res Function(RideMessage) _then;

/// Create a copy of RideMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? rideId = freezed,Object? senderId = null,Object? senderRole = freezed,Object? body = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,rideId: freezed == rideId ? _self.rideId : rideId // ignore: cast_nullable_to_non_nullable
as String?,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,senderRole: freezed == senderRole ? _self.senderRole : senderRole // ignore: cast_nullable_to_non_nullable
as String?,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [RideMessage].
extension RideMessagePatterns on RideMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RideMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RideMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RideMessage value)  $default,){
final _that = this;
switch (_that) {
case _RideMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RideMessage value)?  $default,){
final _that = this;
switch (_that) {
case _RideMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'ride_id')  String? rideId, @JsonKey(name: 'sender_id')  String senderId, @JsonKey(name: 'sender_role')  String? senderRole,  String body, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RideMessage() when $default != null:
return $default(_that.id,_that.rideId,_that.senderId,_that.senderRole,_that.body,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'ride_id')  String? rideId, @JsonKey(name: 'sender_id')  String senderId, @JsonKey(name: 'sender_role')  String? senderRole,  String body, @JsonKey(name: 'created_at')  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _RideMessage():
return $default(_that.id,_that.rideId,_that.senderId,_that.senderRole,_that.body,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'ride_id')  String? rideId, @JsonKey(name: 'sender_id')  String senderId, @JsonKey(name: 'sender_role')  String? senderRole,  String body, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _RideMessage() when $default != null:
return $default(_that.id,_that.rideId,_that.senderId,_that.senderRole,_that.body,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RideMessage implements RideMessage {
  const _RideMessage({required this.id, @JsonKey(name: 'ride_id') this.rideId, @JsonKey(name: 'sender_id') required this.senderId, @JsonKey(name: 'sender_role') this.senderRole, required this.body, @JsonKey(name: 'created_at') this.createdAt});
  factory _RideMessage.fromJson(Map<String, dynamic> json) => _$RideMessageFromJson(json);

@override final  String id;
@override@JsonKey(name: 'ride_id') final  String? rideId;
@override@JsonKey(name: 'sender_id') final  String senderId;
@override@JsonKey(name: 'sender_role') final  String? senderRole;
@override final  String body;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;

/// Create a copy of RideMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RideMessageCopyWith<_RideMessage> get copyWith => __$RideMessageCopyWithImpl<_RideMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RideMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RideMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.rideId, rideId) || other.rideId == rideId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.senderRole, senderRole) || other.senderRole == senderRole)&&(identical(other.body, body) || other.body == body)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,rideId,senderId,senderRole,body,createdAt);

@override
String toString() {
  return 'RideMessage(id: $id, rideId: $rideId, senderId: $senderId, senderRole: $senderRole, body: $body, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$RideMessageCopyWith<$Res> implements $RideMessageCopyWith<$Res> {
  factory _$RideMessageCopyWith(_RideMessage value, $Res Function(_RideMessage) _then) = __$RideMessageCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'ride_id') String? rideId,@JsonKey(name: 'sender_id') String senderId,@JsonKey(name: 'sender_role') String? senderRole, String body,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class __$RideMessageCopyWithImpl<$Res>
    implements _$RideMessageCopyWith<$Res> {
  __$RideMessageCopyWithImpl(this._self, this._then);

  final _RideMessage _self;
  final $Res Function(_RideMessage) _then;

/// Create a copy of RideMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? rideId = freezed,Object? senderId = null,Object? senderRole = freezed,Object? body = null,Object? createdAt = freezed,}) {
  return _then(_RideMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,rideId: freezed == rideId ? _self.rideId : rideId // ignore: cast_nullable_to_non_nullable
as String?,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,senderRole: freezed == senderRole ? _self.senderRole : senderRole // ignore: cast_nullable_to_non_nullable
as String?,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
