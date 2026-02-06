import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/ui/app_phone_field.dart';
import '../../domain/business_entity.dart';
import '../state/business_list_notifier.dart';

class BusinessesPage extends ConsumerWidget {
  const BusinessesPage({super.key});

  Future<void> _openBusinessSheet(
      BuildContext context,
      WidgetRef ref, {
        BusinessEntity? editing,
      }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BusinessFormSheet(editing: editing),
    );
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
      // Prefer deleteBusiness if exists, fallback to delete
      final notifier = ref.read(businessListProvider.notifier);
      if (notifier is dynamic) {
        try {
          await (notifier as dynamic).deleteBusiness(b.id);
        } catch (_) {
          await (notifier as dynamic).delete(b.id);
        }
      }
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

          final isSelected = (selectedId != null &&
              selectedId.trim().isNotEmpty &&
              selectedId == b.id) ||
              ((selectedId == null || selectedId.trim().isEmpty) && i == 0);

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
              leading: _BizAvatar(name: b.name, imagePath: b.imagePath),
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
                        await _openBusinessSheet(context, ref, editing: b);
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

class _BizAvatar extends StatelessWidget {
  final String name;
  final String? imagePath;

  const _BizAvatar({required this.name, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final hasImage = (imagePath ?? '').trim().isNotEmpty && File(imagePath!).existsSync();
    if (hasImage) {
      return CircleAvatar(backgroundImage: FileImage(File(imagePath!)));
    }

    final t = name.trim();
    final letter = t.isEmpty ? 'B' : t[0].toUpperCase();
    return CircleAvatar(child: Text(letter));
  }
}

/// ✅ separate sheet with validation gating (name + phone valid)
class _BusinessFormSheet extends ConsumerStatefulWidget {
  final BusinessEntity? editing;
  const _BusinessFormSheet({this.editing});

  @override
  ConsumerState<_BusinessFormSheet> createState() => _BusinessFormSheetState();
}

class _BusinessFormSheetState extends ConsumerState<_BusinessFormSheet> {
  late final TextEditingController nameCtrl;
  late final TextEditingController upiCtrl;
  late final TextEditingController addressCtrl;

  late InvoiceNumberMode mode;

  String _phoneE164 = '';
  bool _phoneValid = false;

  String? _imagePath;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;

    nameCtrl = TextEditingController(text: e?.name ?? '');
    upiCtrl = TextEditingController(text: e?.upiId ?? '');
    addressCtrl = TextEditingController(text: e?.address ?? '');

    mode = e?.invoiceNumberMode ?? InvoiceNumberMode.auto;

    _phoneE164 = e?.phone ?? '';
    _phoneValid = false; // require re-validate in field
    _imagePath = e?.imagePath;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    upiCtrl.dispose();
    addressCtrl.dispose();
    super.dispose();
  }

  bool get _canSave {
    final nameOk = nameCtrl.text.trim().isNotEmpty;
    return nameOk && _phoneValid;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (file == null) return;
    setState(() => _imagePath = file.path);
  }

  Future<void> _save() async {
    if (_saving) return;

    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business name is required')),
      );
      return;
    }

    if (!_phoneValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid business phone number')),
      );
      return;
    }

    setState(() => _saving = true);

    if (widget.editing == null) {
      final newBusiness = BusinessEntity.create(name).copyWith(
        upiId: upiCtrl.text.trim(),
        phone: _phoneE164,
        address: addressCtrl.text.trim(),
        invoiceNumberMode: mode,
        imagePath: (_imagePath ?? '').trim().isEmpty ? null : _imagePath!.trim(),
      );

      final notifier = ref.read(businessListProvider.notifier);
      // Prefer addBusiness, fallback add
      try {
        await (notifier as dynamic).addBusiness(newBusiness);
      } catch (_) {
        await (notifier as dynamic).add(newBusiness);
      }
    } else {
      final updated = widget.editing!.copyWith(
        name: name,
        upiId: upiCtrl.text.trim(),
        phone: _phoneE164,
        address: addressCtrl.text.trim(),
        invoiceNumberMode: mode,
        imagePath: (_imagePath ?? '').trim().isEmpty ? null : _imagePath!.trim(),
      );

      final notifier = ref.read(businessListProvider.notifier);
      // update alias exists in your notifier already
      await (notifier as dynamic).update(updated);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editing != null;

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
              isEdit ? 'Edit Business' : 'Add Business',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                _BizImagePicker(
                  imagePath: _imagePath,
                  name: nameCtrl.text.trim().isEmpty ? 'B' : nameCtrl.text.trim(),
                  onTap: _pickImage,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Business name *',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
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

            AppPhoneField(
              initialText: _phoneE164,
              label: 'Business phone *',
              onChangedE164: (v) => _phoneE164 = v,
              onValidChanged: (ok) => setState(() => _phoneValid = ok),
            ),

            if (!_phoneValid) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Enter a valid phone number',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

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
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Invoice numbering',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: InvoiceNumberMode.auto,
                  child: Text('Auto (INV-0001)', overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: InvoiceNumberMode.manual,
                  child: Text('Manual', overflow: TextOverflow.ellipsis),
                ),
              ],
              onChanged: _saving ? null : (v) => setState(() => mode = v ?? mode),
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: (_saving || !_canSave) ? null : _save,
                    child: Text(_saving ? 'Saving...' : (isEdit ? 'Update' : 'Save')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BizImagePicker extends StatelessWidget {
  final String? imagePath;
  final String name;
  final VoidCallback onTap;

  const _BizImagePicker({
    required this.imagePath,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = (imagePath ?? '').trim().isNotEmpty && File(imagePath!).existsSync();

    return InkWell(
      borderRadius: BorderRadius.circular(44),
      onTap: onTap,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: hasImage ? FileImage(File(imagePath!)) : null,
            child: hasImage
                ? null
                : Text(
              name.trim().isEmpty ? 'B' : name.trim()[0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: CircleAvatar(
              radius: 11,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
