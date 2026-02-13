import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/backup_zip_service.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _wipeBeforeImport = false;

  Future<void> _exportBackupZip(BuildContext context) async {
    try {
      final file = await BackupZipService.exportZipBackup();

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/zip')],
        text: 'Snap Invoice Backup',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _importBackupZip(BuildContext context) async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;

      final bytes = res.files.first.bytes;
      if (bytes == null) return;

      final total = await BackupZipService.importZipBackup(
        zipBytes: Uint8List.fromList(bytes),
        wipeBeforeImport: _wipeBeforeImport,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $total records successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ✅ Warning card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.45),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Backup is important.\n'
                        'If you uninstall the app or lose your phone, data can be lost.\n'
                        'Please export backup regularly and store it safely.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: const Text('Export Backup (ZIP)'),
            subtitle: const Text('Includes invoices, customers, businesses, items, logs + images'),
            onTap: () => _exportBackupZip(context),
          ),

          SwitchListTile(
            value: _wipeBeforeImport,
            onChanged: (v) => setState(() => _wipeBeforeImport = v),
            title: const Text('Wipe existing data before import'),
            subtitle: const Text('Recommended if restoring to a fresh phone'),
          ),

          ListTile(
            leading: const Icon(Icons.unarchive_outlined),
            title: const Text('Import Backup (ZIP)'),
            subtitle: const Text('Restore app data from a backup zip'),
            onTap: () => _importBackupZip(context),
          ),
        ],
      ),
    );
  }
}
