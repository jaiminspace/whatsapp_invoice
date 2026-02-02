import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../domain/invoice_models.dart';
import '../state/invoice_list_notifier.dart';

enum DashboardRange { today, weekly, monthly, yearly }

final dashboardRangeProvider =
StateProvider<DashboardRange>((ref) => DashboardRange.today);

class TopCustomer {
  final String name;
  final String mobile;
  final double total;
  final int invoiceCount;

  const TopCustomer({
    required this.name,
    required this.mobile,
    required this.total,
    required this.invoiceCount,
  });
}

class DashboardData {
  final double paidAmount;
  final double pendingAmount;
  final int totalInvoices;

  final List<Invoice> recentInvoices;
  final List<TopCustomer> topCustomers;

  /// invoices count for last 7 days (only used for weekly chart)
  final List<int> last7DaysCounts; // length=7, oldest->newest
  final List<String> last7DaysLabels; // e.g. M,T,W,...

  const DashboardData({
    required this.paidAmount,
    required this.pendingAmount,
    required this.totalInvoices,
    required this.recentInvoices,
    required this.topCustomers,
    required this.last7DaysCounts,
    required this.last7DaysLabels,
  });
}

final dashboardDataProvider = Provider<DashboardData>((ref) {
  final invoices = ref.watch(invoiceListProvider);
  final range = ref.watch(dashboardRangeProvider);
  final now = DateTime.now();

  bool inRange(Invoice i) {
    final d = i.createdAt;

    if (range == DashboardRange.today) {
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }

    if (range == DashboardRange.weekly) {
      // ✅ Last 7 days including today
      final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      final endExclusive = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      return d.isAfter(start.subtract(const Duration(milliseconds: 1))) && d.isBefore(endExclusive);
    }

    if (range == DashboardRange.monthly) {
      return d.year == now.year && d.month == now.month;
    }

    // yearly
    return d.year == now.year;
  }

  final filtered = invoices.where(inRange).toList();

  double paid = 0;
  double pending = 0;

  for (final i in filtered) {
    if (i.status == PaymentStatus.paid) {
      paid += i.total;
    } else {
      pending += i.total;
    }
  }

  // Recent invoices (latest first)
  filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final recent = filtered.take(5).toList();

  // Top customers (by total amount) in selected range
  final Map<String, TopCustomer> map = {}; // key: mobile (or name+mobile)
  for (final inv in filtered) {
    final mobile = inv.draft.customerMobile.trim();
    final name = inv.draft.customerName.trim().isEmpty ? 'Customer' : inv.draft.customerName.trim();
    final key = mobile.isEmpty ? 'no_mobile:$name' : mobile;

    final existing = map[key];
    if (existing == null) {
      map[key] = TopCustomer(
        name: name,
        mobile: mobile,
        total: inv.total,
        invoiceCount: 1,
      );
    } else {
      map[key] = TopCustomer(
        name: existing.name,
        mobile: existing.mobile,
        total: existing.total + inv.total,
        invoiceCount: existing.invoiceCount + 1,
      );
    }
  }

  final topCustomers = map.values.toList()
    ..sort((a, b) => b.total.compareTo(a.total));
  final top10 = topCustomers.take(10).toList();

  // Last 7 days counts chart (for any range, still useful)
  final startDay = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
  final counts = List<int>.filled(7, 0);

  for (final inv in invoices) {
    final day = DateTime(inv.createdAt.year, inv.createdAt.month, inv.createdAt.day);
    final diff = day.difference(startDay).inDays;
    if (diff >= 0 && diff < 7) {
      counts[diff] += 1;
    }
  }

  const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  // Create last 7 day labels based on actual weekday
  final last7Labels = List<String>.generate(7, (i) {
    final d = startDay.add(Duration(days: i));
    return labels[(d.weekday - 1) % 7];
  });

  return DashboardData(
    paidAmount: paid,
    pendingAmount: pending,
    totalInvoices: filtered.length,
    recentInvoices: recent,
    topCustomers: top10,
    last7DaysCounts: counts,
    last7DaysLabels: last7Labels,
  );
});
