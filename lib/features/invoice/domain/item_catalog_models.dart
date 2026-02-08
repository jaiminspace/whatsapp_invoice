// item_catalog_models.dart

enum UnitType { pcs, kg, litre, meter }

class CatalogItem {
  final String id;
  final String name;
  final double price;
  final UnitType unit;

  /// ✅ NEW: item can belong to multiple businesses
  /// If empty => treat as "global item for all businesses"
  final List<String> businessIds;

  final DateTime updatedAt;

  const CatalogItem({
    required this.id,
    required this.name,
    required this.price,
    required this.unit,
    required this.businessIds,
    required this.updatedAt,
  });

  CatalogItem copyWith({
    String? id,
    String? name,
    double? price,
    UnitType? unit,
    List<String>? businessIds,
    DateTime? updatedAt,
  }) {
    return CatalogItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      unit: unit ?? this.unit,
      businessIds: businessIds ?? this.businessIds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'unit': unit.name,
    'businessIds': businessIds,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CatalogItem.fromJson(Map<dynamic, dynamic> json) {
    UnitType parseUnit(dynamic raw) {
      final v = (raw ?? '').toString().trim().toLowerCase();
      for (final u in UnitType.values) {
        if (u.name.toLowerCase() == v) return u;
      }
      return UnitType.pcs; // ✅ backward default
    }

    List<String> parseBizIds(dynamic raw) {
      // new format
      if (raw is List) {
        return raw
            .map((e) => (e ?? '').toString().trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();
      }

      // ✅ backward compat: old items used `businessId`
      final legacy = (json['businessId'] ?? '').toString().trim();
      if (legacy.isNotEmpty) return [legacy];

      // old global items => global for all
      return <String>[];
    }

    final updatedRaw = json['updatedAt'];

    return CatalogItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      price: (json['price'] is num)
          ? (json['price'] as num).toDouble()
          : double.tryParse((json['price'] ?? '0').toString()) ?? 0.0,
      unit: parseUnit(json['unit']),
      businessIds: parseBizIds(json['businessIds']),
      updatedAt: updatedRaw == null
          ? DateTime.now()
          : DateTime.tryParse(updatedRaw.toString()) ?? DateTime.now(),
    );
  }
}
