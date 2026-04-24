class DeliveryAddress {
  final String id;
  final String label; // e.g., "Home", "Work"
  final String fullAddress;
  final double latitude;
  final double longitude;
  final String? apartmentNumber;
  final String? floor;
  final String? instructions;
  final bool isDefault;

  DeliveryAddress({
    required this.id,
    required this.label,
    required this.fullAddress,
    required this.latitude,
    required this.longitude,
    this.apartmentNumber,
    this.floor,
    this.instructions,
    this.isDefault = false,
  });

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) {
    return DeliveryAddress(
      id: json['id'] ?? '',
      label: json['label'] ?? '',
      fullAddress: json['fullAddress'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      apartmentNumber: json['apartmentNumber'],
      floor: json['floor'],
      instructions: json['instructions'],
      isDefault: json['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'fullAddress': fullAddress,
      'latitude': latitude,
      'longitude': longitude,
      'apartmentNumber': apartmentNumber,
      'floor': floor,
      'instructions': instructions,
      'isDefault': isDefault,
    };
  }
}
