import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../domain/invoice_models.dart';
import 'invoice_list_notifier.dart';

enum InvoiceFilter { all, pending, paid }
enum InvoiceSort { newest, oldest, amountHigh, amountLow, nameAZ }

final invoiceSearchProvider = StateProvider<String>((ref) => '');
final invoiceFilterProvider = StateProvider<InvoiceFilter>((ref) => InvoiceFilter.all);
final invoiceSortProvider = StateProvider<InvoiceSort>((ref) => InvoiceSort.newest);

final filteredInvoicesProvider = Provider<List<Invoice>>((ref) {
  final invoices = ref.watch(invoiceListProvider);
  final filter = ref.watch(invoiceFilterProvider);
  final q = ref.watch(invoiceSearchProvider).trim().toLowerCase();
  final sort = ref.watch(invoiceSortProvider);

  Iterable<Invoice> items = invoices;

  // status filter
  if (filter == InvoiceFilter.paid) {
    items = items.where((e) => e.status == PaymentStatus.paid);
  } else if (filter == InvoiceFilter.pending) {
    items = items.where((e) => e.status == PaymentStatus.pending);
  }

  // search
  if (q.isNotEmpty) {
    items = items.where((e) {
      final name = e.draft.customerName.toLowerCase();
      final mobile = e.draft.customerMobile.toLowerCase();
      return name.contains(q) || mobile.contains(q);
    });
  }

  final list = items.toList();

  // sorting
  switch (sort) {
    case InvoiceSort.newest:
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      break;
    case InvoiceSort.oldest:
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      break;
    case InvoiceSort.amountHigh:
      list.sort((a, b) => b.total.compareTo(a.total));
      break;
    case InvoiceSort.amountLow:
      list.sort((a, b) => a.total.compareTo(b.total));
      break;
    case InvoiceSort.nameAZ:
      list.sort((a, b) => a.draft.customerName.toLowerCase().compareTo(
        b.draft.customerName.toLowerCase(),
      ));
      break;
  }

  return list;
});
