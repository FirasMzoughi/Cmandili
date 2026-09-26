/// Maps a partner's `partner_type` onto the `vendors.category` it sells under.
///
/// The two legacy values ('restaurant', 'supermarket') predate the generic
/// vendors table and do not match their category ids, so they are translated
/// here. Every newer type ('flowers', 'pets', 'gifts', 'bakery',
/// 'electronics') already *is* its category id and passes straight through —
/// which is what lets a new shop type be launched without touching this file
/// again.
String vendorCategoryForPartnerType(String partnerType) {
  switch (partnerType) {
    case 'restaurant':
      return 'food';
    case 'supermarket':
      return 'grocery';
    default:
      return partnerType;
  }
}

/// Partner types this build can register, paired with how they are shown in
/// the sign-up picker.
const List<({String type, String label, String icon})> kPartnerTypes = [
  (type: 'restaurant', label: 'Restaurant', icon: '🍕'),
  (type: 'supermarket', label: 'Supermarché', icon: '🛒'),
  (type: 'bakery', label: 'Pâtisserie', icon: '🥐'),
  (type: 'flowers', label: 'Fleuriste', icon: '💐'),
  (type: 'pets', label: 'Animalerie', icon: '🐾'),
  (type: 'gifts', label: 'Cadeaux', icon: '🎁'),
  (type: 'electronics', label: 'Électronique', icon: '📱'),
];

/// True for the categories whose catalogue lives in `vendor_items`.
///
/// Restaurants and supermarkets keep their legacy tables; everything else
/// (bakery, flowers, pets, gifts, electronics) is generic. Written as "not one
/// of the two legacy types" on purpose, so launching a new category needs no
/// edit here.
bool isGenericVendorType(String partnerType) =>
    partnerType != 'restaurant' && partnerType != 'supermarket';

/// Human label for a partner type, e.g. 'flowers' -> 'Fleuriste'. Falls back to
/// the raw type so a type added to the DB before this list still shows
/// something sane instead of being mislabelled as another category.
String partnerTypeLabel(String partnerType) {
  for (final t in kPartnerTypes) {
    if (t.type == partnerType) return t.label;
  }
  return partnerType;
}

class PartnerProfile {
  final String userId;
  /// 'restaurant' | 'supermarket' | 'bakery' | 'flowers' | 'pets' | 'gifts'
  /// | 'electronics'. See [vendorCategoryForPartnerType] for how this maps
  /// onto `vendors.category`.
  final String partnerType;

  /// `vendors.id` of the shop this partner owns.
  final String entityId;
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
