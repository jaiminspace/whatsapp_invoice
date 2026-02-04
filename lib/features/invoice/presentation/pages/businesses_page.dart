import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/business_entity.dart';
import '../state/business_list_notifier.dart';

class BusinessesPage extends ConsumerWidget {
  const BusinessesPage({super.key});

  Future<void> _openBusinessSheet(
      BuildContext context,
      WidgetRef ref, {
        BusinessEntity? editing,
      }) async {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final upiCtrl = TextEditingController(text: editing?.upiId ?? '');
    final phoneCtrl = TextEditingController(text: editing?.phone ?? '');
    final addressCtrl = TextEditingController(text: editing?.address ?? '');

    InvoiceNumberMode mode = editing?.invoiceNumberMode ?? InvoiceNumberMode.auto;

    final result = await showModalBottomSheet<bool>(
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
                  editing == null ? 'Add Business' : 'Edit Business',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Business name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: upiCtrl,
                  decoration: const InputDecoration(
                    labelText: 'UPI ID (optional)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. jaimin@upi',
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Address (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<InvoiceNumberMode>(
                  value: mode,
                  isExpanded: true, // ✅ fixes overflow
                  decoration: const InputDecoration(
                    labelText: 'Invoice numbering',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: InvoiceNumberMode.auto,
                      child: Text(
                        'Auto (INV-0001)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: InvoiceNumberMode.manual,
                      child: Text(
                        'Manual',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (v) => mode = v ?? InvoiceNumberMode.auto,
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

    if (result != true) return;

    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business name is required')),
      );
      return;
    }

    if (editing == null) {
      final newBusiness = BusinessEntity.create(name).copyWith(
        upiId: upiCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        address: addressCtrl.text.trim(),
        invoiceNumberMode: mode,
      );

      await ref.read(businessListProvider.notifier).add(newBusiness);
    } else {
      final updated = editing.copyWith(
        name: name,
        upiId: upiCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        address: addressCtrl.text.trim(),
        invoiceNumberMode: mode,
      );

      await ref.read(businessListProvider.notifier).update(updated);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context,
      WidgetRef ref,
      BusinessEntity b,
      ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete business?'),
        content: Text(
          '“${b.name.isEmpty ? 'Business' : b.name}” will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await ref.read(businessListProvider.notifier).delete(b.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businesses = ref.watch(businessListProvider);
    final selectedId = ref.watch(selectedBusinessIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Businesses'),
        actions: [
          IconButton(
            tooltip: 'Add business',
            icon: const Icon(Icons.add),
            onPressed: () => _openBusinessSheet(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openBusinessSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: businesses.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront_outlined, size: 44),
              const SizedBox(height: 10),
              const Text(
                'No businesses yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add your business to start creating invoices.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _openBusinessSheet(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add Business'),
              ),
            ],
          ),
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
        itemCount: businesses.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final b = businesses[i];
          final isSelected = (selectedId.trim().isNotEmpty && selectedId == b.id) ||
              (selectedId.trim().isEmpty && i == 0);

          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withOpacity(0.35),
              ),
            ),
            child: ListTile(
              onTap: () {
                ref.read(selectedBusinessIdProvider.notifier).state = b.id;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Selected: ${b.name.isEmpty ? 'Business' : b.name}',
                    ),
                  ),
                );
              },
              leading: CircleAvatar(
                child: Text(
                  (b.name.trim().isEmpty ? 'B' : b.name.trim()[0])
                      .toUpperCase(),
                ),
              ),
              title: Text(
                b.name.trim().isEmpty ? 'Business' : b.name.trim(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('Invoice: ${b.invoiceNumberMode.name.toUpperCase()}'),
                  if (b.upiId.trim().isNotEmpty) Text('UPI: ${b.upiId}'),
                  if (b.phone.trim().isNotEmpty) Text('Phone: ${b.phone}'),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.check_circle, size: 20),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'edit') {
                        await _openBusinessSheet(
                          context,
                          ref,
                          editing: b,
                        );
                      } else if (v == 'delete') {
                        await _confirmDelete(context, ref, b);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
