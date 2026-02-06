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

  // ✅ Prevent sheet on top of sheet
  bool _sheetOpen = false;

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
    if (_sheetOpen) return;
    _sheetOpen = true;

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CustomerFormSheet(editing: editing),
    );

    if (!mounted) return;
    _sheetOpen = false;
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: customers.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_alt_outlined, size: 44),
                    const SizedBox(height: 10),
                    const Text(
                      'No customer/client yet',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add your customers/clients to start creating invoices for them.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => _openAddOrEdit(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Customer/Client'),
                    ),
                  ],
                ),
              ),
            )
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
                        _AvatarImage(radius: 20, name: name, imagePath: c.imagePath),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
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
                              Text('Joined: $joined', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Total Sale', style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 2),
                            Text(
                              '₹${sale.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
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

// ---------------- BOTTOM SHEET ----------------

class _CustomerFormSheet extends ConsumerStatefulWidget {
  final Customer? editing;
  const _CustomerFormSheet({required this.editing});

  @override
  ConsumerState<_CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends ConsumerState<_CustomerFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;

  String _mobileE164 = '';
  bool _isPhoneValid = false;

  bool _phoneTouched = false;
  bool _submitted = false;

  // ✅ keep / update image safely
  String? _imagePath;
  bool _imageTouched = false; // ✅ only change image if user touches

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.editing?.name ?? '');
    _addressCtrl = TextEditingController(text: widget.editing?.address ?? '');

    _mobileE164 = widget.editing?.mobile ?? '';
    _imagePath = widget.editing?.imagePath;

    _isPhoneValid = _mobileE164.trim().isNotEmpty; // assume valid for existing
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (x == null) return;
    setState(() {
      _imageTouched = true;
      _imagePath = x.path;
    });
  }

  void _removeAvatar() {
    setState(() {
      _imageTouched = true;
      _imagePath = ''; // explicit clear
    });
  }

  bool get _canSave {
    final nameOk = _nameCtrl.text.trim().isNotEmpty;
    final phoneEntered = _mobileE164.trim().isNotEmpty;
    return nameOk && phoneEntered && _isPhoneValid;
  }

  Future<void> _saveCustomer() async {
    setState(() => _submitted = true);

    final ok = _formKey.currentState?.validate() ?? true;
    if (!ok) return;

    final name = _nameCtrl.text.trim();
    final address = _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim();
    final mobile = _mobileE164.trim();

    if (mobile.isEmpty || !_isPhoneValid) return;

    // ✅ Key rule:
    // If user did NOT touch image -> pass null so notifier keeps old image
    final imageForSave = _imageTouched ? _imagePath : null;

    await ref.read(customerListProvider.notifier).upsertCustomer(
      editing: widget.editing,
      name: name,
      mobile: mobile,
      address: address,
      imagePath: imageForSave,
    );

    if (!mounted) return;
    Navigator.pop(context, true);

    // Snack AFTER pop (safer)
    AppSnack.show(context, widget.editing == null ? 'Customer added' : 'Customer updated');
  }

  @override
  Widget build(BuildContext context) {
    final showPhoneError = _phoneTouched || _submitted;

    final displayName = _nameCtrl.text.trim().isEmpty ? 'Customer' : _nameCtrl.text.trim();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.disabled,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.editing == null ? 'Add Customer' : 'Edit Customer',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  _AvatarPicker(
                    imagePath: _imagePath,
                    name: displayName,
                    onTap: _pickAvatar,
                  ),
                  const SizedBox(width: 12),
                  if ((_imagePath ?? '').trim().isNotEmpty)
                    TextButton.icon(
                      onPressed: _removeAvatar,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Customer name *',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (!_submitted) return null;
                return (v ?? '').trim().isEmpty ? 'Name is required' : null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),

            AppPhoneField(
              initialText: _mobileE164,
              initialCountryCode: 'IN',
              label: 'Mobile number *',
              showError: showPhoneError,
              required: true,
              onChangedE164: (e164) {
                _phoneTouched = true;
                _mobileE164 = e164;
                setState(() {});
              },
              onValidChanged: (valid) {
                _phoneTouched = true;
                _isPhoneValid = valid;
                setState(() {});
              },
            ),

            const SizedBox(height: 10),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Address (optional)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _canSave ? _saveCustomer : null,
                    child: Text(widget.editing == null ? 'Save' : 'Update'),
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

// ---------------- AVATAR WIDGETS ----------------

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
    final p = (imagePath ?? '').trim();
    final hasImage = p.isNotEmpty && p != '' && File(p).existsSync();

    if (hasImage) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(File(p)),
      );
    }

    final letter = name.trim().isEmpty ? 'C' : name.trim()[0].toUpperCase();
    return CircleAvatar(radius: radius, child: Text(letter));
  }
}
