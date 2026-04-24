// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'order_item_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

OrderItemModel _$OrderItemModelFromJson(Map<String, dynamic> json) {
  return _OrderItemModel.fromJson(json);
}

/// @nodoc
mixin _$OrderItemModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'order_id')
  String get orderId => throw _privateConstructorUsedError;
  @JsonKey(name: 'food_item_id')
  String get foodItemId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  double get price => throw _privateConstructorUsedError;
  int get quantity => throw _privateConstructorUsedError;
  List<String> get options => throw _privateConstructorUsedError;

  /// Serializes this OrderItemModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OrderItemModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrderItemModelCopyWith<OrderItemModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrderItemModelCopyWith<$Res> {
  factory $OrderItemModelCopyWith(
          OrderItemModel value, $Res Function(OrderItemModel) then) =
      _$OrderItemModelCopyWithImpl<$Res, OrderItemModel>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'order_id') String orderId,
      @JsonKey(name: 'food_item_id') String foodItemId,
      String name,
      double price,
      int quantity,
      List<String> options});
}

/// @nodoc
class _$OrderItemModelCopyWithImpl<$Res, $Val extends OrderItemModel>
    implements $OrderItemModelCopyWith<$Res> {
  _$OrderItemModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OrderItemModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? orderId = null,
    Object? foodItemId = null,
    Object? name = null,
    Object? price = null,
    Object? quantity = null,
    Object? options = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      orderId: null == orderId
          ? _value.orderId
          : orderId // ignore: cast_nullable_to_non_nullable
              as String,
      foodItemId: null == foodItemId
          ? _value.foodItemId
          : foodItemId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      price: null == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as double,
      quantity: null == quantity
          ? _value.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as int,
      options: null == options
          ? _value.options
          : options // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$OrderItemModelImplCopyWith<$Res>
    implements $OrderItemModelCopyWith<$Res> {
  factory _$$OrderItemModelImplCopyWith(_$OrderItemModelImpl value,
          $Res Function(_$OrderItemModelImpl) then) =
      __$$OrderItemModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'order_id') String orderId,
      @JsonKey(name: 'food_item_id') String foodItemId,
      String name,
      double price,
      int quantity,
      List<String> options});
}

/// @nodoc
class __$$OrderItemModelImplCopyWithImpl<$Res>
    extends _$OrderItemModelCopyWithImpl<$Res, _$OrderItemModelImpl>
    implements _$$OrderItemModelImplCopyWith<$Res> {
  __$$OrderItemModelImplCopyWithImpl(
      _$OrderItemModelImpl _value, $Res Function(_$OrderItemModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of OrderItemModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? orderId = null,
    Object? foodItemId = null,
    Object? name = null,
    Object? price = null,
    Object? quantity = null,
    Object? options = null,
  }) {
    return _then(_$OrderItemModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      orderId: null == orderId
          ? _value.orderId
          : orderId // ignore: cast_nullable_to_non_nullable
              as String,
      foodItemId: null == foodItemId
          ? _value.foodItemId
          : foodItemId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      price: null == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as double,
      quantity: null == quantity
          ? _value.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as int,
      options: null == options
          ? _value._options
          : options // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$OrderItemModelImpl implements _OrderItemModel {
  const _$OrderItemModelImpl(
      {required this.id,
      @JsonKey(name: 'order_id') required this.orderId,
      @JsonKey(name: 'food_item_id') required this.foodItemId,
      required this.name,
      required this.price,
      required this.quantity,
      final List<String> options = const []})
      : _options = options;

  factory _$OrderItemModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrderItemModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'order_id')
  final String orderId;
  @override
  @JsonKey(name: 'food_item_id')
  final String foodItemId;
  @override
  final String name;
  @override
  final double price;
  @override
  final int quantity;
  final List<String> _options;
  @override
  @JsonKey()
  List<String> get options {
    if (_options is EqualUnmodifiableListView) return _options;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_options);
  }

  @override
  String toString() {
    return 'OrderItemModel(id: $id, orderId: $orderId, foodItemId: $foodItemId, name: $name, price: $price, quantity: $quantity, options: $options)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrderItemModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.orderId, orderId) || other.orderId == orderId) &&
            (identical(other.foodItemId, foodItemId) ||
                other.foodItemId == foodItemId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            const DeepCollectionEquality().equals(other._options, _options));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, orderId, foodItemId, name,
      price, quantity, const DeepCollectionEquality().hash(_options));

  /// Create a copy of OrderItemModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrderItemModelImplCopyWith<_$OrderItemModelImpl> get copyWith =>
      __$$OrderItemModelImplCopyWithImpl<_$OrderItemModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OrderItemModelImplToJson(
      this,
    );
  }
}

abstract class _OrderItemModel implements OrderItemModel {
  const factory _OrderItemModel(
      {required final String id,
      @JsonKey(name: 'order_id') required final String orderId,
      @JsonKey(name: 'food_item_id') required final String foodItemId,
      required final String name,
      required final double price,
      required final int quantity,
      final List<String> options}) = _$OrderItemModelImpl;

  factory _OrderItemModel.fromJson(Map<String, dynamic> json) =
      _$OrderItemModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'order_id')
  String get orderId;
  @override
  @JsonKey(name: 'food_item_id')
  String get foodItemId;
  @override
  String get name;
  @override
  double get price;
  @override
  int get quantity;
  @override
  List<String> get options;

  /// Create a copy of OrderItemModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrderItemModelImplCopyWith<_$OrderItemModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
