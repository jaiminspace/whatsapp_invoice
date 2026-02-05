import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

import 'logs_page.dart';
import 'businesses_page.dart';
import 'items_page.dart';
import 'customers_page.dart';
import 'settings_page.dart';

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

    // Optional UX reset
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

    final filtered = ref.watch(filteredInvoicesProvider);
    final filter = ref.watch(invoiceFilterProvider);
    final sort = ref.watch(invoiceSortProvider);

    // summary based on all invoices
    final allInvoices = ref.watch(invoiceListProvider);
    final customers = ref.watch(customerListProvider);
    final items = ref.watch(catalogProvider);

    final totalPaid = allInvoices
        .where((e) => e.status == PaymentStatus.paid)
        .fold<double>(0, (sum, e) => sum + e.total);

    final totalUnpaid = allInvoices
        .where((e) => e.status != PaymentStatus.paid)
        .fold<double>(0, (sum, e) => sum + e.total);

    final grouped = _groupByMonth(filtered);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),

        // ✅ Logs icon ALWAYS visible
        actions: [
          IconButton(
            tooltip: 'Logs',
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LogsPage()),
              );
            },
          ),

          // Move everything else into "More" menu so icons don't disappear
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) {
              if (v == 'business') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BusinessesPage()),
                );
              } else if (v == 'items') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ItemsPage()),
                );
              } else if (v == 'customers') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CustomersPage()),
                );
              } else if (v == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'business', child: Text('Businesses')),
              PopupMenuItem(value: 'items', child: Text('Items Catalog')),
              PopupMenuItem(value: 'customers', child: Text('Customers')),
              PopupMenuItem(value: 'settings', child: Text('Settings')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreate(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // ================= SEARCH FIRST =================
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
              onChanged: (v) => ref.read(invoiceSearchProvider.notifier).state = v,
            ),
          ),

          // ================= FILTER + SORT =================
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
                          onTap: () =>
                          ref.read(invoiceFilterProvider.notifier).state =
                              InvoiceFilter.all,
                        ),
                        const SizedBox(width: 8),
                        _chip(
                          label: 'Paid',
                          selected: filter == InvoiceFilter.paid,
                          onTap: () =>
                          ref.read(invoiceFilterProvider.notifier).state =
                              InvoiceFilter.paid,
                        ),
                        const SizedBox(width: 8),
                        _chip(
                          label: 'Unpaid',
                          selected: filter == InvoiceFilter.pending,
                          onTap: () =>
                          ref.read(invoiceFilterProvider.notifier).state =
                              InvoiceFilter.pending,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _SortButton(
                  value: sort,
                  onChanged: (v) => ref.read(invoiceSortProvider.notifier).state = v,
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ================= SUMMARY CHIPS AFTER FILTER =================
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SummaryBox(
                        title: 'Total Paid',
                        value: '₹${totalPaid.toStringAsFixed(2)}',
                        valueColor: Colors.green,
                        icon: Icons.verified_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryBox(
                        title: 'Total Unpaid',
                        value: '₹${totalUnpaid.toStringAsFixed(2)}',
                        valueColor: Colors.red,
                        icon: Icons.pending_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryBox(
                        title: 'Invoices',
                        value: '${allInvoices.length}',
                        icon: Icons.receipt_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryBox(
                        title: 'Customers',
                        value: '${customers.length}',
                        icon: Icons.people_outline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ================= LIST =================
          Expanded(
            child: filtered.isEmpty
                ? const Center(
              child: Text(
                'No invoices yet.\nTap + to create invoice',
                textAlign: TextAlign.center,
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final section = grouped[index];
                return _MonthSection(
                  title: section.title,
                  invoices: section.items,
                  onTapInvoice: _openDetail,
                  onEditInvoice: (inv) => _openCreate(editInvoice: inv),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Widget _chip({
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

// ================= SUMMARY BOX =================

class _SummaryBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _SummaryBox({
    required this.title,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 72, // ✅ equal height in both rows
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
        color: cs.surface,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================= GROUPING HELPERS =================

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

  bool isSameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

  final thisMonth = DateTime(now.year, now.month);
  final lastMonth = DateTime(now.year, now.month - 1);

  final map = <String, List<Invoice>>{};

  for (final inv in invoices) {
    final key = '${inv.createdAt.year}-${inv.createdAt.month.toString().padLeft(2, '0')}';
    (map[key] ??= []).add(inv);
  }

  final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));

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
    // keep invoices sorted (most recent first) inside month
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return _MonthSectionData(title: title, items: items);
  }).toList();
}

// ================= MONTH SECTION =================

class _MonthSection extends StatelessWidget {
  final String title;
  final List<Invoice> invoices;
  final void Function(Invoice) onTapInvoice;
  final void Function(Invoice) onEditInvoice;

  const _MonthSection({
    required this.title,
    required this.invoices,
    required this.onTapInvoice,
    required this.onEditInvoice,
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
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        ...invoices.map(
              (inv) => _InvoiceTile(
            inv: inv,
            onTap: () => onTapInvoice(inv),
            onEdit: () => onEditInvoice(inv),
          ),
        ),
      ],
    );
  }
}

// ================= INVOICE TILE (beautiful + no overflow) =================

class _InvoiceTile extends ConsumerWidget {
  final Invoice inv;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _InvoiceTile({
    required this.inv,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    final name = inv.draft.customerName.trim().isEmpty
        ? 'Customer'
        : inv.draft.customerName.trim();

    final invNo = inv.invoiceNumber.trim().isNotEmpty
        ? inv.invoiceNumber.trim()
        : 'INV-${inv.id.substring(0, 8).toUpperCase()}';

    final dateStr = DateFormat('dd MMM, hh:mm a').format(inv.createdAt);

    final isPaid = inv.status == PaymentStatus.paid;

    final amount = inv.total.toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.40)),
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 3),
            color: Colors.black.withOpacity(0.04),
          )
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                child: Text(name[0].toUpperCase()),
              ),
              const SizedBox(width: 12),

              // middle info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$invNo • $dateStr',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // right side (amount + status + menu) -> fixed width so no overflow
              SizedBox(
                width: 150,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹$amount',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StatusChip(isPaid: isPaid),
                        const SizedBox(width: 6),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          onSelected: (v) async {
                            if (v == 'edit') {
                              onEdit();
                            } else if (v == 'delete') {
                              final ok = await AppConfirmDialog.show(
                                context,
                                title: 'Delete invoice?',
                                message: 'This invoice will be permanently deleted.',
                                confirmText: 'Delete',
                                isDanger: true,
                              );
                              if (!ok) return;

                              await ref
                                  .read(invoiceListProvider.notifier)
                                  .deleteInvoice(inv.id);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                          child: const Icon(Icons.more_vert, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isPaid;

  const _StatusChip({required this.isPaid});

  @override
  Widget build(BuildContext context) {
    final bg = isPaid ? Colors.green.withOpacity(0.16) : Colors.red.withOpacity(0.14);
    final fg = isPaid ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg,
      ),
      child: Text(
        isPaid ? 'PAID' : 'UNPAID',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: fg,
        ),
      ),
    );
  }
}

// ================= SORT BUTTON =================

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
