enum InvoiceNumberMode { auto, manual }

class BusinessEntity {
  final String id;
  final String name;

  final String upiId;
  final String phone;
  final String address;

  /// ✅ NEW: store business logo/image in base64 (works web + mobile)
  final String logoBase64;

  final InvoiceNumberMode invoiceNumberMode;
  final int invoiceCounter;

  const BusinessEntity({
    required this.id,
    required this.name,
    required this.upiId,
    required this.phone,
    required this.address,
    required this.logoBase64,
    required this.invoiceNumberMode,
    required this.invoiceCounter,
  });

  factory BusinessEntity.create(String name) {
    return BusinessEntity(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      upiId: '',
      phone: '',
      address: '',
      logoBase64: '',
      invoiceNumberMode: InvoiceNumberMode.auto,
      invoiceCounter: 0,
    );
  }

  BusinessEntity copyWith({
    String? name,
    String? upiId,
    String? phone,
    String? address,
    String? logoBase64,
    InvoiceNumberMode? invoiceNumberMode,
    int? invoiceCounter,
  }) {
    return BusinessEntity(
      id: id,
      name: name ?? this.name,
      upiId: upiId ?? this.upiId,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      logoBase64: logoBase64 ?? this.logoBase64,
      invoiceNumberMode: invoiceNumberMode ?? this.invoiceNumberMode,
      invoiceCounter: invoiceCounter ?? this.invoiceCounter,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'upiId': upiId,
    'phone': phone,
    'address': address,
    'logoBase64': logoBase64,
    'invoiceNumberMode': invoiceNumberMode.name,
    'invoiceCounter': invoiceCounter,
  };

  factory BusinessEntity.fromJson(Map<dynamic, dynamic> json) {
    return BusinessEntity(
      id: json['id'].toString(),
      name: (json['name'] ?? '').toString(),
      upiId: (json['upiId'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      logoBase64: (json['logoBase64'] ?? '').toString(),
      invoiceNumberMode: InvoiceNumberMode.values.firstWhere(
            (e) => e.name == (json['invoiceNumberMode'] ?? 'auto'),
        orElse: () => InvoiceNumberMode.auto,
      ),
      invoiceCounter: (json['invoiceCounter'] ?? 0) as int,
    );
  }
}
