// file: invoice_models.dart

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

  factory InvoiceItem.fromJson(Map<dynamic, dynamic> json) {
    final qtyRaw = json['qty'];
    final priceRaw = json['price'];

    final parsedQty = qtyRaw is int
        ? qtyRaw
        : (qtyRaw is num ? qtyRaw.toInt() : int.tryParse('$qtyRaw') ?? 1);

    final parsedPrice = priceRaw is num
        ? priceRaw.toDouble()
        : double.tryParse('$priceRaw') ?? 0.0;

    return InvoiceItem(
      name: (json['name'] ?? '').toString(),
      qty: parsedQty < 1 ? 1 : parsedQty,
      price: parsedPrice < 0 ? 0.0 : parsedPrice,
    );
  }
}

// ======================= INVOICE DRAFT =======================

class InvoiceDraft {
  final String customerName;
  final String customerMobile;
  final List<InvoiceItem> items;

  final String customInvoiceNumber; // manual mode input
  final DateTime invoiceDateTime; // selected invoice date/time

  final String businessId;

  const InvoiceDraft({
    required this.customerName,
    required this.customerMobile,
    required this.items,
    required this.customInvoiceNumber,
    required this.invoiceDateTime,
    required this.businessId,
  });

  factory InvoiceDraft.initial() => InvoiceDraft(
    customerName: '',
    customerMobile: '',
    items: const [],
    customInvoiceNumber: '',
    invoiceDateTime: DateTime.now(),
    businessId: ''
  );

  factory InvoiceDraft.empty() => InvoiceDraft.initial();

  double get grandTotal => items.fold(0.0, (sum, e) => sum + e.total);

  Map<String, dynamic> toJson() => {
    'customerName': customerName,
    'customerMobile': customerMobile,
    'items': items.map((e) => e.toJson()).toList(),
    'customInvoiceNumber': customInvoiceNumber,
    'invoiceDateTime': invoiceDateTime.toIso8601String(),
    'businessId': businessId,
  };

  factory InvoiceDraft.fromJson(Map<dynamic, dynamic> json) {
    final itemsRaw = (json['items'] as List?) ?? const [];
    final parsedItems = itemsRaw
        .map((e) => InvoiceItem.fromJson(e as Map<dynamic, dynamic>))
        .toList();

    final dt = DateTime.tryParse((json['invoiceDateTime'] ?? '').toString()) ??
        DateTime.now(); // fallback for old drafts

    return InvoiceDraft(
      customerName: (json['customerName'] ?? '').toString(),
      customerMobile: (json['customerMobile'] ?? '').toString(),
      items: parsedItems,
      customInvoiceNumber: (json['customInvoiceNumber'] ?? '').toString(),
      invoiceDateTime: dt,
      businessId: (json['businessId'] ?? '').toString(),
    );
  }

  InvoiceDraft copyWith({
    String? customerName,
    String? customerMobile,
    List<InvoiceItem>? items,
    String? customInvoiceNumber,
    DateTime? invoiceDateTime,
    String? businessId,
  }) {
    return InvoiceDraft(
      customerName: customerName ?? this.customerName,
      customerMobile: customerMobile ?? this.customerMobile,
      items: items ?? this.items,
      customInvoiceNumber: customInvoiceNumber ?? this.customInvoiceNumber,
      invoiceDateTime: invoiceDateTime ?? this.invoiceDateTime,
      businessId: businessId ?? this.businessId,
    );
  }
}

// ======================= INVOICE =======================

class Invoice {
  final String id;
  final DateTime createdAt; // ✅ source of truth for invoice date/time
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
    // ✅ FIX: serialize createdAt (NOT draft.invoiceDateTime)
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

    final draft = InvoiceDraft.fromJson(json['draft'] as Map<dynamic, dynamic>);

    // ✅ Backward-compatible:
    // if old data doesn't have createdAt, use draft.invoiceDateTime
    final createdAt =
        DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
            draft.invoiceDateTime;

    return Invoice(
      id: (json['id'] ?? '').toString(),
      invoiceNumber: invNo,
      createdAt: createdAt,
      draft: draft,
      status: status,
    );
  }

  Invoice copyWith({PaymentStatus? status, InvoiceDraft? draft}) {
    return Invoice(
      id: id,
      createdAt: createdAt,
      draft: draft ?? this.draft,
      status: status ?? this.status,
      invoiceNumber: invoiceNumber,
    );
  }
}
