import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/app_confirm_dialog.dart';
import '../../../../core/ui/first_run_setup_sheet.dart';

import '../../domain/invoice_models.dart';
import '../state/invoice_filter_provider.dart';
import '../state/invoice_list_notifier.dart';
import '../state/invoice_draft_notifier.dart';

import '../state/customer_notifier.dart';
import '../state/catalog_notifier.dart';

import 'create_invoice_page.dart';
import 'invoice_detail_page.dart';
import 'settings_page.dart';
import 'customers_page.dart';
import 'businesses_page.dart';
import 'items_page.dart';

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

  Future<void> _openCreate({Invoice? editInvoice}) async {
    if (editInvoice != null) {
      // Load invoice into draft for editing
      ref.read(invoiceDraftProvider.notifier).loadFromInvoice(editInvoice);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateInvoicePage(
            isEdit: true,
            editingInvoiceId: editInvoice.id,
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateInvoicePage()),
      );
    }

    // optional UX: reset search & filter
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FirstRunSetupSheet.maybeShow(context, ref);
    });

    final invoices = ref.watch(filteredInvoicesProvider); // filtered list
    final allInvoices = ref.watch(invoiceListProvider); // for totals (ignore filter)

    final filter = ref.watch(invoiceFilterProvider);
    final sort = ref.watch(invoiceSortProvider);

    final customers = ref.watch(customerListProvider);
    final items = ref.watch(catalogProvider);

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
            tooltip: 'Customers',
            icon: const Icon(Icons.people_alt_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomersPage()),
              );
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreate(),
        child: const Icon(Icons.add),
      ),
      body: CustomScrollView(
        slivers: [
          // ---------- Top controls (Search + Filter/Sort + Summary) ----------
          SliverToBoxAdapter(
            child: Column(
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

                // Filter chips + Sort
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
                      _SortButton(
                        value: sort,
                        onChanged: (v) =>
                        ref.read(invoiceSortProvider.notifier).state = v,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Summary Strip (horizontal scroll)
                _InvoiceSummaryStrip(
                  allInvoices: allInvoices,
                  totalCustomers: customers.length,
                  totalItems: items.length,
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),

          // ---------- List ----------
          if (invoices.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'No invoices yet.\nTap + to create invoice',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else ...[
            ..._buildMonthSlivers(
              invoices: invoices,
              onTapInvoice: (inv) => _openDetail(inv),
              onEdit: (inv) => _openCreate(editInvoice: inv),
              onDelete: (inv) async {
                final ok = await AppConfirmDialog.show(
                  context,
                  title: 'Delete invoice?',
                  message: 'This invoice will be permanently deleted.',
                  confirmText: 'Delete',
                  isDanger: true,
                );
                if (!ok) return;

                await ref.read(invoiceListProvider.notifier).deleteInvoice(inv.id);
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
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

// ================= Summary Strip =================

class _InvoiceSummaryStrip extends StatelessWidget {
  final List<Invoice> allInvoices;
  final int totalCustomers;
  final int totalItems;

  const _InvoiceSummaryStrip({
    required this.allInvoices,
    required this.totalCustomers,
    required this.totalItems,
  });

  @override
  Widget build(BuildContext context) {
    double paid = 0;
    double unpaid = 0;

    for (final inv in allInvoices) {
      if (inv.status == PaymentStatus.paid) {
        paid += inv.total;
      } else {
        unpaid += inv.total;
      }
    }

    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _SummaryCard(
            title: 'Total Paid',
            value: '₹${paid.toStringAsFixed(0)}',
            icon: Icons.check_circle_outline,
          ),
          _SummaryCard(
            title: 'Total Unpaid',
            value: '₹${unpaid.toStringAsFixed(0)}',
            icon: Icons.pending_actions,
          ),
          _SummaryCard(
            title: 'Total Invoices',
            value: '${allInvoices.length}',
            icon: Icons.receipt_long,
          ),
          _SummaryCard(
            title: 'Total Customers',
            value: '$totalCustomers',
            icon: Icons.people_outline,
          ),
          _SummaryCard(
            title: 'Total Items',
            value: '$totalItems',
            icon: Icons.inventory_2_outlined,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.35),
        ),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================= Month grouping -> slivers =================

class _MonthSectionData {
  final String title;
  final List<Invoice> items;

  const _MonthSectionData({required this.title, required this.items});
}

List<_MonthSectionData> _groupByMonth(List<Invoice> invoices) {
  final now = DateTime.now();

  String monthName(int m) =>
      const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];

  bool isSameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

  final thisMonth = DateTime(now.year, now.month);
  final lastMonth = DateTime(now.year, now.month - 1);

  final map = <String, List<Invoice>>{};

  for (final inv in invoices) {
    final key = '${inv.createdAt.year}-${inv.createdAt.month.toString().padLeft(2, '0')}';
    (map[key] ??= []).add(inv);
  }

  final keys = map.keys.toList()..sort((a, b) => b.compareTo(a)); // DESC

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

    return _MonthSectionData(title: title, items: map[k]!);
  }).toList();
}

List<Widget> _buildMonthSlivers({
  required List<Invoice> invoices,
  required void Function(Invoice) onTapInvoice,
  required void Function(Invoice) onEdit,
  required void Function(Invoice) onDelete,
}) {
  final grouped = _groupByMonth(invoices);
  final slivers = <Widget>[];

  for (final section in grouped) {
    slivers.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(
            section.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );

    slivers.add(
      SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, i) {
            final inv = section.items[i];
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: _InvoiceTile(
                inv: inv,
                onTap: () => onTapInvoice(inv),
                onEdit: () => onEdit(inv),
                onDelete: () => onDelete(inv),
              ),
            );
          },
          childCount: section.items.length,
        ),
      ),
    );
  }

  return slivers;
}

// ================= Invoice tile =================

class _InvoiceTile extends StatelessWidget {
  final Invoice inv;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _InvoiceTile({
    required this.inv,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = inv.draft.customerName.trim().isEmpty ? 'Customer' : inv.draft.customerName.trim();
    final amount = inv.total.toStringAsFixed(2);
    final isPaid = inv.status == PaymentStatus.paid;

    final invNo = inv.invoiceNumber.trim().isEmpty
        ? 'INV-${inv.id.substring(0, 8).toUpperCase()}'
        : inv.invoiceNumber.trim();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.35),
        ),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: ListTile(
        isThreeLine: true,
        dense: true,
        onTap: onTap,
        leading: CircleAvatar(
          child: Text(name[0].toUpperCase()),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(invNo),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹$amount',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
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
            const SizedBox(width: 6),
            PopupMenuButton<String>(
              tooltip: 'More',
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              onSelected: (v) async {
                // keep your existing edit/delete logic here
              },
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.more_vert),
              ),
            ),
          ],
        ),

      ),
    );
  }
}

// ================= Sort button =================

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
          .map((s) => PopupMenuItem(value: s, child: Text(_label(s))))
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
