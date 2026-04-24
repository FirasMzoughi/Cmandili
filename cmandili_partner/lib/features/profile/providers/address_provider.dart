import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/address_repository.dart';

class Address {
  final String id;
  final String name;
  final String fullAddress;
  final bool isDefault;

  Address({
    required this.id,
    required this.name,
    required this.fullAddress,
    this.isDefault = false,
  });

  Address copyWith({
    String? id,
    String? name,
    String? fullAddress,
    bool? isDefault,
  }) {
    return Address(
      id: id ?? this.id,
      name: name ?? this.name,
      fullAddress: fullAddress ?? this.fullAddress,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      fullAddress: map['full_address'] as String? ?? '',
      isDefault: map['is_default'] as bool? ?? false,
    );
  }
}

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  return AddressRepository();
});

class AddressNotifier extends StateNotifier<List<Address>> {
  final AddressRepository _repository;

  AddressNotifier(this._repository) : super([]) {
    loadAddresses();
  }

  Future<void> loadAddresses() async {
    final raw = await _repository.getUserAddresses();
    state = raw.map(Address.fromMap).toList();
  }

  Future<void> addAddress(String name, String fullAddress) async {
    final isFirst = state.isEmpty;
    final data = await _repository.addAddress(
      name: name,
      fullAddress: fullAddress,
      isDefault: isFirst,
    );
    if (data != null) {
      state = [...state, Address.fromMap(data)];
    }
  }

  Future<void> deleteAddress(String id) async {
    await _repository.deleteAddress(id);
    state = state.where((a) => a.id != id).toList();
  }

  Future<void> setDefault(String id) async {
    await _repository.setDefault(id);
    state = [
      for (final a in state)
        a.copyWith(isDefault: a.id == id),
    ];
  }
}

final addressProvider =
    StateNotifierProvider<AddressNotifier, List<Address>>((ref) {
  return AddressNotifier(ref.watch(addressRepositoryProvider));
});
