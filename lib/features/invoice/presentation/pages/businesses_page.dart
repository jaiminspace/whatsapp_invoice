import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/business_entity.dart';
import '../state/business_list_notifier.dart';

class BusinessesPage extends ConsumerWidget {
  const BusinessesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businesses = ref.watch(businessListProvider);

    Future<void> openAddDialog() async {
      final nameCtrl = TextEditingController();
      final upiCtrl = TextEditingController();
      final phoneCtrl = TextEditingController();
      final addressCtrl = TextEditingController();

      InvoiceNumberMode mode = InvoiceNumberMode.auto;

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Add Business'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Business name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<InvoiceNumberMode>(
                  value: mode,
                  decoration: const InputDecoration(
                    labelText: 'Invoice numbering',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: InvoiceNumberMode.auto,
                      child: Text('Auto (INV-0001)'),
                    ),
                    DropdownMenuItem(
                      value: InvoiceNumberMode.manual,
                      child: Text('Manual (I will enter)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    mode = v;
                  },
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: upiCtrl,
                  decoration: const InputDecoration(
                    labelText: 'UPI ID (optional)',
                    hintText: 'example@upi',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      );

      if (ok != true) return;

      final name = nameCtrl.text.trim();
      if (name.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Business name is required')),
          );
        }
        return;
      }

      final newBusiness = BusinessEntity.create(name).copyWith(
        invoiceNumberMode: mode,
        upiId: upiCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        address: addressCtrl.text.trim(),
      );

      await ref.read(businessListProvider.notifier).add(newBusiness);

      // Clean up controllers
      nameCtrl.dispose();
      upiCtrl.dispose();
      phoneCtrl.dispose();
      addressCtrl.dispose();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Businesses')),
      floatingActionButton: FloatingActionButton(
        onPressed: openAddDialog,
        child: const Icon(Icons.add),
      ),
      body: businesses.isEmpty
          ? const Center(
        child: Text('No businesses yet.\nTap + to add one.'),
      )
          : ListView.separated(
        itemCount: businesses.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final b = businesses[i];
          return ListTile(
            title: Text(b.name.isEmpty ? 'Business' : b.name),
            subtitle: Text(
              [
                'Invoice: ${b.invoiceNumberMode.name}',
                if (b.upiId.trim().isNotEmpty) 'UPI: ${b.upiId}',
                if (b.phone.trim().isNotEmpty) 'Phone: ${b.phone}',
              ].join(' • '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),
    );
  }
}
