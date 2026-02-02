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
    name: (json['name'] ?? '') as String,
    qty: (json['qty'] ?? 1) as int,
    price: ((json['price'] ?? 0) as num).toDouble(),
  );
}

class InvoiceDraft {
  final String customerName;
  final String customerMobile;
  final List<InvoiceItem> items;

  const InvoiceDraft({
    required this.customerName,
    required this.customerMobile,
    required this.items,
  });

  double get grandTotal => items.fold(0.0, (sum, item) => sum + item.total);

  InvoiceDraft copyWith({
    String? customerName,
    String? customerMobile,
    List<InvoiceItem>? items,
  }) {
    return InvoiceDraft(
      customerName: customerName ?? this.customerName,
      customerMobile: customerMobile ?? this.customerMobile,
      items: items ?? this.items,
    );
  }

  factory InvoiceDraft.empty() => const InvoiceDraft(
    customerName: '',
    customerMobile: '',
    items: [],
  );

  Map<String, dynamic> toJson() => {
    'customerName': customerName,
    'customerMobile': customerMobile,
    'items': items.map((e) => e.toJson()).toList(),
  };

  factory InvoiceDraft.fromJson(Map<dynamic, dynamic> json) => InvoiceDraft(
    customerName: (json['customerName'] ?? '') as String,
    customerMobile: (json['customerMobile'] ?? '') as String,
    items: ((json['items'] ?? []) as List)
        .map((e) => InvoiceItem.fromJson(e as Map<dynamic, dynamic>))
        .toList(),
  );
}

class Invoice {
  final String id;
  final DateTime createdAt;
  final InvoiceDraft draft;
  final PaymentStatus status;

  const Invoice({
    required this.id,
    required this.createdAt,
    required this.draft,
    required this.status,
  });

  double get total => draft.grandTotal;

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'draft': draft.toJson(),
    'status': status.name,
  };

  factory Invoice.fromJson(Map<dynamic, dynamic> json) => Invoice(
    id: (json['id'] ?? '') as String,
    createdAt: DateTime.tryParse(
      (json['createdAt'] ?? '') as String,
    ) ??
        DateTime.now(),
    draft: InvoiceDraft.fromJson(json['draft'] as Map<dynamic, dynamic>),
    status: PaymentStatus.values.firstWhere(
          (e) => e.name == (json['status'] ?? 'pending'),
      orElse: () => PaymentStatus.pending,
    ),
  );

  Invoice copyWith({PaymentStatus? status}) {
    return Invoice(
      id: id,
      createdAt: createdAt,
      draft: draft,
      status: status ?? this.status,
    );
  }
}