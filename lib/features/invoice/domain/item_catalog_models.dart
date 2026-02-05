class CatalogItem {
  final String id;
  final String name;
  final double price;
  final DateTime updatedAt;

  const CatalogItem({
    required this.id,
    required this.name,
    required this.price,
    required this.updatedAt,
  });

  CatalogItem copyWith({
    String? id,
    String? name,
    double? price,
    DateTime? updatedAt,
  }) {
    return CatalogItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CatalogItem.fromJson(Map<dynamic, dynamic> json) {
    final updatedRaw = json['updatedAt'];

    return CatalogItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      price: (json['price'] is num)
          ? (json['price'] as num).toDouble()
          : double.tryParse((json['price'] ?? '0').toString()) ?? 0.0,
      updatedAt: updatedRaw == null
          ? DateTime.now()
          : DateTime.tryParse(updatedRaw.toString()) ?? DateTime.now(),
    );
  }
}
