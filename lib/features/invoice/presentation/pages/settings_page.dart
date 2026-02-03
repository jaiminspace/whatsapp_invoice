import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:whatsapp_invoice/features/invoice/presentation/pages/businesses_page.dart';
import 'package:whatsapp_invoice/features/invoice/presentation/pages/items_page.dart';

import '../../domain/business_profile.dart';
import '../state/business_profile_notifier.dart';

import 'package:whatsapp_invoice/features/invoice/presentation/state/invoice_list_notifier.dart';
import 'package:whatsapp_invoice/features/invoice/presentation/utils/invoice_csv_exporter.dart';
import 'package:whatsapp_invoice/features/invoice/presentation/utils/invoice_csv_importer.dart';

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

  Future<void> _exportInvoicesCsv(BuildContext context) async {
    final invoices = ref.read(invoiceListProvider);

    if (invoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No invoices to export')),
      );
      return;
    }

    final csv = invoicesToCsv(invoices);
    final bytes = Uint8List.fromList(utf8.encode(csv));

    final file = XFile.fromData(
      bytes,
      name: 'invoices_export.csv',
      mimeType: 'text/csv',
    );

    await Share.shareXFiles(
      [file],
      text: 'Invoices export (CSV)',
    );
  }

  Future<void> _importInvoicesCsv(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read selected CSV file')),
      );
      return;
    }

    final text = utf8.decode(bytes);
    final invoices = importInvoicesFromCsvText(text);

    if (invoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No invoices found in CSV')),
      );
      return;
    }

    await ref.read(invoiceListProvider.notifier).importMany(invoices);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported ${invoices.length} invoices')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(businessProfileProvider.notifier);
    final profile = ref.watch(businessProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('Manage Businesses'),
            subtitle: const Text('Add / edit / delete businesses'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BusinessesPage()),
              );
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Manage Items Catalog'),
            subtitle: const Text('Add / edit / delete items'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ItemsPage()),
              );
            },
          ),
          const SizedBox(height: 16),
          // ----------------- INVOICE NUMBERING MODE -----------------
          DropdownButtonFormField<InvoiceNumberMode>(
            initialValue: profile.invoiceNumberMode,
            decoration: const InputDecoration(
              labelText: 'Invoice Numbering',
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
            onChanged: (v) async {
              if (v == null) return;

              // Save only mode change immediately
              await notifier.save(profile.copyWith(invoiceNumberMode: v));

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invoice numbering updated')),
                );
              }
            },
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () async {
              // ✅ Keep current mode when saving profile
              final updated = profile.copyWith(
                name: nameCtrl.text.trim().isEmpty
                    ? 'My Business'
                    : nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                address: addressCtrl.text.trim(),
                upiId: upiCtrl.text.trim(),
              );

              await notifier.save(updated);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 10),

          // ----------------- BACKUP / EXPORT -----------------
          const Text(
            'Backup / Export',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),

          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export Invoices (CSV)'),
            subtitle: const Text('Share as a .csv file (Excel/Sheets)'),
            onTap: () => _exportInvoicesCsv(context),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Import Invoices (CSV)'),
            subtitle: const Text('Imports totals (items not fully restored)'),
            onTap: () => _importInvoicesCsv(context),
          ),

          const SizedBox(height: 8),
          Text(
            'Note: CSV export/import is best for reports. For full restore (all items exactly), we should add JSON backup next.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
