class Customer {
  final String id; // we keep id = mobile (unique) mostly
  final String name;
  final String mobile;

  // ✅ new
  final String? address;
  final String? imagePath; // local file path
  final DateTime createdAt; // joined date
  final DateTime updatedAt;

  const Customer({
    required this.id,
    required this.name,
    required this.mobile,
    this.address,
    this.imagePath,
    required this.createdAt,
    required this.updatedAt,
  });

  Customer copyWith({
    String? id,
    String? name,
    String? mobile,
    String? address,
    String? imagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      address: address ?? this.address,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mobile': mobile,
    'address': address,
    'imagePath': imagePath,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Customer.fromJson(Map<dynamic, dynamic> json) {
    DateTime _parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    return Customer(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      mobile: (json['mobile'] ?? '').toString(),
      address: (json['address'] ?? '').toString().trim().isEmpty
          ? null
          : (json['address'] ?? '').toString(),
      imagePath: (json['imagePath'] ?? '').toString().trim().isEmpty
          ? null
          : (json['imagePath'] ?? '').toString(),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }
}
