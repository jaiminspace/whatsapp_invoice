import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../features/invoice/presentation/pages/businesses_page.dart';
import '../../features/invoice/presentation/pages/customers_page.dart';
import '../../features/invoice/presentation/pages/items_page.dart';

class FirstRunSetupSheet {
  static Future<void> maybeShow(BuildContext context, WidgetRef ref) async {
    // ✅ Uses Hive settings box already opened in main()
    // If you are storing this flag via provider instead, tell me.
    // For now: simplest approach is direct Hive access:
    // NOTE: keep Hive import here to avoid circular deps.
    // ignore: depend_on_referenced_packages
    final settings = Hive.box('settings');
    final done =
        settings.get('didCompleteOnboarding', defaultValue: false) as bool;

    if (done) return;
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _SetupWizard(),
    );

    // mark as done when sheet closes (even if skipped)
    settings.put('didCompleteOnboarding', true);
  }
}

class _SetupWizard extends ConsumerStatefulWidget {
  const _SetupWizard();

  @override
  ConsumerState<_SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends ConsumerState<_SetupWizard> {
  int step = 0;

  void _next() {
    if (step >= 2) {
      Navigator.pop(context);
      return;
    }
    setState(() => step++);
  }

  void _back() {
    if (step == 0) return;
    setState(() => step--);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _StepCard(
        icon: Icons.storefront_outlined,
        title: 'Add Business (Recommended)',
        subtitle:
            'Add your business name, UPI, phone & address.\nThis enables invoice QR payments.',
        primaryText: 'Add Business',
        secondaryText: 'Skip',
        onPrimary: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BusinessesPage()),
          );
          _next(); // move forward after returning
        },
        onSecondary: _next,
      ),
      _StepCard(
        icon: Icons.person_outline,
        title: 'Add Customer / Client (Optional)',
        subtitle:
            'Add frequently used clients for faster invoice creation.\nYou can also add directly while making invoice.',
        primaryText: 'Add Customer/Client',
        secondaryText: 'Skip',
        onPrimary: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CustomersPage()),
          );
          _next();
        },
        onSecondary: _next,
      ),
      _StepCard(
        icon: Icons.inventory_2_outlined,
        title: 'Add Items (Optional)',
        subtitle:
            'Create an item catalog (Product / Service / Course).\nYou can still enter items manually in invoice.',
        primaryText: 'Add Items',
        secondaryText: 'Skip',
        onPrimary: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ItemsPage()),
          );
          _next();
        },
        onSecondary: _next,
      ),
    ];

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  'Quick Setup',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${step + 1}/3',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: (step + 1) / 3),
          ),
          const SizedBox(height: 16),

          // Step content
          pages[step],

          const SizedBox(height: 10),

          // Back button (only if not first)
          Row(
            children: [
              if (step > 0)
                TextButton.icon(
                  onPressed: _back,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String primaryText;
  final String secondaryText;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  const _StepCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primaryText,
    required this.secondaryText,
    required this.onPrimary,
    required this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + title
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),

            const SizedBox(height: 14),

            // Buttons
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPrimary,
                child: Text(primaryText),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onSecondary,
                child: Text(secondaryText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
