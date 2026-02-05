import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/customer_notifier.dart';
import '../../domain/customer_model.dart';
import '../../../../core/ui/app_confirm_dialog.dart';
import '../../../../core/ui/app_snack.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  final _searchCtrl = TextEditingController();

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

  Future<void> _openWhatsApp(
      BuildContext context,
      String mobile,
      String name,
      ) async {
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

  Future<void> _openCustomerSheet({
    Customer? editing,
  }) async {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final mobileCtrl = TextEditingController(text: editing?.mobile ?? '');
    final addressCtrl = TextEditingController(text: editing?.address ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  editing == null ? 'Add Customer' : 'Edit Customer',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: mobileCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Address (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(editing == null ? 'Save' : 'Update'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (saved != true) return;

    final mobile = mobileCtrl.text.trim();
    if (mobile.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mobile is required')),
      );
      return;
    }

    final name = nameCtrl.text.trim();
    final address = addressCtrl.text.trim();

    if (editing == null) {
      await ref.read(customerListProvider.notifier).addCustomer(
        name: name,
        mobile: mobile,
        address: address,
      );
      if (mounted) AppSnack.show(context, 'Customer added');
    } else {
      await ref.read(customerListProvider.notifier).updateCustomer(
        id: editing.id,
        name: name,
        mobile: mobile,
        address: address,
      );
      if (mounted) AppSnack.show(context, 'Customer updated');
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customerListProvider);

    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? customers
        : customers.where((c) {
      final name = c.name.toLowerCase();
      final mobile = c.mobile.toLowerCase();
      final address = c.address.toLowerCase();
      return name.contains(q) || mobile.contains(q) || address.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            tooltip: 'Add customer',
            icon: const Icon(Icons.add),
            onPressed: () => _openCustomerSheet(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCustomerSheet(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search name / mobile / address',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No customers yet'))
                : ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final c = filtered[i];
                final displayName = c.name.isEmpty ? 'Customer' : c.name;

                final subtitle = [
                  c.mobile,
                  if (c.address.trim().isNotEmpty) c.address.trim(),
                ].join(' • ');

                return ListTile(
                  title: Text(displayName),
                  subtitle: Text(subtitle),
                  onTap: () => _openCustomerSheet(editing: c),
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
                        onPressed: () =>
                            _openWhatsApp(context, c.mobile, c.name),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'edit') {
                            await _openCustomerSheet(editing: c);
                          } else if (v == 'delete') {
                            final ok = await AppConfirmDialog.show(
                              context,
                              title: 'Delete customer?',
                              message:
                              'This customer will be permanently deleted.',
                              confirmText: 'Delete',
                              isDanger: true,
                            );
                            if (!ok) return;

                            await ref
                                .read(customerListProvider.notifier)
                                .deleteCustomer(c.id);
                            if (context.mounted) {
                              AppSnack.show(context, 'Customer deleted');
                            }
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
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
