class Business {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String upiId;

  const Business({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.upiId,
  });

  Business copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? upiId,
  }) {
    return Business(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      upiId: upiId ?? this.upiId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'address': address,
    'upiId': upiId,
  };

  factory Business.fromJson(Map<dynamic, dynamic> json) => Business(
    id: (json['id'] ?? '').toString(),
    name: (json['name'] ?? '').toString(),
    phone: (json['phone'] ?? '').toString(),
    address: (json['address'] ?? '').toString(),
    upiId: (json['upiId'] ?? '').toString(),
  );
}
