enum UnitType { pcs, kg, litre, meter }

class CatalogItem {
  final String id;
  final String businessId; // ✅ new
  final String name;
  final double price;
  final UnitType unit; // ✅ new
  final DateTime updatedAt;

  const CatalogItem({
    required this.id,
    required this.businessId,
    required this.name,
    required this.price,
    required this.unit,
    required this.updatedAt,
  });

  CatalogItem copyWith({
    String? id,
    String? businessId,
    String? name,
    double? price,
    UnitType? unit,
    DateTime? updatedAt,
  }) {
    return CatalogItem(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      price: price ?? this.price,
      unit: unit ?? this.unit,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'businessId': businessId,
    'name': name,
    'price': price,
    'unit': unit.name,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CatalogItem.fromJson(Map<dynamic, dynamic> json) {
    final updatedRaw = json['updatedAt'];

    UnitType parseUnit(dynamic raw) {
      final v = (raw ?? '').toString().trim().toLowerCase();
      for (final u in UnitType.values) {
        if (u.name.toLowerCase() == v) return u;
      }
      // ✅ backward compat: old items had no unit
      return UnitType.pcs;
    }

    return CatalogItem(
      id: (json['id'] ?? '').toString(),
      businessId: (json['businessId'] ?? '').toString(), // old data => ''
      name: (json['name'] ?? '').toString(),
      price: (json['price'] is num)
          ? (json['price'] as num).toDouble()
          : double.tryParse((json['price'] ?? '0').toString()) ?? 0.0,
      unit: parseUnit(json['unit']),
      updatedAt: updatedRaw == null
          ? DateTime.now()
          : DateTime.tryParse(updatedRaw.toString()) ?? DateTime.now(),
    );
  }
}
