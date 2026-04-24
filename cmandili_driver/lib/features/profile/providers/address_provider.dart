import 'package:flutter_riverpod/flutter_riverpod.dart';

class Address {
  final String id;
  final String name; // Home, Work, etc.
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
}

class AddressNotifier extends StateNotifier<List<Address>> {
  AddressNotifier()
      : super([
          Address(
            id: '1',
            name: 'Home',
            fullAddress: '123 Jasmine Street, Tunis, Tunisia',
            isDefault: true,
          ),
          Address(
            id: '2',
            name: 'Work',
            fullAddress: '456 Tech Park, Ariana, Tunisia',
            isDefault: false,
          ),
        ]);

  void addAddress(String name, String fullAddress) {
    final newAddress = Address(
      id: DateTime.now().toString(),
      name: name,
      fullAddress: fullAddress,
      isDefault: state.isEmpty,
    );
    state = [...state, newAddress];
  }

  void deleteAddress(String id) {
    state = state.where((a) => a.id != id).toList();
  }

  void setDefault(String id) {
    state = [
      for (final address in state)
        if (address.id == id)
          address.copyWith(isDefault: true)
        else
          address.copyWith(isDefault: false)
    ];
  }
}

final addressProvider = StateNotifierProvider<AddressNotifier, List<Address>>((ref) {
  return AddressNotifier();
});
