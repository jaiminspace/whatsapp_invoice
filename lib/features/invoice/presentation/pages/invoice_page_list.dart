import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_invoice/features/invoice/presentation/pages/businesses_page.dart';
import 'package:whatsapp_invoice/features/invoice/presentation/pages/items_page.dart';

import '../../domain/invoice_models.dart';
import '../state/invoice_filter_provider.dart';
import '../state/invoice_list_notifier.dart';

import 'create_invoice_page.dart';
import 'invoice_detail_page.dart';
import 'settings_page.dart';
import 'customers_page.dart';

class InvoiceListPage extends ConsumerStatefulWidget {
  const InvoiceListPage({super.key});

  @override
  ConsumerState<InvoiceListPage> createState() => _InvoiceListPageState();
}

class _InvoiceListPageState extends ConsumerState<InvoiceListPage> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateInvoicePage()),
    );

    // Optional UX
    _searchCtrl.clear();
    ref.read(invoiceSearchProvider.notifier).state = '';
    ref.read(invoiceFilterProvider.notifier).state = InvoiceFilter.all;
  }

  Future<void> _openDetail(Invoice inv) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InvoiceDetailPage(invoice: inv)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoices = ref.watch(filteredInvoicesProvider);
    final filter = ref.watch(invoiceFilterProvider);
    final sort = ref.watch(invoiceSortProvider);

    final grouped = _groupByMonth(invoices);

    return Scaffold(
      appBar: AppBar(
        title: const Text('InvoiceMaker'),
        actions: [
          IconButton(
            tooltip: 'Businesses',
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BusinessesPage()),
              );
            },
          ),
          IconButton(
            tooltip: 'Items Catalog',
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ItemsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.people_alt_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomersPage()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by customer name / mobile',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onChanged: (v) =>
              ref.read(invoiceSearchProvider.notifier).state = v,
            ),
          ),

          // Filter chips + Sort dropdown row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip(
                          label: 'All',
                          selected: filter == InvoiceFilter.all,
                          onTap: () => ref
                              .read(invoiceFilterProvider.notifier)
                              .state = InvoiceFilter.all,
                        ),
                        const SizedBox(width: 8),
                        _chip(
                          label: 'Paid',
                          selected: filter == InvoiceFilter.paid,
                          onTap: () => ref
                              .read(invoiceFilterProvider.notifier)
                              .state = InvoiceFilter.paid,
                        ),
                        const SizedBox(width: 8),
                        _chip(
                          label: 'Unpaid',
                          selected: filter == InvoiceFilter.pending,
                          onTap: () => ref
                              .read(invoiceFilterProvider.notifier)
                              .state = InvoiceFilter.pending,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Sort
                _SortButton(
                  value: sort,
                  onChanged: (v) =>
                  ref.read(invoiceSortProvider.notifier).state = v,
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Month-wise grouped list
          Expanded(
            child: invoices.isEmpty
                ? const Center(
              child: Text(
                'No invoices yet.\nTap + to create invoice',
                textAlign: TextAlign.center,
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final section = grouped[index];
                return _MonthSection(
                  title: section.title,
                  invoices: section.items,
                  onTapInvoice: _openDetail,
                  onDelete: (inv) async {
                    // simple confirm (you can swap with AppConfirmDialog)
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete invoice?'),
                        content: const Text(
                            'This invoice will be permanently deleted.'),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );

                    if (ok == true) {
                      await ref
                          .read(invoiceListProvider.notifier)
                          .deleteInvoice(inv.id);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

// ------------------ Grouping helpers ------------------

class _MonthSectionData {
  final String title;
  final List<Invoice> items;

  const _MonthSectionData({required this.title, required this.items});
}

List<_MonthSectionData> _groupByMonth(List<Invoice> invoices) {
  final now = DateTime.now();

  String monthName(int m) => const [
    'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
  ][m - 1];

  bool isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  final thisMonth = DateTime(now.year, now.month);
  final lastMonth = DateTime(now.year, now.month - 1);

  final map = <String, List<Invoice>>{};

  for (final inv in invoices) {
    final key = '${inv.createdAt.year}-${inv.createdAt.month.toString().padLeft(2, '0')}';
    (map[key] ??= []).add(inv);
  }

  // keys sorted DESC by month
  final keys = map.keys.toList()
    ..sort((a, b) => b.compareTo(a));

  return keys.map((k) {
    final parts = k.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final monthDate = DateTime(y, m);

    String title;
    if (isSameMonth(monthDate, thisMonth)) {
      title = 'This month';
    } else if (isSameMonth(monthDate, lastMonth)) {
      title = 'Last month';
    } else {
      title = '${monthName(m)} $y';
    }

    final items = map[k]!;
    return _MonthSectionData(title: title, items: items);
  }).toList();
}

// ------------------ Section widget ------------------

class _MonthSection extends StatelessWidget {
  final String title;
  final List<Invoice> invoices;
  final void Function(Invoice) onTapInvoice;
  final void Function(Invoice) onDelete;

  const _MonthSection({
    required this.title,
    required this.invoices,
    required this.onTapInvoice,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ...invoices.map((inv) => _InvoiceTile(
          inv: inv,
          onTap: () => onTapInvoice(inv),
          onDelete: () => onDelete(inv),
        )),
      ],
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  final Invoice inv;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _InvoiceTile({
    required this.inv,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = inv.draft.customerName.trim().isEmpty
        ? 'Customer'
        : inv.draft.customerName.trim();
    final amount = inv.total.toStringAsFixed(2);
    final isPaid = inv.status == PaymentStatus.paid;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.35),
        ),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          child: Text(name[0].toUpperCase()),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          inv.invoiceNumber.trim().isEmpty
              ? 'INV-${inv.id.substring(0, 8).toUpperCase()}'
              : inv.invoiceNumber,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹$amount',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: isPaid
                    ? Colors.green.withOpacity(0.18)
                    : Colors.orange.withOpacity(0.18),
              ),
              child: Text(
                isPaid ? 'PAID' : 'UNPAID',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isPaid ? Colors.green : Colors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------ Sort button ------------------

class _SortButton extends StatelessWidget {
  final InvoiceSort value;
  final ValueChanged<InvoiceSort> onChanged;

  const _SortButton({required this.value, required this.onChanged});

  String _label(InvoiceSort s) {
    switch (s) {
      case InvoiceSort.newest:
        return 'Newest';
      case InvoiceSort.oldest:
        return 'Oldest';
      case InvoiceSort.amountHigh:
        return 'Amount ↓';
      case InvoiceSort.amountLow:
        return 'Amount ↑';
      case InvoiceSort.nameAZ:
        return 'Name A–Z';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<InvoiceSort>(
      tooltip: 'Sort',
      onSelected: onChanged,
      itemBuilder: (_) => InvoiceSort.values
          .map(
            (s) => PopupMenuItem(
          value: s,
          child: Text(_label(s)),
        ),
      )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.45),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, size: 18),
            const SizedBox(width: 8),
            Text(_label(value)),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down, size: 18),
          ],
        ),
      ),
    );
  }
}
