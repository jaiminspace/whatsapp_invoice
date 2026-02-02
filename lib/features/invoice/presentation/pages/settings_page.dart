import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/business_profile_notifier.dart';
import '../../domain/business_profile.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late TextEditingController nameCtrl;
  late TextEditingController phoneCtrl;
  late TextEditingController addressCtrl;
  late TextEditingController upiCtrl;

  @override
  void initState() {
    super.initState();
    final p = ref.read(businessProfileProvider);
    nameCtrl = TextEditingController(text: p.name);
    phoneCtrl = TextEditingController(text: p.phone);
    addressCtrl = TextEditingController(text: p.address);
    upiCtrl = TextEditingController(text: p.upiId);
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
    final notifier = ref.read(businessProfileProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Business name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phoneCtrl,
            decoration: const InputDecoration(
              labelText: 'Business phone',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: addressCtrl,
            decoration: const InputDecoration(
              labelText: 'Business address',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: upiCtrl,
            decoration: const InputDecoration(
              labelText: 'UPI ID (for payments)',
              border: OutlineInputBorder(),
              hintText: 'example@upi',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              final profile = BusinessProfile(
                name: nameCtrl.text.trim().isEmpty ? 'My Business' : nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                address: addressCtrl.text.trim(),
                upiId: upiCtrl.text.trim(),
              );
              await notifier.save(profile);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
