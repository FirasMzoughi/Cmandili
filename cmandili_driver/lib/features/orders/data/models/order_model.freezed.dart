// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'order_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

OrderModel _$OrderModelFromJson(Map<String, dynamic> json) {
  return _OrderModel.fromJson(json);
}

/// @nodoc
mixin _$OrderModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  String get userId => throw _privateConstructorUsedError;
  @JsonKey(name: 'restaurant_id')
  String get restaurantId => throw _privateConstructorUsedError;
  @JsonKey(name: 'driver_id')
  String? get driverId => throw _privateConstructorUsedError;
  String get status =>
      throw _privateConstructorUsedError; // pending, accepted, picked_up, delivered, cancelled
  @JsonKey(name: 'total_amount')
  double get totalAmount => throw _privateConstructorUsedError;
  @JsonKey(name: 'delivery_fee')
  double get deliveryFee => throw _privateConstructorUsedError;
  @JsonKey(name: 'payment_method')
  String get paymentMethod =>
      throw _privateConstructorUsedError; // cash, wallet
  @JsonKey(name: 'payment_status')
  String get paymentStatus => throw _privateConstructorUsedError;
  @JsonKey(name: 'delivery_address')
  Map<String, dynamic> get deliveryAddress =>
      throw _privateConstructorUsedError; // Store full address snapshot
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this OrderModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OrderModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrderModelCopyWith<OrderModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrderModelCopyWith<$Res> {
  factory $OrderModelCopyWith(
          OrderModel value, $Res Function(OrderModel) then) =
      _$OrderModelCopyWithImpl<$Res, OrderModel>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'user_id') String userId,
      @JsonKey(name: 'restaurant_id') String restaurantId,
      @JsonKey(name: 'driver_id') String? driverId,
      String status,
      @JsonKey(name: 'total_amount') double totalAmount,
      @JsonKey(name: 'delivery_fee') double deliveryFee,
      @JsonKey(name: 'payment_method') String paymentMethod,
      @JsonKey(name: 'payment_status') String paymentStatus,
      @JsonKey(name: 'delivery_address') Map<String, dynamic> deliveryAddress,
      @JsonKey(name: 'created_at') DateTime? createdAt});
}

/// @nodoc
class _$OrderModelCopyWithImpl<$Res, $Val extends OrderModel>
    implements $OrderModelCopyWith<$Res> {
  _$OrderModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OrderModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? restaurantId = null,
    Object? driverId = freezed,
    Object? status = null,
    Object? totalAmount = null,
    Object? deliveryFee = null,
    Object? paymentMethod = null,
    Object? paymentStatus = null,
    Object? deliveryAddress = null,
    Object? createdAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      restaurantId: null == restaurantId
          ? _value.restaurantId
          : restaurantId // ignore: cast_nullable_to_non_nullable
              as String,
      driverId: freezed == driverId
          ? _value.driverId
          : driverId // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      totalAmount: null == totalAmount
          ? _value.totalAmount
          : totalAmount // ignore: cast_nullable_to_non_nullable
              as double,
      deliveryFee: null == deliveryFee
          ? _value.deliveryFee
          : deliveryFee // ignore: cast_nullable_to_non_nullable
              as double,
      paymentMethod: null == paymentMethod
          ? _value.paymentMethod
          : paymentMethod // ignore: cast_nullable_to_non_nullable
              as String,
      paymentStatus: null == paymentStatus
          ? _value.paymentStatus
          : paymentStatus // ignore: cast_nullable_to_non_nullable
              as String,
      deliveryAddress: null == deliveryAddress
          ? _value.deliveryAddress
          : deliveryAddress // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$OrderModelImplCopyWith<$Res>
    implements $OrderModelCopyWith<$Res> {
  factory _$$OrderModelImplCopyWith(
          _$OrderModelImpl value, $Res Function(_$OrderModelImpl) then) =
      __$$OrderModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'user_id') String userId,
      @JsonKey(name: 'restaurant_id') String restaurantId,
      @JsonKey(name: 'driver_id') String? driverId,
      String status,
      @JsonKey(name: 'total_amount') double totalAmount,
      @JsonKey(name: 'delivery_fee') double deliveryFee,
      @JsonKey(name: 'payment_method') String paymentMethod,
      @JsonKey(name: 'payment_status') String paymentStatus,
      @JsonKey(name: 'delivery_address') Map<String, dynamic> deliveryAddress,
      @JsonKey(name: 'created_at') DateTime? createdAt});
}

