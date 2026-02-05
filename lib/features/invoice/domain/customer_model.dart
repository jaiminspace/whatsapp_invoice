class Customer {
  final String id; // we keep id = mobile (unique)
  final String name;
  final String mobile;
  final String address; // ✅ NEW
  final DateTime updatedAt;

  const Customer({
    required this.id,
    required this.name,
    required this.mobile,
    required this.address,
    required this.updatedAt,
  });

  Customer copyWith({
    String? name,
    String? mobile,
    String? address,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      address: address ?? this.address,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mobile': mobile,
    'address': address,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Customer.fromJson(Map<dynamic, dynamic> json) {
    return Customer(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      mobile: (json['mobile'] ?? '').toString(),
      address: (json['address'] ?? '').toString(), // ✅ NEW (safe default)
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
