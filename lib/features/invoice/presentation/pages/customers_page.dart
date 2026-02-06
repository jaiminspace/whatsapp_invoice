import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/ui/app_confirm_dialog.dart';
import '../../../../core/ui/app_phone_field.dart';
import '../../../../core/ui/app_snack.dart';
import '../state/customer_notifier.dart';
import '../state/customer_sales_provider.dart';
import '../../domain/customer_model.dart';

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

  Future<void> _openAddOrEdit({Customer? editing}) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CustomerFormSheet(editing: editing),
    );
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
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            tooltip: 'Add customer',
            icon: const Icon(Icons.add),
            onPressed: () => _openAddOrEdit(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('Add Customer'),
      ),
      body: Column(
        children: [
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

                final joined = DateFormat('dd MMM yyyy').format(c.createdAt);

                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.35),
                    ),
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    child: Row(
                      children: [
                        _AvatarImage(
                          radius: 20,
                          name: name,
                          imagePath: c.imagePath,
                        ),
                        const SizedBox(width: 12),

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
                              const SizedBox(height: 2),
                              Text(
                                'Joined: $joined',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 10),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Total Sale',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${sale.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _openAddOrEdit(editing: c),
                                ),
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

class _CustomerFormSheet extends ConsumerStatefulWidget {
  final Customer? editing;
  const _CustomerFormSheet({this.editing});

  @override
  ConsumerState<_CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends ConsumerState<_CustomerFormSheet> {
  late final TextEditingController nameCtrl;
  late final TextEditingController addressCtrl;

  String _mobileE164 = '';
  bool _mobileValid = false;
  String? _imagePath;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.editing;
    nameCtrl = TextEditingController(text: c?.name ?? '');
    addressCtrl = TextEditingController(text: c?.address ?? '');
    _mobileE164 = c?.mobile ?? '';
    _imagePath = c?.imagePath;

    // If old mobile exists, allow saving only after field validates again.
    _mobileValid = false;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    addressCtrl.dispose();
    super.dispose();
  }

  bool get _canSave {
    final nameOk = nameCtrl.text.trim().isNotEmpty;
    return nameOk && _mobileValid;
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
        const SnackBar(content: Text('Customer name is required')),
      );
      return;
    }

    if (!_mobileValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid mobile number')),
      );
      return;
    }

    setState(() => _saving = true);

    final address = addressCtrl.text.trim();

    if (widget.editing == null) {
      await ref.read(customerListProvider.notifier).addCustomer(
        name: name,
        mobile: _mobileE164,
        address: address,
        imagePath: _imagePath,
      );
    } else {
      await ref.read(customerListProvider.notifier).updateCustomer(
        id: widget.editing!.id,
        name: name,
        mobile: _mobileE164,
        address: address,
        imagePath: _imagePath,
      );
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editing != null;
    final joined = isEdit ? DateFormat('dd MMM yyyy').format(widget.editing!.createdAt) : null;

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
              isEdit ? 'Edit Customer' : 'Add Customer',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (joined != null) ...[
              const SizedBox(height: 6),
              Text('Joined: $joined', style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 12),

            Row(
              children: [
                _AvatarPicker(
                  imagePath: _imagePath,
                  name: nameCtrl.text.trim().isEmpty ? 'C' : nameCtrl.text.trim(),
                  onTap: _pickImage,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Customer name *',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            AppPhoneField(
              initialText: _mobileE164,
              label: 'Mobile number *',
              onChangedE164: (v) => _mobileE164 = v,
              onValidChanged: (ok) => setState(() => _mobileValid = ok),
            ),

            if (!_mobileValid) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Enter a valid mobile number',
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

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context, false),
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

class _AvatarPicker extends StatelessWidget {
  final String? imagePath;
  final String name;
  final VoidCallback onTap;

  const _AvatarPicker({
    required this.imagePath,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: onTap,
      child: Stack(
        children: [
          _AvatarImage(radius: 28, name: name, imagePath: imagePath),
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

class _AvatarImage extends StatelessWidget {
  final double radius;
  final String name;
  final String? imagePath;

  const _AvatarImage({
    required this.radius,
    required this.name,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = (imagePath ?? '').trim().isNotEmpty && File(imagePath!).existsSync();

    if (hasImage) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(File(imagePath!)),
      );
    }

    final letter = name.trim().isEmpty ? 'C' : name.trim()[0].toUpperCase();
    return CircleAvatar(radius: radius, child: Text(letter));
  }
}
