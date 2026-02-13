import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/ui/app_confirm_dialog.dart';
import '../../../../core/ui/app_phone_field.dart';
import '../../domain/customer_model.dart';
import '../state/customer_notifier.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({
    super.key,
    this.autoOpenAddIfEmpty = false, // 👈 enable only if you want initial flow
  });

  /// If true: when page is first shown AND customers list is empty,
  /// open the Add Customer sheet once.
  final bool autoOpenAddIfEmpty;

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  final _searchCtrl = TextEditingController();

  // ✅ prevents re-entrancy while sheet opening/open
  bool _isSheetOpen = false;

  // ✅ prevents "initial flow" from opening again on back/rebuild
  bool _didAutoOpenOnce = false;

  @override
  void initState() {
    super.initState();

    // ✅ Auto-open ONLY ONCE, and NEVER from build().
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!widget.autoOpenAddIfEmpty) return;
      if (_didAutoOpenOnce) return;

      final customers = ref.read(customerListProvider);
      if (customers.isEmpty) {
        _didAutoOpenOnce = true;
        await _openAddOrEdit(context);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openAddOrEdit(BuildContext context, {Customer? customer}) async {
    if (_isSheetOpen) return; // ✅ HARD LOCK
    _isSheetOpen = true;

    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => _CustomerFormSheet(customer: customer),
      );
    } finally {
      _isSheetOpen = false;
    }
  }

  bool _isValidPhone(String input) {
    final v = input.trim();
    if (v.isEmpty) return false;

    final digitsOnly = RegExp(r'^\d{10}$');
    final e164 = RegExp(r'^\+\d{10,15}$');

    return digitsOnly.hasMatch(v) || e164.hasMatch(v);
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customerListProvider);

    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? customers
        : customers.where((c) {
      final n = c.name.toLowerCase();
      final m = c.mobile.toLowerCase();
      return n.contains(q) || m.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers / Clients'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSheetOpen ? null : () => _openAddOrEdit(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Customer'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search name or mobile...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.trim().isEmpty
                    ? null
                    : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {});
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: customers.isEmpty
                ? const Center(
              child: Text('No customers yet.\nTap + to add one.'),
            )
                : filtered.isEmpty
                ? Center(
              child: Text(
                'No results for "${_searchCtrl.text.trim()}"',
                textAlign: TextAlign.center,
              ),
            )
                : ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final c = filtered[i];
                final phoneOk = _isValidPhone(c.mobile);

                final hasImage = c.imagePath != null &&
                    c.imagePath!.trim().isNotEmpty &&
                    File(c.imagePath!).existsSync();

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage:
                    hasImage ? FileImage(File(c.imagePath!)) : null,
                    child: hasImage
                        ? null
                        : Text(
                      (c.name.trim().isEmpty
                          ? 'C'
                          : c.name.trim()[0])
                          .toUpperCase(),
                    ),
                  ),
                  title: Text(c.name.isEmpty ? 'Customer' : c.name),
                  subtitle: Text(
                    phoneOk ? c.mobile : '${c.mobile}  (invalid)',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: _isSheetOpen
                            ? null
                            : () => _openAddOrEdit(
                          context,
                          customer: c,
                        ),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: () async {
                          final ok = await AppConfirmDialog.show(
                            context,
                            title: 'Delete customer?',
                            message:
                            'This will remove "${c.name.isEmpty ? 'Customer' : c.name}".',
                            confirmText: 'Delete',
                          );
                          if (!ok) return;

                          await ref
                              .read(customerListProvider.notifier)
                              .deleteCustomer(c.id);
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
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
  final Customer? customer;
  const _CustomerFormSheet({this.customer});

  @override
  ConsumerState<_CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends ConsumerState<_CustomerFormSheet> {
  late final TextEditingController nameCtrl;
  late final TextEditingController addressCtrl;

  bool get isEdit => widget.customer != null;

  // ✅ AppPhoneField state
  late String _phoneE164;
  bool _phoneValid = false;

  // ✅ Image restored
  String? _imagePath;

  @override
  void initState() {
    super.initState();

    final c = widget.customer;
    nameCtrl = TextEditingController(text: c?.name ?? '');
    addressCtrl = TextEditingController(text: c?.address ?? '');

    // mobile stored as E.164 in your app
    _phoneE164 = c?.mobile ?? '';
    _imagePath = c?.imagePath;

    // field will update validity via callback;
    // we can set a reasonable initial value:
    _phoneValid = _phoneE164.trim().isNotEmpty;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return;
    setState(() => _imagePath = file.path);
  }

  void _removeImage() {
    setState(() => _imagePath = null);
  }

  @override
  Widget build(BuildContext context) {
    final name = nameCtrl.text.trim();
    final canSave = name.isNotEmpty && _phoneValid;

    final hasImage = _imagePath != null &&
        _imagePath!.trim().isNotEmpty &&
        File(_imagePath!).existsSync();

    return Padding(
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
          const SizedBox(height: 12),

          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundImage: hasImage ? FileImage(File(_imagePath!)) : null,
                child: hasImage
                    ? null
                    : const Icon(Icons.person_outline, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_outlined),
                  label: Text(hasImage ? 'Change photo' : 'Add photo'),
                ),
              ),
              const SizedBox(width: 8),
              if (hasImage)
                IconButton(
                  tooltip: 'Remove photo',
                  onPressed: _removeImage,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),

          const SizedBox(height: 12),

          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Customer name *',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),

          // ✅ PhoneField used instead of TextField (mobile)
          AppPhoneField(
            initialText: _phoneE164,
            label: 'Customer phone *',
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
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canSave
                  ? () async {
                await ref.read(customerListProvider.notifier).upsertCustomer(
                  editing: widget.customer,
                  name: nameCtrl.text.trim(),
                  mobile: _phoneE164.trim(), // ✅ save E.164
                  address: addressCtrl.text.trim().isEmpty
                      ? null
                      : addressCtrl.text.trim(),
                  imagePath: _imagePath,
                );

                if (mounted) Navigator.pop(context);
              }
                  : null,
              child: Text(isEdit ? 'Save' : 'Add'),
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
