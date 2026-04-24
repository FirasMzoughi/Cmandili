import 'package:flutter_riverpod/flutter_riverpod.dart';

class PaymentMethod {
  final String id;
  final String cardHolderName;
  final String lastFourDigits;
  final String expiryDate;
  final bool isDefault;

  PaymentMethod({
    required this.id,
    required this.cardHolderName,
    required this.lastFourDigits,
    required this.expiryDate,
    this.isDefault = false,
  });

  PaymentMethod copyWith({
    String? id,
    String? cardHolderName,
    String? lastFourDigits,
    String? expiryDate,
    bool? isDefault,
  }) {
    return PaymentMethod(
      id: id ?? this.id,
      cardHolderName: cardHolderName ?? this.cardHolderName,
      lastFourDigits: lastFourDigits ?? this.lastFourDigits,
      expiryDate: expiryDate ?? this.expiryDate,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

class PaymentNotifier extends StateNotifier<List<PaymentMethod>> {
  PaymentNotifier()
      : super([
          PaymentMethod(
            id: '1',
            cardHolderName: 'John Doe',
            lastFourDigits: '4242',
            expiryDate: '12/25',
            isDefault: true,
          ),
        ]);

  void addCard(String cardHolderName, String cardNumber, String expiryDate) {
    final newCard = PaymentMethod(
      id: DateTime.now().toString(),
      cardHolderName: cardHolderName,
      lastFourDigits: cardNumber.length >= 4 
          ? cardNumber.substring(cardNumber.length - 4) 
          : 'xxxx',
      expiryDate: expiryDate,
      isDefault: state.isEmpty,
    );
    state = [...state, newCard];
  }

  void deleteCard(String id) {
    state = state.where((c) => c.id != id).toList();
  }
}

final paymentProvider = StateNotifierProvider<PaymentNotifier, List<PaymentMethod>>((ref) {
  return PaymentNotifier();
});
