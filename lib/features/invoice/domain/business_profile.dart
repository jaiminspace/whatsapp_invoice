class BusinessProfile {
  final String name;
  final String phone;
  final String address;
  final String upiId;

  const BusinessProfile({
    required this.name,
    required this.phone,
    required this.address,
    required this.upiId,
  });

  factory BusinessProfile.empty() => const BusinessProfile(
    name: 'My Business',
    phone: '',
    address: '',
    upiId: '',
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'address': address,
    'upiId': upiId,
  };

  factory BusinessProfile.fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return BusinessProfile.empty();
    return BusinessProfile(
      name: (json['name'] ?? 'My Business') as String,
      phone: (json['phone'] ?? '') as String,
      address: (json['address'] ?? '') as String,
      upiId: (json['upiId'] ?? '') as String,
    );
  }

  BusinessProfile copyWith({
    String? name,
    String? phone,
    String? address,
    String? upiId,
  }) {
    return BusinessProfile(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      upiId: upiId ?? this.upiId,
    );
  }
}
