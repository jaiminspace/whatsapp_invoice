// invoice_models.dart

enum PaymentStatus { pending, paid }

class InvoiceItem {
  final String name;
  final int qty;
  final double price;

  const InvoiceItem({
    required this.name,
    required this.qty,
    required this.price,
  });

  double get total => qty * price;

  InvoiceItem copyWith({
    String? name,
    int? qty,
    double? price,
  }) {
    return InvoiceItem(
      name: name ?? this.name,
      qty: qty ?? this.qty,
      price: price ?? this.price,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'qty': qty,
    'price': price,
  };

  factory InvoiceItem.fromJson(Map<dynamic, dynamic> json) => InvoiceItem(
    name: (json['name'] ?? '').toString(),
    qty: (json['qty'] ?? 1) as int,
    price: (json['price'] ?? 0).toDouble(),
  );
}

class InvoiceDraft {
  final String customerName;
  final String customerMobile;
  final String customInvoiceNumber;
  final DateTime invoiceDateTime;

  // ✅ multi-business
  final String businessId;

  // ✅ invoice items
  final List<InvoiceItem> items;

  // ✅ NEW: invoice type stored in draft
  final PaymentStatus status;

  const InvoiceDraft({
    required this.customerName,
    required this.customerMobile,
    required this.customInvoiceNumber,
    required this.invoiceDateTime,
    required this.businessId,
    required this.items,
    required this.status,
  });

  factory InvoiceDraft.empty() => InvoiceDraft(
    customerName: '',
    customerMobile: '',
    customInvoiceNumber: '',
    invoiceDateTime: DateTime.now(),
    businessId: '',
    items: const [],
    status: PaymentStatus.pending, // ✅ default unpaid
  );

  InvoiceDraft copyWith({
    String? customerName,
    String? customerMobile,
    String? customInvoiceNumber,
    DateTime? invoiceDateTime,
    String? businessId,
    List<InvoiceItem>? items,
    PaymentStatus? status,
  }) {
    return InvoiceDraft(
      customerName: customerName ?? this.customerName,
      customerMobile: customerMobile ?? this.customerMobile,
      customInvoiceNumber: customInvoiceNumber ?? this.customInvoiceNumber,
      invoiceDateTime: invoiceDateTime ?? this.invoiceDateTime,
      businessId: businessId ?? this.businessId,
      items: items ?? this.items,
      status: status ?? this.status,
    );
  }

  double get grandTotal =>
      items.fold(0.0, (sum, e) => sum + (e.qty * e.price));

  Map<String, dynamic> toJson() => {
    'customerName': customerName,
    'customerMobile': customerMobile,
    'customInvoiceNumber': customInvoiceNumber,
    'invoiceDateTime': invoiceDateTime.toIso8601String(),
    'businessId': businessId,
    'items': items.map((e) => e.toJson()).toList(),
    'status': status.name,
  };

  factory InvoiceDraft.fromJson(Map<dynamic, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    return InvoiceDraft(
      customerName: (json['customerName'] ?? '').toString(),
      customerMobile: (json['customerMobile'] ?? '').toString(),
      customInvoiceNumber: (json['customInvoiceNumber'] ?? '').toString(),
      invoiceDateTime: DateTime.tryParse((json['invoiceDateTime'] ?? '').toString()) ??
          DateTime.now(),
      businessId: (json['businessId'] ?? '').toString(),
      items: rawItems
          .whereType<Map>()
          .map((e) => InvoiceItem.fromJson(e))
          .toList(),
      status: PaymentStatus.values.firstWhere(
            (e) => e.name == (json['status'] ?? 'pending'),
        orElse: () => PaymentStatus.pending,
      ),
    );
  }
}

class Invoice {
  final String id;
  final DateTime createdAt;
  final InvoiceDraft draft;
  final String invoiceNumber;
  final PaymentStatus status;

  const Invoice({
    required this.id,
    required this.createdAt,
    required this.draft,
    required this.invoiceNumber,
    required this.status,
  });

  double get total => draft.grandTotal;

  Invoice copyWith({
    DateTime? createdAt,
    InvoiceDraft? draft,
    String? invoiceNumber,
    PaymentStatus? status,
  }) {
    return Invoice(
      id: id,
      createdAt: createdAt ?? this.createdAt,
      draft: draft ?? this.draft,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'draft': draft.toJson(),
    'invoiceNumber': invoiceNumber,
    'status': status.name,
  };

  factory Invoice.fromJson(Map<dynamic, dynamic> json) => Invoice(
    id: json['id'].toString(),
    createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
        DateTime.now(),
    draft: InvoiceDraft.fromJson((json['draft'] as Map?) ?? {}),
    invoiceNumber: (json['invoiceNumber'] ?? '').toString(),
    status: PaymentStatus.values.firstWhere(
          (e) => e.name == (json['status'] ?? 'pending'),
      orElse: () => PaymentStatus.pending,
    ),
  );
}
