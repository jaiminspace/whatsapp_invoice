import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/app_confirm_dialog.dart';
import '../../../../core/ui/create_invoice_gate.dart';
import '../../../../core/ui/first_run_setup_sheet.dart';

import '../../domain/invoice_models.dart';
import '../state/invoice_filter_provider.dart';
import '../state/invoice_list_notifier.dart';
import '../state/invoice_draft_notifier.dart';

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
    final ok = await CreateInvoiceGate.ensureReady(context, ref);
    if (!ok) return;

    // ✅ If editing: load draft from invoice before opening page
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
      // ✅ New invoice
      ref.read(invoiceDraftProvider.notifier).reset();

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

    final invoices = ref.watch(filteredInvoicesProvider);
    final filter = ref.watch(invoiceFilterProvider);
    final sort = ref.watch(invoiceSortProvider);

    final grouped = _groupByMonth(invoices);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Diary'),
        actions: [
          IconButton(
            tooltip: 'Businesses',
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BusinessesPage()),
            ),
          ),
          IconButton(
            tooltip: 'Items',
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ItemsPage()),
            ),
          ),
          IconButton(
            tooltip: 'Customers',
            icon: const Icon(Icons.people_alt_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomersPage()),
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreate(),
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

          // Filters + Sort
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip('All', filter == InvoiceFilter.all,
                                () => ref.read(invoiceFilterProvider.notifier).state =
                                InvoiceFilter.all),
                        _chip('Paid', filter == InvoiceFilter.paid,
                                () => ref.read(invoiceFilterProvider.notifier).state =
                                InvoiceFilter.paid),
                        _chip('Unpaid', filter == InvoiceFilter.pending,
                                () => ref.read(invoiceFilterProvider.notifier).state =
                                InvoiceFilter.pending),
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
                  onTap: _openDetail,
                  onEdit: (inv) => _openCreate(editInvoice: inv),
                  onDelete: (inv) async {
                    final ok = await AppConfirmDialog.show(
                      context,
                      title: 'Delete invoice?',
                      message:
                      'This invoice will be permanently deleted.',
                      confirmText: 'Delete',
                      isDanger: true,
                    );
                    if (!ok) return;

                    await ref
                        .read(invoiceListProvider.notifier)
                        .deleteInvoice(inv.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

// ---------------- MONTH GROUPING ----------------

class _MonthSectionData {
  final String title;
  final List<Invoice> items;

  const _MonthSectionData({required this.title, required this.items});
}

List<_MonthSectionData> _groupByMonth(List<Invoice> invoices) {
  final map = <String, List<Invoice>>{};

  for (final inv in invoices) {
    final key = '${inv.createdAt.year}-${inv.createdAt.month}';
    (map[key] ??= []).add(inv);
  }

  final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));

  return keys.map((k) {
    final parts = k.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final title = '${_monthName(m)} $y';
    return _MonthSectionData(title: title, items: map[k]!);
  }).toList();
}

String _monthName(int m) =>
    const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];

// ---------------- UI ----------------

class _MonthSection extends StatelessWidget {
  final String title;
  final List<Invoice> invoices;
  final void Function(Invoice) onTap;
  final void Function(Invoice) onEdit;
  final void Function(Invoice) onDelete;

  const _MonthSection({
    required this.title,
    required this.invoices,
    required this.onTap,
    required this.onEdit,
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
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        ...invoices.map(
              (inv) => _InvoiceTile(
            inv: inv,
            onTap: () => onTap(inv),
            onEdit: () => onEdit(inv),
            onDelete: () => onDelete(inv),
          ),
        ),
      ],
    );
  }
}

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
    final name =
    inv.draft.customerName.trim().isEmpty ? 'Customer' : inv.draft.customerName.trim();
    final isPaid = inv.status == PaymentStatus.paid;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Text(name[0].toUpperCase())),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(inv.invoiceNumber.isEmpty
            ? 'INV-${inv.id.substring(0, 8).toUpperCase()}'
            : inv.invoiceNumber),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}

// ---------------- SORT BUTTON (UNCHANGED) ----------------

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
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withOpacity(0.45),
          ),
        ),
        child: Row(
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
