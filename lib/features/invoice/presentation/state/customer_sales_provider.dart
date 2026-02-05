import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/invoice_list_notifier.dart';
import '../state/customer_notifier.dart';

/// Maps customerId/mobile -> total sales amount (sum of invoice.total)
final customerTotalSalesProvider = Provider<Map<String, double>>((ref) {
  final customers = ref.watch(customerListProvider);
  final invoices = ref.watch(invoiceListProvider);

  // default 0 for all customers
  final map = <String, double>{
    for (final c in customers) c.id: 0.0,
  };

  for (final inv in invoices) {
    final mobile = inv.draft.customerMobile.trim();
    if (mobile.isEmpty) continue;

    // If your customer.id == mobile (your code suggests it is),
    // this will correctly accumulate totals.
    final key = mobile;

    map[key] = (map[key] ?? 0.0) + inv.total;
  }

  return map;
});
