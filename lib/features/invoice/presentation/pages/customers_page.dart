import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:whatsapp_invoice/features/invoice/presentation/state/customer_notifier.dart';
import 'package:whatsapp_invoice/features/invoice/presentation/state/customer_sales_provider.dart';

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
    final m = mobile.replaceAll(RegExp(r'\s+'), '').trim();
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
    final m = mobile.replaceAll('+', '').replaceAll(RegExp(r'\s+'), '').trim();
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

  @override
  Widget build(BuildContext context) {
    final allCustomers = ref.watch(customerListProvider);
    final totalSalesMap = ref.watch(customerTotalSalesProvider);

    final q = _searchCtrl.text.trim().toLowerCase();
    final customers = q.isEmpty
        ? allCustomers
        : allCustomers.where((c) {
      final name = c.name.toLowerCase();
      final mobile = c.mobile.toLowerCase();
      final addr = (c.address ?? '').toLowerCase();
      return name.contains(q) || mobile.contains(q) || addr.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search customer / mobile / address',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          Expanded(
            child: customers.isEmpty
                ? const Center(child: Text('No customers yet'))
                : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              itemCount: customers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final c = customers[i];
                final name = c.name.trim().isEmpty ? 'Customer' : c.name.trim();
                final sale = (totalSalesMap[c.id] ?? 0.0);

                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withOpacity(0.35),
                    ),
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          child: Text(name[0].toUpperCase()),
                        ),
                        const SizedBox(width: 12),

                        // Name + mobile + address
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                c.mobile.trim().isEmpty ? 'No mobile' : c.mobile.trim(),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if ((c.address ?? '').trim().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  (c.address ?? '').trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(width: 10),

                        // Total Sale + actions
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${sale.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Total Sale',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Row(
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
                          ],
                        ),
                      ],
                    ),
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
