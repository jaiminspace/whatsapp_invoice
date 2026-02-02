import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatsapp_invoice/features/invoice/presentation/state/invoice_list_notifier.dart';
import 'package:whatsapp_invoice/features/invoice/presentation/state/customer_notifier.dart';
import 'package:whatsapp_invoice/features/invoice/presentation/state/invoice_filter_provider.dart';
import 'package:whatsapp_invoice/invoice_draft_notifier.dart';

class CreateInvoicePage extends ConsumerWidget {
  const CreateInvoicePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(invoiceDraftProvider);
    final notifier = ref.read(invoiceDraftProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Invoice'),
        actions: [
          IconButton(
            onPressed: notifier.reset,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset',
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ✅ Customer quick picker (optional UI)
          OutlinedButton.icon(
            icon: const Icon(Icons.person_search),
            label: const Text('Choose Customer'),
            onPressed: () async {
              final selected = await showModalBottomSheet<Map<String, String>>(
                context: context,
                builder: (_) => const _CustomerPickerSheet(),
              );

              if (selected != null) {
                notifier.setCustomerName(selected['name'] ?? '');
                notifier.setCustomerMobile(selected['mobile'] ?? '');
              }
            },
          ),
          const SizedBox(height: 12),

          TextField(
            decoration: const InputDecoration(
              labelText: 'Customer name',
              border: OutlineInputBorder(),
            ),
            controller: TextEditingController(text: draft.customerName)
              ..selection = TextSelection.fromPosition(
                TextPosition(offset: draft.customerName.length),
              ),
            onChanged: notifier.setCustomerName,
          ),
          const SizedBox(height: 12),

          TextField(
            decoration: const InputDecoration(
              labelText: 'Customer mobile',
              border: OutlineInputBorder(),
            ),
            controller: TextEditingController(text: draft.customerMobile)
              ..selection = TextSelection.fromPosition(
                TextPosition(offset: draft.customerMobile.length),
              ),
            keyboardType: TextInputType.phone,
            onChanged: notifier.setCustomerMobile,
          ),

          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Items',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              FilledButton.icon(
                onPressed: notifier.addItem,
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (draft.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No items. Tap "Add item" to start.'),
            ),

          ...List.generate(draft.items.length, (index) {
            final item = draft.items[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Item name',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => notifier.updateItemName(index, v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => notifier.removeItem(index),
                          icon: const Icon(Icons.delete_outline),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Qty',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => notifier.updateItemQty(
                              index,
                              int.tryParse(v) ?? 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Price',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (v) => notifier.updateItemPrice(
                              index,
                              double.tryParse(v) ?? 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Item total'),
                        Text('₹${item.total.toStringAsFixed(2)}'),
                      ],
                    )
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: const Text('Grand Total'),
              trailing: Text(
                '₹${draft.grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              if (draft.items.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Add at least 1 item')),
                );
                return;
              }

              // ✅ Save invoice
              await ref.read(invoiceListProvider.notifier).addFromDraft(draft);

              // ✅ Save/Update customer book
              await ref.read(customerListProvider.notifier).upsertFromInvoice(
                name: draft.customerName,
                mobile: draft.customerMobile,
              );

              // ✅ Reset draft
              ref.read(invoiceDraftProvider.notifier).reset();

              // ✅ Optional UX: reset list filter/search (not required)
              ref.read(invoiceFilterProvider.notifier).state = InvoiceFilter.all;
              ref.read(invoiceSearchProvider.notifier).state = '';

              if (context.mounted) Navigator.pop(context); // ✅ no true
            },
            child: const Text('Save Invoice'),
          )
        ],
      ),
    );
  }
}

class _CustomerPickerSheet extends ConsumerWidget {
  const _CustomerPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customerListProvider);

    return SafeArea(
      child: customers.isEmpty
          ? const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No customers yet'),
      )
          : ListView.separated(
        itemCount: customers.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final c = customers[i];
          return ListTile(
            title: Text(c.name.isEmpty ? 'Customer' : c.name),
            subtitle: Text(c.mobile),
            onTap: () {
              Navigator.pop<Map<String, String>>(context, {
                'name': c.name,
                'mobile': c.mobile,
              });
            },
          );
        },
      ),
    );
  }
}
