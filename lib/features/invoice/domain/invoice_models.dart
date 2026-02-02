enum PaymentStatus { pending, paid }

// ======================= INVOICE ITEM =======================

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

  InvoiceItem copyWith({String? name, int? qty, double? price}) {
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
    price: ((json['price'] ?? 0) as num).toDouble(),
  );
}

// ======================= INVOICE DRAFT =======================

class InvoiceDraft {
  final String customerName;
  final String customerMobile;
  final List<InvoiceItem> items;

  // ✅ Manual invoice number (used when mode = manual)
  final String customInvoiceNumber;

  const InvoiceDraft({
    required this.customerName,
    required this.customerMobile,
    required this.items,
    required this.customInvoiceNumber,
  });

  factory InvoiceDraft.initial() => const InvoiceDraft(
    customerName: '',
    customerMobile: '',
    items: [],
    customInvoiceNumber: '',
  );

  // ✅ Required by Invoice.total
  double get grandTotal =>
      items.fold(0.0, (sum, item) => sum + item.total);

  Map<String, dynamic> toJson() => {
    'customerName': customerName,
    'customerMobile': customerMobile,
    'items': items.map((e) => e.toJson()).toList(),
    'customInvoiceNumber': customInvoiceNumber,
  };

  factory InvoiceDraft.fromJson(Map<dynamic, dynamic> json) => InvoiceDraft(
    customerName: (json['customerName'] ?? '').toString(),
    customerMobile: (json['customerMobile'] ?? '').toString(),
    items: (json['items'] as List? ?? [])
        .map((e) => InvoiceItem.fromJson(e as Map))
        .toList(),
    customInvoiceNumber:
    (json['customInvoiceNumber'] ?? '').toString(),
  );

  InvoiceDraft copyWith({
    String? customerName,
    String? customerMobile,
    List<InvoiceItem>? items,
    String? customInvoiceNumber,
  }) {
    return InvoiceDraft(
      customerName: customerName ?? this.customerName,
      customerMobile: customerMobile ?? this.customerMobile,
      items: items ?? this.items,
      customInvoiceNumber:
      customInvoiceNumber ?? this.customInvoiceNumber,
    );
  }
}

// ======================= INVOICE =======================

class Invoice {
  final String id;
  final DateTime createdAt;
  final InvoiceDraft draft;
  final PaymentStatus status;
  final String invoiceNumber;

  const Invoice({
    required this.id,
    required this.createdAt,
    required this.draft,
    required this.status,
    required this.invoiceNumber,
  });

  double get total => draft.grandTotal;

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'draft': draft.toJson(),
    'status': status.toString().split('.').last, // web-safe
    'invoiceNumber': invoiceNumber,
  };

  factory Invoice.fromJson(Map<dynamic, dynamic> json) {
    final invNo = (json['invoiceNumber'] ?? '').toString();

    final statusRaw = (json['status'] ?? 'pending').toString();
    final statusValue =
    statusRaw.contains('.') ? statusRaw.split('.').last : statusRaw;

    final status = PaymentStatus.values.firstWhere(
          (e) => e.toString().split('.').last == statusValue,
      orElse: () => PaymentStatus.pending,
    );

    return Invoice(
      id: (json['id'] ?? '').toString(),
      invoiceNumber: invNo, // empty allowed for old invoices
      createdAt:
      DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      draft:
      InvoiceDraft.fromJson(json['draft'] as Map<dynamic, dynamic>),
      status: status,
    );
  }

  Invoice copyWith({PaymentStatus? status}) {
    return Invoice(
      id: id,
      createdAt: createdAt,
      draft: draft,
      status: status ?? this.status,
      invoiceNumber: invoiceNumber,
    );
  }
}
