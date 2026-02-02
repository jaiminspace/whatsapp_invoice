import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:whatsapp_invoice/features/invoice/presentation/state/customer_notifier.dart';

import '../../../../core/ui/app_confirm_dialog.dart';
import '../../../../core/ui/app_snack.dart';

class CustomersPage extends ConsumerWidget {
  const CustomersPage({super.key});

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
    // WhatsApp universal web link (works on Android + iOS + Web)
    final uri = Uri.parse('https://wa.me/$m?text=$msg');

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customerListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: customers.isEmpty
          ? const Center(child: Text('No customers yet'))
          : ListView.separated(
        itemCount: customers.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final c = customers[i];
          final displayName = c.name.isEmpty ? 'Customer' : c.name;

          return ListTile(
            title: Text(displayName),
            subtitle: Text(c.mobile),
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
                  },)
                  ],
            ),
          );
        },
      ),
    );
  }
}