/// @nodoc
class __$$OrderModelImplCopyWithImpl<$Res>
    extends _$OrderModelCopyWithImpl<$Res, _$OrderModelImpl>
    implements _$$OrderModelImplCopyWith<$Res> {
  __$$OrderModelImplCopyWithImpl(
      _$OrderModelImpl _value, $Res Function(_$OrderModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of OrderModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? restaurantId = null,
    Object? driverId = freezed,
    Object? status = null,
    Object? totalAmount = null,
    Object? deliveryFee = null,
    Object? paymentMethod = null,
    Object? paymentStatus = null,
    Object? deliveryAddress = null,
    Object? createdAt = freezed,
  }) {
    return _then(_$OrderModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      restaurantId: null == restaurantId
          ? _value.restaurantId
          : restaurantId // ignore: cast_nullable_to_non_nullable
              as String,
      driverId: freezed == driverId
          ? _value.driverId
          : driverId // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      totalAmount: null == totalAmount
          ? _value.totalAmount
          : totalAmount // ignore: cast_nullable_to_non_nullable
              as double,
      deliveryFee: null == deliveryFee
          ? _value.deliveryFee
          : deliveryFee // ignore: cast_nullable_to_non_nullable
              as double,
      paymentMethod: null == paymentMethod
          ? _value.paymentMethod
          : paymentMethod // ignore: cast_nullable_to_non_nullable
              as String,
      paymentStatus: null == paymentStatus
          ? _value.paymentStatus
          : paymentStatus // ignore: cast_nullable_to_non_nullable
              as String,
      deliveryAddress: null == deliveryAddress
          ? _value._deliveryAddress
          : deliveryAddress // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$OrderModelImpl implements _OrderModel {
  const _$OrderModelImpl(
      {required this.id,
      @JsonKey(name: 'user_id') required this.userId,
      @JsonKey(name: 'restaurant_id') required this.restaurantId,
      @JsonKey(name: 'driver_id') this.driverId,
      this.status = 'pending',
      @JsonKey(name: 'total_amount') required this.totalAmount,
      @JsonKey(name: 'delivery_fee') required this.deliveryFee,
      @JsonKey(name: 'payment_method') required this.paymentMethod,
      @JsonKey(name: 'payment_status') this.paymentStatus = 'pending',
      @JsonKey(name: 'delivery_address')
      required final Map<String, dynamic> deliveryAddress,
      @JsonKey(name: 'created_at') this.createdAt})
      : _deliveryAddress = deliveryAddress;

  factory _$OrderModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrderModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  @JsonKey(name: 'restaurant_id')
  final String restaurantId;
  @override
  @JsonKey(name: 'driver_id')
  final String? driverId;
  @override
  @JsonKey()
  final String status;
// pending, accepted, picked_up, delivered, cancelled
  @override
  @JsonKey(name: 'total_amount')
  final double totalAmount;
  @override
  @JsonKey(name: 'delivery_fee')
  final double deliveryFee;
  @override
  @JsonKey(name: 'payment_method')
  final String paymentMethod;
// cash, wallet
  @override
  @JsonKey(name: 'payment_status')
  final String paymentStatus;
  final Map<String, dynamic> _deliveryAddress;
  @override
  @JsonKey(name: 'delivery_address')
  Map<String, dynamic> get deliveryAddress {
    if (_deliveryAddress is EqualUnmodifiableMapView) return _deliveryAddress;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_deliveryAddress);
  }

// Store full address snapshot
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  @override
  String toString() {
    return 'OrderModel(id: $id, userId: $userId, restaurantId: $restaurantId, driverId: $driverId, status: $status, totalAmount: $totalAmount, deliveryFee: $deliveryFee, paymentMethod: $paymentMethod, paymentStatus: $paymentStatus, deliveryAddress: $deliveryAddress, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrderModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.restaurantId, restaurantId) ||
                other.restaurantId == restaurantId) &&
            (identical(other.driverId, driverId) ||
                other.driverId == driverId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.totalAmount, totalAmount) ||
                other.totalAmount == totalAmount) &&
            (identical(other.deliveryFee, deliveryFee) ||
                other.deliveryFee == deliveryFee) &&
            (identical(other.paymentMethod, paymentMethod) ||
                other.paymentMethod == paymentMethod) &&
            (identical(other.paymentStatus, paymentStatus) ||
                other.paymentStatus == paymentStatus) &&
            const DeepCollectionEquality()
                .equals(other._deliveryAddress, _deliveryAddress) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      userId,
      restaurantId,
      driverId,
      status,
      totalAmount,
      deliveryFee,
      paymentMethod,
      paymentStatus,
      const DeepCollectionEquality().hash(_deliveryAddress),
      createdAt);

  /// Create a copy of OrderModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrderModelImplCopyWith<_$OrderModelImpl> get copyWith =>
      __$$OrderModelImplCopyWithImpl<_$OrderModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OrderModelImplToJson(
      this,
    );
  }
}

abstract class _OrderModel implements OrderModel {
  const factory _OrderModel(
          {required final String id,
          @JsonKey(name: 'user_id') required final String userId,
          @JsonKey(name: 'restaurant_id') required final String restaurantId,
          @JsonKey(name: 'driver_id') final String? driverId,
          final String status,
          @JsonKey(name: 'total_amount') required final double totalAmount,
          @JsonKey(name: 'delivery_fee') required final double deliveryFee,
          @JsonKey(name: 'payment_method') required final String paymentMethod,
          @JsonKey(name: 'payment_status') final String paymentStatus,
          @JsonKey(name: 'delivery_address')
          required final Map<String, dynamic> deliveryAddress,
          @JsonKey(name: 'created_at') final DateTime? createdAt}) =
      _$OrderModelImpl;

  factory _OrderModel.fromJson(Map<String, dynamic> json) =
      _$OrderModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'user_id')
  String get userId;
  @override
  @JsonKey(name: 'restaurant_id')
  String get restaurantId;
  @override
  @JsonKey(name: 'driver_id')
  String? get driverId;
  @override
  String get status; // pending, accepted, picked_up, delivered, cancelled
  @override
  @JsonKey(name: 'total_amount')
  double get totalAmount;
  @override
  @JsonKey(name: 'delivery_fee')
  double get deliveryFee;
  @override
  @JsonKey(name: 'payment_method')
  String get paymentMethod; // cash, wallet
  @override
  @JsonKey(name: 'payment_status')
  String get paymentStatus;
  @override
  @JsonKey(name: 'delivery_address')
  Map<String, dynamic> get deliveryAddress; // Store full address snapshot
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;

  /// Create a copy of OrderModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrderModelImplCopyWith<_$OrderModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
