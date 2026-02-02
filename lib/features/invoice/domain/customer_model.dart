class Customer {
  final String id; // mobile used as id for simplicity
  final String name;
  final String mobile;
  final DateTime updatedAt;

  const Customer({
    required this.id,
    required this.name,
    required this.mobile,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mobile': mobile,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Customer.fromJson(Map<dynamic, dynamic> json) => Customer(
    id: (json['id'] ?? '') as String,
    name: (json['name'] ?? '') as String,
    mobile: (json['mobile'] ?? '') as String,
    updatedAt: DateTime.tryParse((json['updatedAt'] ?? '') as String) ??
        DateTime.now(),
  );

  Customer copyWith({String? name, DateTime? updatedAt}) => Customer(
    id: id,
    name: name ?? this.name,
    mobile: mobile,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
