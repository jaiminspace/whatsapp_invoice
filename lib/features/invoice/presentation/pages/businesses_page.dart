import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/business_list_notifier.dart';
import '../../domain/business_models.dart';
import '../../../../core/ui/app_confirm_dialog.dart';

class BusinessesPage extends ConsumerWidget {
  const BusinessesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businesses = ref.watch(businessListProvider);
    final selectedId = ref.watch(selectedBusinessIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Businesses'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddOrEdit(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Business'),
      ),
      body: businesses.isEmpty
          ? const Center(child: Text('No businesses yet.\nTap + to add one.'))
          : ListView.separated(
        itemCount: businesses.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final b = businesses[i];
          final isSelected = (selectedId.isEmpty && i == 0) || selectedId == b.id;

          return ListTile(
            title: Text(b.name.isEmpty ? 'Business' : b.name),
            subtitle: Text(
              [
                if (b.phone.trim().isNotEmpty) b.phone.trim(),
                if (b.upiId.trim().isNotEmpty) 'UPI: ${b.upiId.trim()}',
              ].join(' • '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            leading: CircleAvatar(
              child: Text((b.name.isEmpty ? 'B' : b.name[0]).toUpperCase()),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.green.shade100,
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Edit',
                  onPressed: () => _openAddOrEdit(context, ref, business: b),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: () async {
                    final ok = await AppConfirmDialog.show(
                      context,
                      title: 'Delete business?',
                      message: 'This will remove "${b.name}".',
                      confirmText: 'Delete',
                    );
                    if (!ok) return;
                    await ref.read(businessListProvider.notifier).deleteBusiness(b.id);
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            onTap: () {
              ref.read(selectedBusinessIdProvider.notifier).state = b.id;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Selected: ${b.name}')),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openAddOrEdit(
      BuildContext context,
      WidgetRef ref, {
        Business? business,
      }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BusinessFormSheet(business: business),
    );
  }
}

class _BusinessFormSheet extends ConsumerStatefulWidget {
  final Business? business;
  const _BusinessFormSheet({this.business});

  @override
  ConsumerState<_BusinessFormSheet> createState() => _BusinessFormSheetState();
}

class _BusinessFormSheetState extends ConsumerState<_BusinessFormSheet> {
  late final TextEditingController nameCtrl;
  late final TextEditingController phoneCtrl;
  late final TextEditingController addressCtrl;
  late final TextEditingController upiCtrl;

  @override
  void initState() {
    super.initState();
    final b = widget.business;
    nameCtrl = TextEditingController(text: b?.name ?? '');
    phoneCtrl = TextEditingController(text: b?.phone ?? '');
    addressCtrl = TextEditingController(text: b?.address ?? '');
    upiCtrl = TextEditingController(text: b?.upiId ?? '');
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    addressCtrl.dispose();
    upiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.business != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isEdit ? 'Edit Business' : 'Add Business',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Business name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: addressCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Address',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: upiCtrl,
            decoration: const InputDecoration(
              labelText: 'UPI ID',
              hintText: 'example@upi',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Business name required')),
                );
                return;
              }

              if (isEdit) {
                final updated = widget.business!.copyWith(
                  name: name,
                  phone: phoneCtrl.text.trim(),
                  address: addressCtrl.text.trim(),
                  upiId: upiCtrl.text.trim(),
                );
                await ref.read(businessListProvider.notifier).updateBusiness(updated);
              } else {
                await ref.read(businessListProvider.notifier).addBusiness(
                  name: name,
                  phone: phoneCtrl.text.trim(),
                  address: addressCtrl.text.trim(),
                  upiId: upiCtrl.text.trim(),
                );
              }

              if (mounted) Navigator.pop(context);
            },
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
