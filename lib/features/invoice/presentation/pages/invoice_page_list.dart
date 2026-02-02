import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:whatsapp_invoice/features/invoice/domain/invoice_models.dart';
import 'package:whatsapp_invoice/features/invoice/presentation/pages/create_invoice_page.dart';
import 'package:whatsapp_invoice/features/invoice/presentation/pages/invoice_detail_page.dart';
import 'package:whatsapp_invoice/features/invoice/presentation/pages/settings_page.dart';
import 'package:whatsapp_invoice/features/invoice/presentation/state/invoice_filter_provider.dart';
import 'package:whatsapp_invoice/features/invoice/presentation/state/invoice_list_notifier.dart';

import '../utils/invoice_csv_exporter.dart';
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

    // ✅ Optional UX: after coming back, reset filter/search so user sees All
    _searchCtrl.clear();
    ref.read(invoiceSearchProvider.notifier).state = '';
    ref.read(invoiceFilterProvider.notifier).state = InvoiceFilter.all;

    // ✅ No reload/invalidate needed because invoiceListProvider watches Hive changes
  }

  Future<void> _openDetail(Invoice inv) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InvoiceDetailPage(invoice: inv)),
    );

    // ✅ No reload/invalidate needed because invoiceListProvider watches Hive changes
  }

  @override
  Widget build(BuildContext context) {
    final invoices = ref.watch(filteredInvoicesProvider);
    final filter = ref.watch(invoiceFilterProvider);
    final searchText = ref.watch(invoiceSearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.people_alt_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomersPage()),
              );
            },
          ),
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.download),
            onPressed: () async {
              final allInvoices = ref.read(invoiceListProvider); // export ALL (not filtered)
              if (allInvoices.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No invoices to export')),
                );
                return;
              }

              final csv = invoicesToCsv(allInvoices);
              await Share.share(
                csv,
                subject: 'Invoices Export (CSV)',
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search by customer name / mobile',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) =>
              ref.read(invoiceSearchProvider.notifier).state = v,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: filter == InvoiceFilter.all,
                  onSelected: (_) => ref
                      .read(invoiceFilterProvider.notifier)
                      .state = InvoiceFilter.all,
                ),
                ChoiceChip(
                  label: const Text('Pending'),
                  selected: filter == InvoiceFilter.pending,
                  onSelected: (_) => ref
                      .read(invoiceFilterProvider.notifier)
                      .state = InvoiceFilter.pending,
                ),
                ChoiceChip(
                  label: const Text('Paid'),
                  selected: filter == InvoiceFilter.paid,
                  onSelected: (_) => ref
                      .read(invoiceFilterProvider.notifier)
                      .state = InvoiceFilter.paid,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: invoices.isEmpty
                ? Center(
              child: Text(
                searchText.trim().isNotEmpty
                    ? 'No matching invoices'
                    : 'No invoices yet.\nTap + to create invoice',
                textAlign: TextAlign.center,
              ),
            )
                : ListView.separated(
              itemCount: invoices.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final inv = invoices[index];
                return ListTile(
                  onTap: () => _openDetail(inv),
                  title: Text(inv.draft.customerName.isEmpty
                      ? 'Customer'
                      : inv.draft.customerName),
                  subtitle: Text(
                    '${inv.draft.items.length} items • ${inv.draft.customerMobile}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '₹${inv.total.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: inv.status == PaymentStatus.paid
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              inv.status == PaymentStatus.paid
                                  ? 'PAID'
                                  : 'PENDING',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: inv.status == PaymentStatus.paid
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => ref
                            .read(invoiceListProvider.notifier)
                            .deleteInvoice(inv.id),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
