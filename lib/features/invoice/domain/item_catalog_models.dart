class CatalogItem {
  final String id;
  final String name;
  final double price; // default price

  const CatalogItem({
    required this.id,
    required this.name,
    required this.price,
  });

  CatalogItem copyWith({String? id, String? name, double? price}) {
    return CatalogItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
  };

  factory CatalogItem.fromJson(Map<dynamic, dynamic> json) => CatalogItem(
    id: (json['id'] ?? '').toString(),
    name: (json['name'] ?? '').toString(),
    price: ((json['price'] ?? 0) as num).toDouble(),
  );
}
