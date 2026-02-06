class BusinessEntity {
  final String id;
  final String name;
  final String upiId;
  final String phone;
  final String address;

  /// ✅ NEW (file path on device)
  final String? imagePath;

  /// ✅ BACKWARD COMPAT: old code expects this
  /// (if you used base64 image earlier for PDF/logo)
  final String? logoBase64;

  final InvoiceNumberMode invoiceNumberMode;

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

    /// ✅ NEW
    String? imagePath,

    /// ✅ BACKWARD COMPAT
    String? logoBase64,
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

    /// ✅ NEW
    'imagePath': imagePath,

    /// ✅ BACKWARD COMPAT
    'logoBase64': logoBase64,
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

      /// ✅ NEW (backward compatible)
      imagePath: _cleanNullable(json['imagePath']),

      /// ✅ BACKWARD COMPAT (so existing notifier/PDF keeps working)
      logoBase64: _cleanNullable(json['logoBase64']),
    );
  }

  static InvoiceNumberMode _parseMode(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == 'manual') return InvoiceNumberMode.manual;
    return InvoiceNumberMode.auto;
  }
}

enum InvoiceNumberMode { auto, manual }
