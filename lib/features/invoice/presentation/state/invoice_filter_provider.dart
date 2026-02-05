import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../domain/invoice_models.dart';
import '../state/invoice_list_notifier.dart';

// -------------------- Filter: Paid/Unpaid/All --------------------
enum InvoiceFilter { all, paid, pending }

final invoiceFilterProvider = StateProvider<InvoiceFilter>((ref) {
  return InvoiceFilter.all;
});

// -------------------- Search --------------------
final invoiceSearchProvider = StateProvider<String>((ref) => '');

// -------------------- Sort --------------------
enum InvoiceSort { newest, oldest, amountHigh, amountLow, nameAZ }

final invoiceSortProvider = StateProvider<InvoiceSort>((ref) {
  return InvoiceSort.newest;
});

// -------------------- Date Filters --------------------
enum InvoiceDateFilter {
  allTime,
  thisWeek,
  last7Days,
  last30Days,
  thisMonth,
  thisYear,
  custom,
}

final invoiceDateFilterProvider = StateProvider<InvoiceDateFilter>((ref) {
  return InvoiceDateFilter.allTime;
});

final invoiceCustomRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

// -------------------- Computed: Filtered + Sorted list --------------------
final filteredInvoicesProvider = Provider<List<Invoice>>((ref) {
  final list = ref.watch(invoiceListProvider);

  final filter = ref.watch(invoiceFilterProvider);
  final sort = ref.watch(invoiceSortProvider);
  final search = ref.watch(invoiceSearchProvider).trim().toLowerCase();

  final dateFilter = ref.watch(invoiceDateFilterProvider);
  final customRange = ref.watch(invoiceCustomRangeProvider);

  Iterable<Invoice> it = list;
  final now = DateTime.now();

  bool inRangeInclusive(DateTime dt, DateTime start, DateTime endInclusiveDate) {
    final startD = DateTime(start.year, start.month, start.day);
    final endD = DateTime(endInclusiveDate.year, endInclusiveDate.month, endInclusiveDate.day, 23, 59, 59);
    return !dt.isBefore(startD) && !dt.isAfter(endD);
  }

  DateTime startOfWeekMonday(DateTime d) {
    final onlyDate = DateTime(d.year, d.month, d.day);
    return onlyDate.subtract(Duration(days: onlyDate.weekday - 1)); // Monday
  }

  // 1) Date filter
  switch (dateFilter) {
    case InvoiceDateFilter.allTime:
      break;

    case InvoiceDateFilter.thisWeek:
      final start = startOfWeekMonday(now);
      final end = start.add(const Duration(days: 6));
      it = it.where((inv) => inRangeInclusive(inv.createdAt, start, end));
      break;

    case InvoiceDateFilter.last7Days:
      final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      final end = DateTime(now.year, now.month, now.day);
      it = it.where((inv) => inRangeInclusive(inv.createdAt, start, end));
      break;

    case InvoiceDateFilter.last30Days:
      final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
      final end = DateTime(now.year, now.month, now.day);
      it = it.where((inv) => inRangeInclusive(inv.createdAt, start, end));
      break;

    case InvoiceDateFilter.thisMonth:
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 0);
      it = it.where((inv) => inRangeInclusive(inv.createdAt, start, end));
      break;

    case InvoiceDateFilter.thisYear:
      final start = DateTime(now.year, 1, 1);
      final end = DateTime(now.year, 12, 31);
      it = it.where((inv) => inRangeInclusive(inv.createdAt, start, end));
      break;

    case InvoiceDateFilter.custom:
      if (customRange != null) {
        it = it.where((inv) => inRangeInclusive(inv.createdAt, customRange.start, customRange.end));
      }
      break;
  }

  // 2) Paid/unpaid filter
  if (filter == InvoiceFilter.paid) {
    it = it.where((inv) => inv.status == PaymentStatus.paid);
  } else if (filter == InvoiceFilter.pending) {
    it = it.where((inv) => inv.status == PaymentStatus.pending);
  }

  // 3) Search
  if (search.isNotEmpty) {
    it = it.where((inv) {
      final name = inv.draft.customerName.toLowerCase();
      final mobile = inv.draft.customerMobile.toLowerCase();
      final invNo = inv.invoiceNumber.toLowerCase();
      return name.contains(search) || mobile.contains(search) || invNo.contains(search);
    });
  }

  final out = it.toList(growable: false);

  // 4) Sort ✅ FIXED
  int byNameAZ(Invoice a, Invoice b) {
    final an = (a.draft.customerName.trim().isEmpty ? 'customer' : a.draft.customerName.trim()).toLowerCase();
    final bn = (b.draft.customerName.trim().isEmpty ? 'customer' : b.draft.customerName.trim()).toLowerCase();
    final c = an.compareTo(bn);
    if (c != 0) return c;
    return b.createdAt.compareTo(a.createdAt);
  }

  int byAmountHigh(Invoice a, Invoice b) {
    final c = b.total.compareTo(a.total);
    if (c != 0) return c;
    return b.createdAt.compareTo(a.createdAt);
  }

  int byAmountLow(Invoice a, Invoice b) {
    final c = a.total.compareTo(b.total);
    if (c != 0) return c;
    return b.createdAt.compareTo(a.createdAt);
  }

  switch (sort) {
    case InvoiceSort.newest:
      out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      break;
    case InvoiceSort.oldest:
      out.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      break;
    case InvoiceSort.amountHigh:
      out.sort(byAmountHigh);
      break;
    case InvoiceSort.amountLow:
      out.sort(byAmountLow);
      break;
    case InvoiceSort.nameAZ:
      out.sort(byNameAZ);
      break;
  }

  return out;
});
