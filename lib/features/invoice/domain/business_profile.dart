enum InvoiceNumberMode { auto, manual }

class BusinessProfile {
  final String name;
  final String phone;
  final String address;
  final String upiId;

  final InvoiceNumberMode invoiceNumberMode;

  const BusinessProfile({
    required this.name,
    required this.phone,
    required this.address,
    required this.upiId,
    required this.invoiceNumberMode,
  });

  factory BusinessProfile.initial() => const BusinessProfile(
    name: 'My Business',
    phone: '',
    address: '',
    upiId: '',
    invoiceNumberMode: InvoiceNumberMode.auto,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'address': address,
    'upiId': upiId,
    'invoiceNumberMode': invoiceNumberMode.toString().split('.').last, // web-safe
  };

  factory BusinessProfile.fromJson(Map<dynamic, dynamic> json) {
    final modeRaw = (json['invoiceNumberMode'] ?? 'auto').toString();
    final modeValue = modeRaw.contains('.') ? modeRaw.split('.').last : modeRaw;

    final mode = InvoiceNumberMode.values.firstWhere(
          (e) => e.toString().split('.').last == modeValue,
      orElse: () => InvoiceNumberMode.auto,
    );

    return BusinessProfile(
      name: (json['name'] ?? 'My Business').toString(),
      phone: (json['phone'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      upiId: (json['upiId'] ?? '').toString(),
      invoiceNumberMode: mode,
    );
  }

  BusinessProfile copyWith({
    String? name,
    String? phone,
    String? address,
    String? upiId,
    InvoiceNumberMode? invoiceNumberMode,
  }) {
    return BusinessProfile(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      upiId: upiId ?? this.upiId,
      invoiceNumberMode: invoiceNumberMode ?? this.invoiceNumberMode,
    );
  }
}
