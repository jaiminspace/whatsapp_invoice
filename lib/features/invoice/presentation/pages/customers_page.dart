import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/ui/app_confirm_dialog.dart';
import '../../../../core/ui/app_phone_field.dart';
import '../../domain/customer_model.dart';
import '../state/customer_notifier.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({
    super.key,
    this.autoOpenAddIfEmpty = false,
  });

  final bool autoOpenAddIfEmpty;

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  final _searchCtrl = TextEditingController();

  bool _isSheetOpen = false;
  bool _didAutoOpenOnce = false;

  @override
  void initState() {
    super.initState();

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
    if (_isSheetOpen) return;
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

  Future<void> _launch(Uri uri) async {
    final ok = await canLaunchUrl(uri);
    if (!ok) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _call(String phone) async {
    final p = phone.trim();
    if (p.isEmpty) return;
    await _launch(Uri(scheme: 'tel', path: p));
  }

  Future<void> _sms(String phone) async {
    final p = phone.trim();
    if (p.isEmpty) return;
    await _launch(Uri(scheme: 'sms', path: p));
  }

  Future<void> _whatsapp(String phoneE164) async {
    // WhatsApp expects digits only, without '+'
    final p = phoneE164.trim();
    if (p.isEmpty) return;

    final normalized = p.startsWith('+') ? p.substring(1) : p;
    await _launch(Uri.parse('https://wa.me/$normalized'));
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
      body: SafeArea(
        child: Column(
          children: [
            // ---------------- Search ----------------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search name or phone…',
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
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),

            // ---------------- List ----------------
            Expanded(
              child: customers.isEmpty
                  ? const _EmptyState()
                  : filtered.isEmpty
                  ? _NoResultsState(query: _searchCtrl.text.trim())
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final c = filtered[i];
                  final phoneOk = _isValidPhone(c.mobile);

                  final hasImage = c.imagePath != null &&
                      c.imagePath!.trim().isNotEmpty &&
                      File(c.imagePath!).existsSync();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CustomerModernCard(
                      customer: c,
                      hasImage: hasImage,
                      phoneOk: phoneOk,
                      onEdit: () => _openAddOrEdit(context, customer: c),
                      onDelete: () async {
                        final ok = await AppConfirmDialog.show(
                          context,
                          title: 'Delete customer?',
                          message:
                          'This will remove "${c.name.isEmpty ? 'Customer' : c.name}".',
                          confirmText: 'Delete',
                          isDanger: true,
                        );
                        if (!ok) return;

                        await ref
                            .read(customerListProvider.notifier)
                            .deleteCustomer(c.id);
                      },
                      onCall: phoneOk ? () => _call(c.mobile) : null,
                      onSms: phoneOk ? () => _sms(c.mobile) : null,
                      onWhatsapp: phoneOk ? () => _whatsapp(c.mobile) : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Modern Customer Card
// ============================================================================

class _CustomerModernCard extends StatelessWidget {
  final Customer customer;
  final bool hasImage;
  final bool phoneOk;

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  final VoidCallback? onCall;
  final VoidCallback? onSms;
  final VoidCallback? onWhatsapp;

  const _CustomerModernCard({
    required this.customer,
    required this.hasImage,
    required this.phoneOk,
    required this.onEdit,
    required this.onDelete,
    required this.onCall,
    required this.onSms,
    required this.onWhatsapp,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final name = customer.name.trim().isEmpty ? 'Customer' : customer.name.trim();
    final phone = customer.mobile.trim();
    final address = (customer.address ?? '').trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
        color: cs.surface,
      ),
      child: Column(
        children: [
          // -------- top row --------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage:
                hasImage ? FileImage(File(customer.imagePath!)) : null,
                child: hasImage
                    ? null
                    : Text(
                  name.characters.first.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name (no ellipsis)
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                      maxLines: null,
                      softWrap: true,
                    ),
                    const SizedBox(height: 6),

                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.call_outlined,
                              size: 16,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              phone.isEmpty ? '-' : phone,
                              style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: null,
                              softWrap: true,
                            ),
                          ],
                        ),
                        if (!phoneOk && phone.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: cs.error.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Invalid',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: cs.error,
                              ),
                            ),
                          ),
                      ],
                    ),

                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              address,
                              style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurfaceVariant,
                              ),
                              maxLines: null,
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              PopupMenuButton<String>(
                tooltip: 'Options',
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
                child: Padding(
                  padding: const EdgeInsets.only(left: 6, top: 2),
                  child: Icon(Icons.more_vert, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // -------- actions (overflow safe) --------
          LayoutBuilder(
            builder: (context, constraints) {
              // 2 per row on small widths, 3 per row on big widths
              final w = constraints.maxWidth;

              final show3 = w >= 420; // tablets / large phones
              final spacing = 10.0;

              final itemWidth = show3
                  ? (w - (spacing * 2)) / 3
                  : (w - spacing) / 2;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _ActionChip(
                      icon: Icons.call_rounded,
                      label: 'Call',
                      enabled: onCall != null,
                      onTap: onCall,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _ActionChip(
                      icon: Icons.message_rounded,
                      label: 'SMS',
                      enabled: onSms != null,
                      onTap: onSms,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _ActionChip(
                      icon: Icons.chat_bubble_outline,
                      label: 'WhatsApp',
                      enabled: onWhatsapp != null,
                      onTap: onWhatsapp,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
          color: enabled ? cs.surface : cs.surfaceVariant.withOpacity(0.35),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: enabled ? cs.primary : cs.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: enabled
                      ? cs.primary
                      : cs.onSurfaceVariant.withOpacity(0.6),
                ),
                overflow: TextOverflow.visible,
                softWrap: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Empty / No Results
// ============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.people_alt_outlined, size: 32, color: cs.primary),
            ),
            const SizedBox(height: 12),
            const Text(
              'No customers yet',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Tap “Add Customer” to create your first customer.',
              style: TextStyle(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  final String query;
  const _NoResultsState({required this.query});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                color: cs.secondary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.search_off, size: 32, color: cs.secondary),
            ),
            const SizedBox(height: 12),
            const Text(
              'No results',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              query.isEmpty ? 'Try a different search.' : 'No match for "$query".',
              style: TextStyle(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Bottom Sheet (your original logic preserved)
// ============================================================================

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

  late String _phoneE164;
  bool _phoneValid = false;

  String? _imagePath;

  @override
  void initState() {
    super.initState();

    final c = widget.customer;
    nameCtrl = TextEditingController(text: c?.name ?? '');
    addressCtrl = TextEditingController(text: c?.address ?? '');

    _phoneE164 = c?.mobile ?? '';
    _imagePath = c?.imagePath;

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

  void _removeImage() => setState(() => _imagePath = null);

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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),

          // Row(
          //   children: [
          //     CircleAvatar(
          //       radius: 26,
          //       backgroundImage: hasImage ? FileImage(File(_imagePath!)) : null,
          //       child: hasImage ? null : const Icon(Icons.person_outline, size: 26),
          //     ),
          //     const SizedBox(width: 12),
          //     Expanded(
          //       child: OutlinedButton.icon(
          //         onPressed: _pickImage,
          //         icon: const Icon(Icons.photo_outlined),
          //         label: Text(hasImage ? 'Change photo' : 'Add photo'),
          //       ),
          //     ),
          //     const SizedBox(width: 8),
          //     if (hasImage)
          //       IconButton(
          //         tooltip: 'Remove photo',
          //         onPressed: _removeImage,
          //         icon: const Icon(Icons.delete_outline),
          //       ),
          //   ],
          // ),
          //
          // const SizedBox(height: 12),

          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Customer name *',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),

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
                  fontWeight: FontWeight.w700,
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
            minLines: 1,
            maxLines: 3,
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
                  mobile: _phoneE164.trim(),
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
