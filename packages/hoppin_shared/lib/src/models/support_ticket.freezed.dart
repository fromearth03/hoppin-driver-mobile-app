// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'support_ticket.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SupportTicket {

 String get id; String? get subject; String? get category;@JsonKey(name: 'type_code') String? get typeCode; String? get priority;@JsonKey(name: 'ride_id') String? get rideId; String get status;@JsonKey(name: 'created_at') DateTime? get createdAt;@JsonKey(name: 'updated_at') DateTime? get updatedAt;
/// Create a copy of SupportTicket
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SupportTicketCopyWith<SupportTicket> get copyWith => _$SupportTicketCopyWithImpl<SupportTicket>(this as SupportTicket, _$identity);

  /// Serializes this SupportTicket to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SupportTicket&&(identical(other.id, id) || other.id == id)&&(identical(other.subject, subject) || other.subject == subject)&&(identical(other.category, category) || other.category == category)&&(identical(other.typeCode, typeCode) || other.typeCode == typeCode)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.rideId, rideId) || other.rideId == rideId)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,subject,category,typeCode,priority,rideId,status,createdAt,updatedAt);

@override
String toString() {
  return 'SupportTicket(id: $id, subject: $subject, category: $category, typeCode: $typeCode, priority: $priority, rideId: $rideId, status: $status, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $SupportTicketCopyWith<$Res>  {
  factory $SupportTicketCopyWith(SupportTicket value, $Res Function(SupportTicket) _then) = _$SupportTicketCopyWithImpl;
@useResult
$Res call({
 String id, String? subject, String? category,@JsonKey(name: 'type_code') String? typeCode, String? priority,@JsonKey(name: 'ride_id') String? rideId, String status,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class _$SupportTicketCopyWithImpl<$Res>
    implements $SupportTicketCopyWith<$Res> {
  _$SupportTicketCopyWithImpl(this._self, this._then);

  final SupportTicket _self;
  final $Res Function(SupportTicket) _then;

/// Create a copy of SupportTicket
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? subject = freezed,Object? category = freezed,Object? typeCode = freezed,Object? priority = freezed,Object? rideId = freezed,Object? status = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,subject: freezed == subject ? _self.subject : subject // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,typeCode: freezed == typeCode ? _self.typeCode : typeCode // ignore: cast_nullable_to_non_nullable
as String?,priority: freezed == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as String?,rideId: freezed == rideId ? _self.rideId : rideId // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [SupportTicket].
extension SupportTicketPatterns on SupportTicket {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SupportTicket value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SupportTicket() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SupportTicket value)  $default,){
final _that = this;
switch (_that) {
case _SupportTicket():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SupportTicket value)?  $default,){
final _that = this;
switch (_that) {
case _SupportTicket() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? subject,  String? category, @JsonKey(name: 'type_code')  String? typeCode,  String? priority, @JsonKey(name: 'ride_id')  String? rideId,  String status, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SupportTicket() when $default != null:
return $default(_that.id,_that.subject,_that.category,_that.typeCode,_that.priority,_that.rideId,_that.status,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? subject,  String? category, @JsonKey(name: 'type_code')  String? typeCode,  String? priority, @JsonKey(name: 'ride_id')  String? rideId,  String status, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _SupportTicket():
return $default(_that.id,_that.subject,_that.category,_that.typeCode,_that.priority,_that.rideId,_that.status,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? subject,  String? category, @JsonKey(name: 'type_code')  String? typeCode,  String? priority, @JsonKey(name: 'ride_id')  String? rideId,  String status, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _SupportTicket() when $default != null:
return $default(_that.id,_that.subject,_that.category,_that.typeCode,_that.priority,_that.rideId,_that.status,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SupportTicket implements SupportTicket {
  const _SupportTicket({required this.id, this.subject, this.category, @JsonKey(name: 'type_code') this.typeCode, this.priority, @JsonKey(name: 'ride_id') this.rideId, this.status = 'open', @JsonKey(name: 'created_at') this.createdAt, @JsonKey(name: 'updated_at') this.updatedAt});
  factory _SupportTicket.fromJson(Map<String, dynamic> json) => _$SupportTicketFromJson(json);

@override final  String id;
@override final  String? subject;
@override final  String? category;
@override@JsonKey(name: 'type_code') final  String? typeCode;
@override final  String? priority;
@override@JsonKey(name: 'ride_id') final  String? rideId;
@override@JsonKey() final  String status;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;
@override@JsonKey(name: 'updated_at') final  DateTime? updatedAt;

/// Create a copy of SupportTicket
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SupportTicketCopyWith<_SupportTicket> get copyWith => __$SupportTicketCopyWithImpl<_SupportTicket>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SupportTicketToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SupportTicket&&(identical(other.id, id) || other.id == id)&&(identical(other.subject, subject) || other.subject == subject)&&(identical(other.category, category) || other.category == category)&&(identical(other.typeCode, typeCode) || other.typeCode == typeCode)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.rideId, rideId) || other.rideId == rideId)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,subject,category,typeCode,priority,rideId,status,createdAt,updatedAt);

@override
String toString() {
  return 'SupportTicket(id: $id, subject: $subject, category: $category, typeCode: $typeCode, priority: $priority, rideId: $rideId, status: $status, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$SupportTicketCopyWith<$Res> implements $SupportTicketCopyWith<$Res> {
  factory _$SupportTicketCopyWith(_SupportTicket value, $Res Function(_SupportTicket) _then) = __$SupportTicketCopyWithImpl;
@override @useResult
$Res call({
 String id, String? subject, String? category,@JsonKey(name: 'type_code') String? typeCode, String? priority,@JsonKey(name: 'ride_id') String? rideId, String status,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class __$SupportTicketCopyWithImpl<$Res>
    implements _$SupportTicketCopyWith<$Res> {
  __$SupportTicketCopyWithImpl(this._self, this._then);

  final _SupportTicket _self;
  final $Res Function(_SupportTicket) _then;

/// Create a copy of SupportTicket
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? subject = freezed,Object? category = freezed,Object? typeCode = freezed,Object? priority = freezed,Object? rideId = freezed,Object? status = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_SupportTicket(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,subject: freezed == subject ? _self.subject : subject // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,typeCode: freezed == typeCode ? _self.typeCode : typeCode // ignore: cast_nullable_to_non_nullable
as String?,priority: freezed == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as String?,rideId: freezed == rideId ? _self.rideId : rideId // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$TicketMessage {

 String get id;@JsonKey(name: 'ticket_id') String? get ticketId;@JsonKey(name: 'author_id') String? get authorId;@JsonKey(name: 'is_staff') bool get isStaff; String get body;@JsonKey(name: 'created_at') DateTime? get createdAt;
/// Create a copy of TicketMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TicketMessageCopyWith<TicketMessage> get copyWith => _$TicketMessageCopyWithImpl<TicketMessage>(this as TicketMessage, _$identity);

  /// Serializes this TicketMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TicketMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.ticketId, ticketId) || other.ticketId == ticketId)&&(identical(other.authorId, authorId) || other.authorId == authorId)&&(identical(other.isStaff, isStaff) || other.isStaff == isStaff)&&(identical(other.body, body) || other.body == body)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ticketId,authorId,isStaff,body,createdAt);

@override
String toString() {
  return 'TicketMessage(id: $id, ticketId: $ticketId, authorId: $authorId, isStaff: $isStaff, body: $body, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $TicketMessageCopyWith<$Res>  {
  factory $TicketMessageCopyWith(TicketMessage value, $Res Function(TicketMessage) _then) = _$TicketMessageCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'ticket_id') String? ticketId,@JsonKey(name: 'author_id') String? authorId,@JsonKey(name: 'is_staff') bool isStaff, String body,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class _$TicketMessageCopyWithImpl<$Res>
    implements $TicketMessageCopyWith<$Res> {
  _$TicketMessageCopyWithImpl(this._self, this._then);

  final TicketMessage _self;
  final $Res Function(TicketMessage) _then;

/// Create a copy of TicketMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? ticketId = freezed,Object? authorId = freezed,Object? isStaff = null,Object? body = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ticketId: freezed == ticketId ? _self.ticketId : ticketId // ignore: cast_nullable_to_non_nullable
as String?,authorId: freezed == authorId ? _self.authorId : authorId // ignore: cast_nullable_to_non_nullable
as String?,isStaff: null == isStaff ? _self.isStaff : isStaff // ignore: cast_nullable_to_non_nullable
as bool,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [TicketMessage].
extension TicketMessagePatterns on TicketMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TicketMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TicketMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TicketMessage value)  $default,){
final _that = this;
switch (_that) {
case _TicketMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TicketMessage value)?  $default,){
final _that = this;
switch (_that) {
case _TicketMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'ticket_id')  String? ticketId, @JsonKey(name: 'author_id')  String? authorId, @JsonKey(name: 'is_staff')  bool isStaff,  String body, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TicketMessage() when $default != null:
return $default(_that.id,_that.ticketId,_that.authorId,_that.isStaff,_that.body,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'ticket_id')  String? ticketId, @JsonKey(name: 'author_id')  String? authorId, @JsonKey(name: 'is_staff')  bool isStaff,  String body, @JsonKey(name: 'created_at')  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _TicketMessage():
return $default(_that.id,_that.ticketId,_that.authorId,_that.isStaff,_that.body,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'ticket_id')  String? ticketId, @JsonKey(name: 'author_id')  String? authorId, @JsonKey(name: 'is_staff')  bool isStaff,  String body, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _TicketMessage() when $default != null:
return $default(_that.id,_that.ticketId,_that.authorId,_that.isStaff,_that.body,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TicketMessage implements TicketMessage {
  const _TicketMessage({required this.id, @JsonKey(name: 'ticket_id') this.ticketId, @JsonKey(name: 'author_id') this.authorId, @JsonKey(name: 'is_staff') this.isStaff = false, required this.body, @JsonKey(name: 'created_at') this.createdAt});
  factory _TicketMessage.fromJson(Map<String, dynamic> json) => _$TicketMessageFromJson(json);

@override final  String id;
@override@JsonKey(name: 'ticket_id') final  String? ticketId;
@override@JsonKey(name: 'author_id') final  String? authorId;
@override@JsonKey(name: 'is_staff') final  bool isStaff;
@override final  String body;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;

/// Create a copy of TicketMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TicketMessageCopyWith<_TicketMessage> get copyWith => __$TicketMessageCopyWithImpl<_TicketMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TicketMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TicketMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.ticketId, ticketId) || other.ticketId == ticketId)&&(identical(other.authorId, authorId) || other.authorId == authorId)&&(identical(other.isStaff, isStaff) || other.isStaff == isStaff)&&(identical(other.body, body) || other.body == body)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ticketId,authorId,isStaff,body,createdAt);

@override
String toString() {
  return 'TicketMessage(id: $id, ticketId: $ticketId, authorId: $authorId, isStaff: $isStaff, body: $body, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$TicketMessageCopyWith<$Res> implements $TicketMessageCopyWith<$Res> {
  factory _$TicketMessageCopyWith(_TicketMessage value, $Res Function(_TicketMessage) _then) = __$TicketMessageCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'ticket_id') String? ticketId,@JsonKey(name: 'author_id') String? authorId,@JsonKey(name: 'is_staff') bool isStaff, String body,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class __$TicketMessageCopyWithImpl<$Res>
    implements _$TicketMessageCopyWith<$Res> {
  __$TicketMessageCopyWithImpl(this._self, this._then);

  final _TicketMessage _self;
  final $Res Function(_TicketMessage) _then;

/// Create a copy of TicketMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? ticketId = freezed,Object? authorId = freezed,Object? isStaff = null,Object? body = null,Object? createdAt = freezed,}) {
  return _then(_TicketMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ticketId: freezed == ticketId ? _self.ticketId : ticketId // ignore: cast_nullable_to_non_nullable
as String?,authorId: freezed == authorId ? _self.authorId : authorId // ignore: cast_nullable_to_non_nullable
as String?,isStaff: null == isStaff ? _self.isStaff : isStaff // ignore: cast_nullable_to_non_nullable
as bool,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$TicketThread {

 SupportTicket get ticket; List<TicketMessage> get messages;
/// Create a copy of TicketThread
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TicketThreadCopyWith<TicketThread> get copyWith => _$TicketThreadCopyWithImpl<TicketThread>(this as TicketThread, _$identity);

  /// Serializes this TicketThread to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TicketThread&&(identical(other.ticket, ticket) || other.ticket == ticket)&&const DeepCollectionEquality().equals(other.messages, messages));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ticket,const DeepCollectionEquality().hash(messages));

@override
String toString() {
  return 'TicketThread(ticket: $ticket, messages: $messages)';
}


}

/// @nodoc
abstract mixin class $TicketThreadCopyWith<$Res>  {
  factory $TicketThreadCopyWith(TicketThread value, $Res Function(TicketThread) _then) = _$TicketThreadCopyWithImpl;
@useResult
$Res call({
 SupportTicket ticket, List<TicketMessage> messages
});


$SupportTicketCopyWith<$Res> get ticket;

}
/// @nodoc
class _$TicketThreadCopyWithImpl<$Res>
    implements $TicketThreadCopyWith<$Res> {
  _$TicketThreadCopyWithImpl(this._self, this._then);

  final TicketThread _self;
  final $Res Function(TicketThread) _then;

/// Create a copy of TicketThread
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ticket = null,Object? messages = null,}) {
  return _then(_self.copyWith(
ticket: null == ticket ? _self.ticket : ticket // ignore: cast_nullable_to_non_nullable
as SupportTicket,messages: null == messages ? _self.messages : messages // ignore: cast_nullable_to_non_nullable
as List<TicketMessage>,
  ));
}
/// Create a copy of TicketThread
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SupportTicketCopyWith<$Res> get ticket {
  
  return $SupportTicketCopyWith<$Res>(_self.ticket, (value) {
    return _then(_self.copyWith(ticket: value));
  });
}
}


/// Adds pattern-matching-related methods to [TicketThread].
extension TicketThreadPatterns on TicketThread {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TicketThread value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TicketThread() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TicketThread value)  $default,){
final _that = this;
switch (_that) {
case _TicketThread():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TicketThread value)?  $default,){
final _that = this;
switch (_that) {
case _TicketThread() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SupportTicket ticket,  List<TicketMessage> messages)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TicketThread() when $default != null:
return $default(_that.ticket,_that.messages);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SupportTicket ticket,  List<TicketMessage> messages)  $default,) {final _that = this;
switch (_that) {
case _TicketThread():
return $default(_that.ticket,_that.messages);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SupportTicket ticket,  List<TicketMessage> messages)?  $default,) {final _that = this;
switch (_that) {
case _TicketThread() when $default != null:
return $default(_that.ticket,_that.messages);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TicketThread implements TicketThread {
  const _TicketThread({required this.ticket, final  List<TicketMessage> messages = const <TicketMessage>[]}): _messages = messages;
  factory _TicketThread.fromJson(Map<String, dynamic> json) => _$TicketThreadFromJson(json);

@override final  SupportTicket ticket;
 final  List<TicketMessage> _messages;
@override@JsonKey() List<TicketMessage> get messages {
  if (_messages is EqualUnmodifiableListView) return _messages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_messages);
}


/// Create a copy of TicketThread
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TicketThreadCopyWith<_TicketThread> get copyWith => __$TicketThreadCopyWithImpl<_TicketThread>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TicketThreadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TicketThread&&(identical(other.ticket, ticket) || other.ticket == ticket)&&const DeepCollectionEquality().equals(other._messages, _messages));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ticket,const DeepCollectionEquality().hash(_messages));

@override
String toString() {
  return 'TicketThread(ticket: $ticket, messages: $messages)';
}


}

/// @nodoc
abstract mixin class _$TicketThreadCopyWith<$Res> implements $TicketThreadCopyWith<$Res> {
  factory _$TicketThreadCopyWith(_TicketThread value, $Res Function(_TicketThread) _then) = __$TicketThreadCopyWithImpl;
@override @useResult
$Res call({
 SupportTicket ticket, List<TicketMessage> messages
});


@override $SupportTicketCopyWith<$Res> get ticket;

}
/// @nodoc
class __$TicketThreadCopyWithImpl<$Res>
    implements _$TicketThreadCopyWith<$Res> {
  __$TicketThreadCopyWithImpl(this._self, this._then);

  final _TicketThread _self;
  final $Res Function(_TicketThread) _then;

/// Create a copy of TicketThread
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ticket = null,Object? messages = null,}) {
  return _then(_TicketThread(
ticket: null == ticket ? _self.ticket : ticket // ignore: cast_nullable_to_non_nullable
as SupportTicket,messages: null == messages ? _self._messages : messages // ignore: cast_nullable_to_non_nullable
as List<TicketMessage>,
  ));
}

/// Create a copy of TicketThread
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SupportTicketCopyWith<$Res> get ticket {
  
  return $SupportTicketCopyWith<$Res>(_self.ticket, (value) {
    return _then(_self.copyWith(ticket: value));
  });
}
}

// dart format on
