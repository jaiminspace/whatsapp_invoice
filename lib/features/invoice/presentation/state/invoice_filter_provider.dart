import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:whatsapp_invoice/features/invoice/domain/invoice_models.dart';
import 'package:whatsapp_invoice/features/invoice/presentation/state/invoice_list_notifier.dart';

enum InvoiceFilter { all, pending, paid }

final invoiceSearchProvider = StateProvider<String>((ref) => '');
final invoiceFilterProvider = StateProvider<InvoiceFilter>((ref) => InvoiceFilter.all);

final filteredInvoicesProvider = Provider<List<Invoice>>((ref) {
  final invoices = ref.watch(invoiceListProvider); // ✅ ONLY source
  final filter = ref.watch(invoiceFilterProvider);
  final q = ref.watch(invoiceSearchProvider).trim().toLowerCase();

  Iterable<Invoice> items = invoices;

  switch (filter) {
    case InvoiceFilter.paid:
      items = items.where((e) => e.status == PaymentStatus.paid);
      break;
    case InvoiceFilter.pending:
      items = items.where((e) => e.status == PaymentStatus.pending);
      break;
    case InvoiceFilter.all:
      break;
  }

  if (q.isNotEmpty) {
    items = items.where((e) {
      final name = e.draft.customerName.toLowerCase();
      final mobile = e.draft.customerMobile.toLowerCase();
      return name.contains(q) || mobile.contains(q);
    });
  }

  return items.toList();
});
