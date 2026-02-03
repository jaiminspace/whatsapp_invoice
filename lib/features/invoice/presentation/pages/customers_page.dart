import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/customer_model.dart';
import '../state/customer_notifier.dart';
import '../state/invoice_list_notifier.dart';

import '../../../../core/ui/app_confirm_dialog.dart';
import '../../../../core/ui/app_snack.dart';

enum CustomerSortMode { az, lastUsed, topAmount }

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  final _searchCtrl = TextEditingController();
  CustomerSortMode _sortMode = CustomerSortMode.az;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _callNumber(BuildContext context, String mobile) async {
    final m = mobile.trim();
    if (m.isEmpty) return;

    final uri = Uri(scheme: 'tel', path: m);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open dialer')),
      );
    }
  }

  Future<void> _openWhatsApp(BuildContext context, String mobile, String name) async {
    final m = mobile.replaceAll(RegExp(r'\s+'), '');
    if (m.isEmpty) return;

    final msg = Uri.encodeComponent('Hi ${name.isEmpty ? 'there' : name},');
    final uri = Uri.parse('https://wa.me/$m?text=$msg');

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
  }

  Future<void> _openAddEditDialog({
    required BuildContext context,
    String? editingId,
    String initialName = '',
    String initialMobile = '',
  }) async {
    final nameCtrl = TextEditingController(text: initialName);
    final mobileCtrl = TextEditingController(text: initialMobile);

    final isEdit = editingId != null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? 'Edit Customer/Client' : 'Add Customer/Client'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: mobileCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isEdit ? 'Update' : 'Add'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final name = nameCtrl.text.trim();
    final mobile = mobileCtrl.text.trim();

    if (mobile.isEmpty) {
      if (context.mounted) AppSnack.show(context, 'Mobile is required');
      return;
    }

    if (isEdit) {
      await ref.read(customerListProvider.notifier).updateCustomer(
        id: editingId!,
        name: name,
        mobile: mobile,
      );
      if (context.mounted) AppSnack.show(context, 'Customer updated');
    } else {
      await ref.read(customerListProvider.notifier).addCustomer(
        name: name,
        mobile: mobile,
      );
      if (context.mounted) AppSnack.show(context, 'Customer added');
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customerListProvider);
    final invoices = ref.watch(invoiceListProvider);

    // --------- compute totals + last used from invoices ----------
    final totalByMobile = <String, double>{};
    final lastUsedByMobile = <String, DateTime>{};

    for (final inv in invoices) {
      final m = inv.draft.customerMobile.trim();
      if (m.isEmpty) continue;

      totalByMobile[m] = (totalByMobile[m] ?? 0.0) + inv.total;

      final existing = lastUsedByMobile[m];
      final t = inv.createdAt;
      if (existing == null || t.isAfter(existing)) {
        lastUsedByMobile[m] = t;
      }
    }

    final query = _searchCtrl.text.trim().toLowerCase();

    List<Customer> filtered = customers.where((c) {
      if (query.isEmpty) return true;
      final name = c.name.toLowerCase();
      final mobile = c.mobile.toLowerCase();
      return name.contains(query) || mobile.contains(query);
    }).toList();

    // --------- sorting ----------
    filtered.sort((a, b) {
      switch (_sortMode) {
        case CustomerSortMode.az:
          return (a.name.isEmpty ? a.mobile : a.name)
              .toLowerCase()
              .compareTo((b.name.isEmpty ? b.mobile : b.name).toLowerCase());

        case CustomerSortMode.lastUsed:
          final la = lastUsedByMobile[a.mobile.trim()] ?? DateTime.fromMillisecondsSinceEpoch(0);
          final lb = lastUsedByMobile[b.mobile.trim()] ?? DateTime.fromMillisecondsSinceEpoch(0);
          return lb.compareTo(la);

        case CustomerSortMode.topAmount:
          final ta = totalByMobile[a.mobile.trim()] ?? 0.0;
          final tb = totalByMobile[b.mobile.trim()] ?? 0.0;
          return tb.compareTo(ta);
      }
    });

    // --------- quick sections ----------
    final lastUsedList = customers.toList()
      ..sort((a, b) {
        final la = lastUsedByMobile[a.mobile.trim()] ?? DateTime.fromMillisecondsSinceEpoch(0);
        final lb = lastUsedByMobile[b.mobile.trim()] ?? DateTime.fromMillisecondsSinceEpoch(0);
        return lb.compareTo(la);
      });
    final lastUsedTop = lastUsedList.take(5).toList();

    final topAmountList = customers.toList()
      ..sort((a, b) {
        final ta = totalByMobile[a.mobile.trim()] ?? 0.0;
        final tb = totalByMobile[b.mobile.trim()] ?? 0.0;
        return tb.compareTo(ta);
      });
    final topAmountTop = topAmountList.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers / Clients'),
        actions: [
          PopupMenuButton<CustomerSortMode>(
            tooltip: 'Sort',
            initialValue: _sortMode,
            onSelected: (v) => setState(() => _sortMode = v),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: CustomerSortMode.az,
                child: Text('Sort: A-Z'),
              ),
              PopupMenuItem(
                value: CustomerSortMode.lastUsed,
                child: Text('Sort: Last used'),
              ),
              PopupMenuItem(
                value: CustomerSortMode.topAmount,
                child: Text('Sort: Top amount'),
              ),
            ],
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddEditDialog(context: context),
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Search
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search name or mobile...',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Quick chips / sections
            // if (customers.isNotEmpty) ...[
            //   Align(
            //     alignment: Alignment.centerLeft,
            //     child: Text(
            //       'Quick Access',
            //       style: Theme.of(context).textTheme.titleMedium,
            //     ),
            //   ),
            //   const SizedBox(height: 8),
            //
            //   // Last used
            //   if (lastUsedTop.isNotEmpty)
            //     Card(
            //       child: Padding(
            //         padding: const EdgeInsets.all(12),
            //         child: Column(
            //           crossAxisAlignment: CrossAxisAlignment.start,
            //           children: [
            //             const Text('Last used customers'),
            //             const SizedBox(height: 8),
            //             Wrap(
            //               spacing: 8,
            //               runSpacing: 8,
            //               children: lastUsedTop.map((c) {
            //                 final n = c.name.isEmpty ? c.mobile : c.name;
            //                 return ActionChip(
            //                   label: Text(n),
            //                   onPressed: () => _openAddEditDialog(
            //                     context: context,
            //                     editingId: c.id,
            //                     initialName: c.name,
            //                     initialMobile: c.mobile,
            //                   ),
            //                 );
            //               }).toList(),
            //             ),
            //           ],
            //         ),
            //       ),
            //     ),
            //
            //   // Top amount
            //   if (topAmountTop.isNotEmpty)
            //     Card(
            //       child: Padding(
            //         padding: const EdgeInsets.all(12),
            //         child: Column(
            //           crossAxisAlignment: CrossAxisAlignment.start,
            //           children: [
            //             const Text('Top customers (amount)'),
            //             const SizedBox(height: 8),
            //             Column(
            //               children: topAmountTop.map((c) {
            //                 final amount = totalByMobile[c.mobile.trim()] ?? 0.0;
            //                 return ListTile(
            //                   dense: true,
            //                   contentPadding: EdgeInsets.zero,
            //                   title: Text(c.name.isEmpty ? c.mobile : c.name),
            //                   subtitle: Text(c.mobile),
            //                   trailing: Text('₹${amount.toStringAsFixed(0)}'),
            //                 );
            //               }).toList(),
            //             ),
            //           ],
            //         ),
            //       ),
            //     ),
            // ],
            //
            // const SizedBox(height: 8),

            // List
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No customers found'))
                  : ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final c = filtered[i];
                  final displayName = c.name.isEmpty ? 'Customer/Client' : c.name;

                  final amount = totalByMobile[c.mobile.trim()] ?? 0.0;

                  return ListTile(
                    title: Text(displayName),
                    subtitle: Text('${c.mobile}  •  Total: ₹${amount.toStringAsFixed(0)}'),
                    onTap: () => _openAddEditDialog(
                      context: context,
                      editingId: c.id,
                      initialName: c.name,
                      initialMobile: c.mobile,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Call',
                          icon: const Icon(Icons.call),
                          onPressed: () => _callNumber(context, c.mobile),
                        ),
                        IconButton(
                          tooltip: 'WhatsApp',
                          icon: const Icon(Icons.chat),
                          onPressed: () => _openWhatsApp(context, c.mobile, c.name),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final ok = await AppConfirmDialog.show(
                              context,
                              title: 'Delete customer?',
                              message: 'This customer will be permanently deleted.',
                              confirmText: 'Delete',
                              isDanger: true,
                            );
                            if (!ok) return;

                            await ref.read(customerListProvider.notifier).deleteCustomer(c.id);
                            if (context.mounted) AppSnack.show(context, 'Customer deleted');
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
