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

  Future<void> _openAddOrEdit({
    Customer? customer,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CustomerFormSheet(customer: customer),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customerListProvider);

    final q = _searchCtrl.text.trim().toLowerCase();

    final filtered = customers.where((c) {
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) || c.mobile.contains(q);
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name / mobile',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('Add Customer'),
      ),
      body: filtered.isEmpty
          ? const Center(child: Text('No customers yet'))
          : ListView.separated(
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final c = filtered[i];
          final displayName = c.name.trim().isEmpty ? 'Customer' : c.name;

          return ListTile(
            title: Text(displayName),
            subtitle: Text(
              [
                c.mobile,
                if (c.address.trim().isNotEmpty) c.address.trim(),
              ].join(' • '),
            ),
            trailing: Wrap(
              spacing: 6,
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
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _openAddOrEdit(customer: c),
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

                    await ref
                        .read(customerListProvider.notifier)
                        .deleteCustomer(c.id);

                    if (context.mounted) {
                      AppSnack.show(context, 'Customer deleted');
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CustomerFormSheet extends ConsumerStatefulWidget {
  final Customer? customer;

  const _CustomerFormSheet({this.customer});

  @override
  ConsumerState<_CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends ConsumerState<_CustomerFormSheet> {
  late final TextEditingController nameCtrl;
  late final TextEditingController mobileCtrl;
  late final TextEditingController addressCtrl;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    nameCtrl = TextEditingController(text: c?.name ?? '');
    mobileCtrl = TextEditingController(text: c?.mobile ?? '');
    addressCtrl = TextEditingController(text: c?.address ?? '');
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    mobileCtrl.dispose();
    addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.customer != null;

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
              isEdit ? 'Edit Customer' : 'Add Customer',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

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
                labelText: 'Mobile (unique)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: addressCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Address (optional)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final mobile = mobileCtrl.text.trim();
                  final address = addressCtrl.text.trim();

                  if (mobile.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mobile number required')),
                    );
                    return;
                  }

                  if (isEdit) {
                    await ref.read(customerListProvider.notifier).updateCustomer(
                      id: widget.customer!.id,
                      name: name,
                      mobile: mobile,
                      address: address,
                    );
                  } else {
                    await ref.read(customerListProvider.notifier).addCustomer(
                      name: name,
                      mobile: mobile,
                      address: address,
                    );
                  }

                  if (mounted) Navigator.pop(context);
                },
                child: Text(isEdit ? 'Save' : 'Add'),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
