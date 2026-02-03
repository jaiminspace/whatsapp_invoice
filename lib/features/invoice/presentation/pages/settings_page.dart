import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'businesses_page.dart';
import 'items_page.dart';

import '../state/business_profile_notifier.dart';
import '../state/invoice_list_notifier.dart';
import '../utils/invoice_csv_exporter.dart';
import '../utils/invoice_csv_importer.dart';
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

  Future<void> _exportCsv(BuildContext context) async {
    final invoices = ref.read(invoiceListProvider);
    if (invoices.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No invoices to export')));
      return;
    }

    final csv = invoicesToCsv(invoices);
    final bytes = Uint8List.fromList(utf8.encode(csv));

    await Share.shareXFiles([
      XFile.fromData(bytes,
          name: 'invoices_export.csv', mimeType: 'text/csv')
    ]);
  }

  Future<void> _importCsv(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result == null || result.files.first.bytes == null) return;

    final invoices =
    importInvoicesFromCsvText(utf8.decode(result.files.first.bytes!));

    await ref.read(invoiceListProvider.notifier).importMany(invoices);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported ${invoices.length} invoices')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(businessProfileProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.storefront),
            title: const Text('Manage Businesses'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BusinessesPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2),
            title: const Text('Manage Items Catalog'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ItemsPage()),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export CSV'),
            onTap: () => _exportCsv(context),
          ),
          ListTile(
            leading: const Icon(Icons.upload),
            title: const Text('Import CSV'),
            onTap: () => _importCsv(context),
          ),
        ],
      ),
    );
  }
}
