import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/invoice/domain/item_catalog_models.dart';
import '../../features/invoice/presentation/pages/businesses_page.dart';
import '../../features/invoice/presentation/pages/customers_page.dart';
import '../../features/invoice/presentation/pages/items_page.dart';
import '../../features/invoice/presentation/state/business_list_notifier.dart';
import '../../features/invoice/presentation/state/catalog_notifier.dart';
import '../../features/invoice/presentation/state/customer_notifier.dart';


class CreateInvoiceGate {
  /// Call this instead of directly opening CreateInvoicePage.
  static Future<bool> ensureReady(BuildContext context, WidgetRef ref) async {
    // Always require at least 1 business
    final businesses = ref.read(businessListProvider);
    if (businesses.isNotEmpty) return true;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateInvoiceGateSheet(),
    );

    return ok == true;
  }
}

class _CreateInvoiceGateSheet extends ConsumerWidget {
  const _CreateInvoiceGateSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businesses = ref.watch(businessListProvider);
    final customers = ref.watch(customerListProvider);

    final hasBusiness = businesses.isNotEmpty;
    final hasCustomers = customers.isNotEmpty;

    // ✅ pick a safe businessId for catalog watch
    final selectedBusiness = ref.watch(selectedBusinessProvider);
    final bizId = selectedBusiness?.id ??
        (businesses.isNotEmpty ? businesses.first.id : '');

    // ✅ IMPORTANT: catalog is per business
    final items =
    bizId.isEmpty ? const <CatalogItem>[] : ref.watch(catalogProvider);

    final hasItems = items.isNotEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.lock_outline),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Before creating an invoice',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                _StepTile(
                  index: 1,
                  title: 'Add Business (Required)',
                  subtitle: hasBusiness
                      ? 'Done: ${businesses.first.name.isEmpty ? 'Business' : businesses.first.name}'
                      : 'Add at least one business to continue',
                  done: hasBusiness,
                  buttonText: hasBusiness ? 'Manage' : 'Add Business',
                  icon: Icons.storefront_outlined,
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BusinessesPage()),
                    );
                  },
                ),

                const SizedBox(height: 10),

                _StepTile(
                  index: 2,
                  title: 'Add Customer (Optional)',
                  subtitle: hasCustomers
                      ? 'You have ${customers.length} customers'
                      : 'Optional, you can add later',
                  done: hasCustomers,
                  buttonText: hasCustomers ? 'Manage' : 'Add Customer',
                  icon: Icons.people_alt_outlined,
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CustomersPage()),
                    );
                  },
                ),

                const SizedBox(height: 10),

                _StepTile(
                  index: 3,
                  title: 'Add Items Catalog (Optional)',
                  subtitle: hasItems
                      ? 'You have ${items.length} items (for selected business)'
                      : 'Optional, you can add later',
                  done: hasItems,
                  buttonText: hasItems ? 'Manage' : 'Add Items',
                  icon: Icons.inventory_2_outlined,
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ItemsPage()),
                    );
                  },
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: hasBusiness
                            ? () => Navigator.pop(context, true)
                            : null,
                        child: const Text('Continue'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final int index;
  final String title;
  final String subtitle;
  final bool done;
  final String buttonText;
  final IconData icon;
  final VoidCallback onPressed;

  const _StepTile({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.buttonText,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            child: done
                ? const Icon(Icons.check, size: 18)
                : Text(index.toString()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onPressed,
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
}
