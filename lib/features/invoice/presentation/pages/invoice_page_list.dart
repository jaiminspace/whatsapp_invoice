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

// ✅ change if your file/class name is different
import 'logs_page.dart';

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
      // ✅ FORCE refresh every time returning
      await ref.read(invoiceListProvider.notifier).refresh();
    }

    // ✅ IMPORTANT: force refresh so newly added/edited invoice shows immediately
    ref.invalidate(invoiceListProvider);

    // ❌ Do NOT reset filters/search/date here.
    // Keep user’s selected Paid/Unpaid/Date range exactly as-is.
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

    final invoices = ref.watch(filteredInvoicesProvider);

    final filter = ref.watch(invoiceFilterProvider);
    final sort = ref.watch(invoiceSortProvider);

    final dateFilter = ref.watch(invoiceDateFilterProvider);
    final customRange = ref.watch(invoiceCustomRangeProvider);

    final customers = ref.watch(customerListProvider);
    final items = ref.watch(catalogProvider);

    final totalPaid = invoices
        .where((e) => e.status == PaymentStatus.paid)
        .fold<double>(0, (p, e) => p + e.total);

    final totalUnpaid = invoices
        .where((e) => e.status == PaymentStatus.pending)
        .fold<double>(0, (p, e) => p + e.total);

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
          // ✅ Logs icon
          IconButton(
            tooltip: 'Activity Logs',
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LogsPage()),
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          children: [
            // -------------------- Search --------------------
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by customer / mobile / invoice no',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onChanged: (v) => ref.read(invoiceSearchProvider.notifier).state = v,
            ),
            const SizedBox(height: 10),

            // -------------------- Filters + Sort --------------------
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip(
                          label: 'All',
                          selected: filter == InvoiceFilter.all,
                          onTap: () => ref.read(invoiceFilterProvider.notifier).state = InvoiceFilter.all,
                        ),
                        const SizedBox(width: 8),
                        _chip(
                          label: 'Paid',
                          selected: filter == InvoiceFilter.paid,
                          onTap: () => ref.read(invoiceFilterProvider.notifier).state = InvoiceFilter.paid,
                        ),
                        const SizedBox(width: 8),
                        _chip(
                          label: 'Unpaid',
                          selected: filter == InvoiceFilter.pending,
                          onTap: () => ref.read(invoiceFilterProvider.notifier).state = InvoiceFilter.pending,
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
            const SizedBox(height: 10),

            // -------------------- Date Filter --------------------
            Row(
              children: [
                Expanded(
                  child: _DateFilterButton(
                    value: dateFilter,
                    onChanged: (v) {
                      ref.read(invoiceDateFilterProvider.notifier).state = v;
                      if (v != InvoiceDateFilter.custom) {
                        ref.read(invoiceCustomRangeProvider.notifier).state = null;
                      }
                    },
                    customRange: customRange,
                  ),
                ),
                if (dateFilter == InvoiceDateFilter.custom) ...[
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: const Text('Pick'),
                    onPressed: () async {
                      final now = DateTime.now();
                      final initial = ref.read(invoiceCustomRangeProvider) ??
                          DateTimeRange(
                            start: DateTime(now.year, now.month, 1),
                            end: now,
                          );

                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDateRange: initial,
                      );

                      if (picked != null) {
                        ref.read(invoiceCustomRangeProvider.notifier).state = picked;
                      }
                    },
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // -------------------- Summary chips (AFTER filters) --------------------
            _SummaryGrid(
              totalPaid: totalPaid,
              totalUnpaid: totalUnpaid,
              invoiceCount: invoices.length,
              customerCount: customers.length,
              itemCount: items.length,
            ),

            const SizedBox(height: 14),

            // -------------------- List --------------------
            if (invoices.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                  child: Text(
                    'No invoices found.\nTap + to create invoice',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...invoices.map(
                    (inv) => _InvoiceCard(
                  inv: inv,
                  onTap: () => _openDetail(inv),
                  onEdit: () => _openCreate(editInvoice: inv),
                  onDelete: () async {
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
              ),
          ],
        ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

// -------------------- Summary UI --------------------

class _SummaryGrid extends StatelessWidget {
  final double totalPaid;
  final double totalUnpaid;
  final int invoiceCount;
  final int customerCount;
  final int itemCount;

  const _SummaryGrid({
    required this.totalPaid,
    required this.totalUnpaid,
    required this.invoiceCount,
    required this.customerCount,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    Widget tile({
      required String title,
      required String value,
      required IconData icon,
      Color? valueColor,
    }) {
      return Container(
        height: 74,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.35),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: valueColor,
                    ),
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

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: tile(
                title: 'Total Paid',
                value: '₹${totalPaid.toStringAsFixed(0)}',
                icon: Icons.verified_rounded,
                valueColor: Colors.green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: tile(
                title: 'Total Unpaid',
                value: '₹${totalUnpaid.toStringAsFixed(0)}',
                icon: Icons.pending_actions_rounded,
                valueColor: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: tile(
                title: 'Invoices',
                value: invoiceCount.toString(),
                icon: Icons.receipt_long,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: tile(
                title: 'Customers',
                value: customerCount.toString(),
                icon: Icons.people_alt_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: tile(
                title: 'Items',
                value: itemCount.toString(),
                icon: Icons.inventory_2_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// -------------------- Invoice Card --------------------

class _InvoiceCard extends StatelessWidget {
  final Invoice inv;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _InvoiceCard({
    required this.inv,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = inv.draft.customerName.trim().isEmpty ? 'Customer' : inv.draft.customerName.trim();
    final invNo = inv.invoiceNumber.trim().isEmpty
        ? 'INV-${inv.id.substring(0, 8).toUpperCase()}'
        : inv.invoiceNumber.trim();

    final isPaid = inv.status == PaymentStatus.paid;
    final amount = inv.total.toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.35),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                child: Text(name.characters.first.toUpperCase()),
              ),
              const SizedBox(width: 12),

              // Left content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      invNo,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Right content (no overflow)
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '₹$amount',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      const SizedBox(width: 6),
                      PopupMenuButton<String>(
                        tooltip: 'Options',
                        onSelected: (v) async {
                          if (v == 'edit') onEdit();
                          if (v == 'delete') onDelete();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                        child: const Icon(Icons.more_vert, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: isPaid ? Colors.green.withOpacity(0.16) : Colors.red.withOpacity(0.16),
                    ),
                    child: Text(
                      isPaid ? 'PAID' : 'UNPAID',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: isPaid ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------- Sort button --------------------

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

// -------------------- Date filter button --------------------

class _DateFilterButton extends StatelessWidget {
  final InvoiceDateFilter value;
  final ValueChanged<InvoiceDateFilter> onChanged;
  final DateTimeRange? customRange;

  const _DateFilterButton({
    required this.value,
    required this.onChanged,
    required this.customRange,
  });

  String _label(InvoiceDateFilter v) {
    switch (v) {
      case InvoiceDateFilter.allTime:
        return 'All time';
      case InvoiceDateFilter.thisWeek:
        return 'This week';
      case InvoiceDateFilter.last7Days:
        return 'Last 7 days';
      case InvoiceDateFilter.last30Days:
        return 'Last 30 days';
      case InvoiceDateFilter.thisMonth:
        return 'This month';
      case InvoiceDateFilter.thisYear:
        return 'This year';
      case InvoiceDateFilter.custom:
        if (customRange == null) return 'Custom range';
        return 'Custom: ${customRange!.start.day}/${customRange!.start.month} - ${customRange!.end.day}/${customRange!.end.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<InvoiceDateFilter>(
      tooltip: 'Date filter',
      onSelected: onChanged,
      itemBuilder: (_) => InvoiceDateFilter.values
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
            const Icon(Icons.calendar_month, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _label(value),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down, size: 18),
          ],
        ),
      ),
    );
  }
}
