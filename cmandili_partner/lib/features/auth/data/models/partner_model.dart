class PartnerProfile {
  final String userId;
  final String partnerType; // 'restaurant' | 'supermarket'
  final String entityId;    // restaurants.id or supermarkets.id
  final String businessName;
  final String address;
  final String? phone;
  final String? bio;
  final String? avatarUrl;

  PartnerProfile({
    required this.userId,
    required this.partnerType,
    required this.entityId,
    required this.businessName,
    this.address = '',
    this.phone,
    this.bio,
    this.avatarUrl,
  });

  factory PartnerProfile.fromJson(Map<String, dynamic> json) {
    return PartnerProfile(
      userId: json['user_id'] as String? ?? '',
      partnerType: json['partner_type'] as String? ?? 'restaurant',
      entityId: json['entity_id'] as String? ?? '',
      businessName: json['business_name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      phone: json['phone'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'partner_type': partnerType,
      'entity_id': entityId,
      'business_name': businessName,
      'address': address,
      if (phone != null) 'phone': phone,
      if (bio != null) 'bio': bio,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
  }

  PartnerProfile copyWith({
    String? businessName,
    String? address,
    String? phone,
    String? bio,
    String? avatarUrl,
  }) {
    return PartnerProfile(
      userId: userId,
      partnerType: partnerType,
      entityId: entityId,
      businessName: businessName ?? this.businessName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
