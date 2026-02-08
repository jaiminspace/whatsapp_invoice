import 'item_catalog_models.dart'; // UnitType

enum BusinessType {
  general,
  grocery,
  dairy,
  hardware,
  restaurant,
  service,
}

extension BusinessTypeX on BusinessType {
  String get label {
    switch (this) {
      case BusinessType.general:
        return 'General';
      case BusinessType.grocery:
        return 'Grocery';
      case BusinessType.dairy:
        return 'Dairy';
      case BusinessType.hardware:
        return 'Hardware';
      case BusinessType.restaurant:
        return 'Restaurant';
      case BusinessType.service:
        return 'Service';
    }
  }
}

BusinessType _parseBusinessType(String raw) {
  final v = raw.trim().toLowerCase();
  for (final t in BusinessType.values) {
    if (t.name.toLowerCase() == v) return t;
  }
  return BusinessType.general;
}

UnitType _parseUnit(String raw) {
  final v = raw.trim().toLowerCase();
  for (final u in UnitType.values) {
    if (u.name.toLowerCase() == v) return u;
  }
  return UnitType.pcs;
}

List<UnitType> _parseUnits(dynamic raw) {
  if (raw is List) {
    final out = <UnitType>[];
    for (final e in raw) {
      out.add(_parseUnit((e ?? '').toString()));
    }
    if (out.isNotEmpty) return out;
  }
  // ✅ Default allowed units
  return const [UnitType.pcs, UnitType.kg, UnitType.litre];
}

class BusinessEntity {
  final String id;
  final String name;
  final String upiId;
  final String phone;
  final String address;

  final String? imagePath;
  final String? logoBase64;

  final InvoiceNumberMode invoiceNumberMode;

  final BusinessType businessType;
  final UnitType defaultUnit;
  final List<UnitType> allowedUnits;

  final DateTime createdAt;
  final DateTime updatedAt;

  const BusinessEntity({
    required this.id,
    required this.name,
    required this.upiId,
    required this.phone,
    required this.address,
    required this.invoiceNumberMode,
    required this.createdAt,
    required this.updatedAt,
    this.imagePath,
    this.logoBase64,
    this.businessType = BusinessType.general,
    this.defaultUnit = UnitType.pcs,
    this.allowedUnits = const [UnitType.pcs, UnitType.kg, UnitType.litre],
  });

  factory BusinessEntity.create(String name) {
    final now = DateTime.now();
    return BusinessEntity(
      id: now.microsecondsSinceEpoch.toString(),
      name: name.trim(),
      upiId: '',
      phone: '',
      address: '',
      invoiceNumberMode: InvoiceNumberMode.auto,
      createdAt: now,
      updatedAt: now,
      imagePath: null,
      logoBase64: null,
      businessType: BusinessType.general,
      defaultUnit: UnitType.pcs,
      allowedUnits: const [UnitType.pcs, UnitType.kg, UnitType.litre],
    );
  }

  BusinessEntity copyWith({
    String? id,
    String? name,
    String? upiId,
    String? phone,
    String? address,
    InvoiceNumberMode? invoiceNumberMode,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? imagePath,
    String? logoBase64,
    BusinessType? businessType,
    UnitType? defaultUnit,
    List<UnitType>? allowedUnits,
  }) {
    return BusinessEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      upiId: upiId ?? this.upiId,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      invoiceNumberMode: invoiceNumberMode ?? this.invoiceNumberMode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imagePath: imagePath ?? this.imagePath,
      logoBase64: logoBase64 ?? this.logoBase64,
      businessType: businessType ?? this.businessType,
      defaultUnit: defaultUnit ?? this.defaultUnit,
      allowedUnits: allowedUnits ?? this.allowedUnits,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'upiId': upiId,
    'phone': phone,
    'address': address,
    'invoiceNumberMode': invoiceNumberMode.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'imagePath': imagePath,
    'logoBase64': logoBase64,
    'businessType': businessType.name,
    'defaultUnit': defaultUnit.name,
    'allowedUnits': allowedUnits.map((e) => e.name).toList(),
  };

  factory BusinessEntity.fromJson(Map json) {
    String? _cleanNullable(dynamic v) {
      final s = (v as String?)?.trim();
      if (s == null || s.isEmpty) return null;
      return s;
    }

    return BusinessEntity(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      upiId: (json['upiId'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      invoiceNumberMode:
      _parseMode((json['invoiceNumberMode'] ?? '').toString()),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
      imagePath: _cleanNullable(json['imagePath']),
      logoBase64: _cleanNullable(json['logoBase64']),
      businessType: _parseBusinessType((json['businessType'] ?? '').toString()),
      defaultUnit: _parseUnit((json['defaultUnit'] ?? '').toString()),
      allowedUnits: _parseUnits(json['allowedUnits']),
    );
  }

  static InvoiceNumberMode _parseMode(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == 'manual') return InvoiceNumberMode.manual;
    return InvoiceNumberMode.auto;
  }
}

enum InvoiceNumberMode { auto, manual }
