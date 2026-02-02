import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/invoice_models.dart';
import '../state/dashboard_provider.dart';

import 'create_invoice_page.dart';
import 'invoice_page_list.dart'; // your InvoiceListPage file name
import 'customers_page.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(dashboardRangeProvider);
    final data = ref.watch(dashboardDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        children: [
          _RangeChips(
            selected: range,
            onChange: (r) => ref.read(dashboardRangeProvider.notifier).state = r,
          ),

          const SizedBox(height: 14),

          // Summary cards
          _SummaryGrid(
            paid: data.paidAmount,
            pending: data.pendingAmount,
            count: data.totalInvoices,
          ),

          const SizedBox(height: 14),

          // Charts section
          _SectionCard(
            title: 'Analytics',
            subtitle: 'Quick view of collections & activity',
            child: Column(
              children: [
                _PaidPendingBar(
                  paid: data.paidAmount,
                  pending: data.pendingAmount,
                ),
                const SizedBox(height: 14),
                _InvoicesMiniBarChart(
                  counts: data.last7DaysCounts,
                  labels: data.last7DaysLabels,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Quick actions (modern big buttons)
          _QuickActions(
            onCreate: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateInvoicePage()),
            ),
            onInvoices: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InvoiceListPage()),
            ),
            onCustomers: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomersPage()),
            ),
            onAddCustomer: () {
              // If you have AddCustomerPage, navigate there.
              // Otherwise open CustomersPage and show "Add customer" bottom sheet from there.
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomersPage()),
              );
            },
          ),

          const SizedBox(height: 14),

          // Recent invoices
          _SectionCard(
            title: 'Recent invoices',
            subtitle: 'Latest 5 invoices in selected range',
            child: data.recentInvoices.isEmpty
                ? const _EmptyHint('No invoices found for this range.')
                : Column(
              children: data.recentInvoices.map((inv) {
                return _InvoiceRow(inv: inv);
              }).toList(),
            ),
          ),

          const SizedBox(height: 14),

          // Top customers
          _SectionCard(
            title: 'Top customers',
            subtitle: 'Top 10 customers by billing amount',
            child: data.topCustomers.isEmpty
                ? const _EmptyHint('No customer data yet.')
                : Column(
              children: data.topCustomers.map((c) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Text(
                      (c.name.isEmpty ? 'C' : c.name[0].toUpperCase()),
                    ),
                  ),
                  title: Text(c.name),
                  subtitle: Text(
                    c.mobile.isEmpty
                        ? '${c.invoiceCount} invoices'
                        : '${c.mobile} • ${c.invoiceCount} invoices',
                  ),
                  trailing: Text(
                    '₹${c.total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// =================== UI WIDGETS (polished) ===================

class _RangeChips extends StatelessWidget {
  final DashboardRange selected;
  final ValueChanged<DashboardRange> onChange;

  const _RangeChips({required this.selected, required this.onChange});

  String _label(DashboardRange r) {
    switch (r) {
      case DashboardRange.today:
        return 'Today';
      case DashboardRange.weekly:
        return 'Weekly';
      case DashboardRange.monthly:
        return 'Monthly';
      case DashboardRange.yearly:
        return 'Yearly';
    }
  }

  IconData _icon(DashboardRange r) {
    switch (r) {
      case DashboardRange.today:
        return Icons.today_outlined;
      case DashboardRange.weekly:
        return Icons.date_range_outlined;
      case DashboardRange.monthly:
        return Icons.calendar_month_outlined;
      case DashboardRange.yearly:
        return Icons.event_repeat_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: DashboardRange.values.map((r) {
        final isSelected = r == selected;
        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon(r), size: 18),
              const SizedBox(width: 6),
              Text(_label(r)),
            ],
          ),
          selected: isSelected,
          onSelected: (_) => onChange(r),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        );
      }).toList(),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final double paid;
  final double pending;
  final int count;

  const _SummaryGrid({
    required this.paid,
    required this.pending,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Pending',
            value: '₹${pending.toStringAsFixed(0)}',
            icon: Icons.schedule_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            title: 'Paid',
            value: '₹${paid.toStringAsFixed(0)}',
            icon: Icons.verified_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            title: 'Invoices',
            value: count.toString(),
            icon: Icons.receipt_long_rounded,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            cs.surfaceContainerHighest.withOpacity(0.9),
            cs.surfaceContainerHighest.withOpacity(0.55),
          ],
        ),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: cs.primary),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: cs.surfaceContainerHighest.withOpacity(0.55),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onInvoices;
  final VoidCallback onCustomers;
  final VoidCallback onAddCustomer;

  const _QuickActions({
    required this.onCreate,
    required this.onInvoices,
    required this.onCustomers,
    required this.onAddCustomer,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Quick actions',
      subtitle: 'Fast shortcuts for daily work',
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Create Invoice'),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onInvoices,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('All Invoices'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCustomers,
                  icon: const Icon(Icons.people_alt_outlined),
                  label: const Text('Customers'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAddCustomer,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Add New Customer'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  final Invoice inv;
  const _InvoiceRow({required this.inv});

  @override
  Widget build(BuildContext context) {
    final name = inv.draft.customerName.trim().isEmpty ? 'Customer' : inv.draft.customerName.trim();
    final isPaid = inv.status == PaymentStatus.paid;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            child: Text(name[0].toUpperCase()),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  inv.invoiceNumber.trim().isEmpty ? 'INV-${inv.id.substring(0, 8).toUpperCase()}' : inv.invoiceNumber,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${inv.total.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: isPaid ? Colors.green.withOpacity(0.18) : Colors.orange.withOpacity(0.18),
                ),
                child: Text(
                  isPaid ? 'PAID' : 'PENDING',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: isPaid ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _PaidPendingBar extends StatelessWidget {
  final double paid;
  final double pending;
  const _PaidPendingBar({required this.paid, required this.pending});

  @override
  Widget build(BuildContext context) {
    final total = (paid + pending);
    final paidPct = total <= 0 ? 0.0 : paid / total;
    final pendingPct = total <= 0 ? 0.0 : pending / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Paid vs Pending', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                Expanded(
                  flex: (paidPct * 1000).round().clamp(0, 1000),
                  child: Container(color: Colors.green.withOpacity(0.75)),
                ),
                Expanded(
                  flex: (pendingPct * 1000).round().clamp(0, 1000),
                  child: Container(color: Colors.orange.withOpacity(0.75)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Paid: ₹${paid.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green)),
            Text('Pending: ₹${pending.toStringAsFixed(0)}', style: const TextStyle(color: Colors.orange)),
          ],
        ),
      ],
    );
  }
}

class _InvoicesMiniBarChart extends StatelessWidget {
  final List<int> counts;
  final List<String> labels;

  const _InvoicesMiniBarChart({
    required this.counts,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = counts.isEmpty ? 0 : counts.reduce((a, b) => a > b ? a : b);
    final safeMax = maxVal <= 0 ? 1 : maxVal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Invoices activity (last 7 days)', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final v = counts[i];
              final h = (v / safeMax) * 90.0;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: h,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.75),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        labels[i],
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
