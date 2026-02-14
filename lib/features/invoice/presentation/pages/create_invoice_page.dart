import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../state/invoice_list_notifier.dart';
import '../state/customer_notifier.dart';

import '../../../../core/ui/app_confirm_dialog.dart';
import '../../../../core/ui/app_phone_field.dart'; // ✅ make sure this path matches your project
import '../../domain/business_profile.dart';
import '../state/business_profile_notifier.dart';

import '../state/business_list_notifier.dart';
import '../state/catalog_notifier.dart';
import '../../domain/item_catalog_models.dart';
import '../state/invoice_draft_notifier.dart';
import '../../domain/invoice_models.dart';

class CreateInvoicePage extends ConsumerStatefulWidget {
  final bool isEdit;
  final String? editingInvoiceId;

  const CreateInvoicePage({
    super.key,
    this.isEdit = false,
    this.editingInvoiceId,
  });

  @override
  ConsumerState<CreateInvoicePage> createState() => _CreateInvoicePageState();
}

class _CreateInvoicePageState extends ConsumerState<CreateInvoicePage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _manualInvCtrl;

  // ✅ AppPhoneField state (same behavior as bottom sheets)
  String _customerPhoneE164 = '';
  bool _customerPhoneValid = true;

  // ✅ Stable controllers for item rows
  final List<TextEditingController> _itemNameCtrls = [];
  final List<TextEditingController> _itemQtyCtrls = [];
  final List<TextEditingController> _itemPriceCtrls = [];

  @override
  void initState() {
    super.initState();
    final draft = ref.read(invoiceDraftProvider);

    _nameCtrl = TextEditingController(text: draft.customerName);
    _manualInvCtrl = TextEditingController(text: draft.customInvoiceNumber);

    _customerPhoneE164 = draft.customerMobile;
    _customerPhoneValid = true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _manualInvCtrl.dispose();

    for (final c in _itemNameCtrls) c.dispose();
    for (final c in _itemQtyCtrls) c.dispose();
    for (final c in _itemPriceCtrls) c.dispose();

    super.dispose();
  }

  void _syncItemControllers(List<InvoiceItem> items) {
    // Add controllers if items increased
    while (_itemNameCtrls.length < items.length) {
      final i = _itemNameCtrls.length;

      _itemNameCtrls.add(TextEditingController(text: items[i].name));
      _itemQtyCtrls.add(TextEditingController(text: items[i].qty.toString()));

      // ✅ keep raw string (no toFixed) so typing doesn't fight rebuilds
      final initialPrice = items[i].price == 0 ? '' : items[i].price.toString();
      _itemPriceCtrls.add(TextEditingController(text: initialPrice));
    }

    // Remove controllers if items decreased
    while (_itemNameCtrls.length > items.length) {
      _itemNameCtrls.removeLast().dispose();
      _itemQtyCtrls.removeLast().dispose();
      _itemPriceCtrls.removeLast().dispose();
    }
  }

  void _resetDraft() {
    ref.read(invoiceDraftProvider.notifier).reset();
    _nameCtrl.text = '';
    _manualInvCtrl.text = '';

    // ✅ reset phone field state
    setState(() {
      _customerPhoneE164 = '';
      _customerPhoneValid = true;
    });

    for (final c in _itemNameCtrls) c.dispose();
    for (final c in _itemQtyCtrls) c.dispose();
    for (final c in _itemPriceCtrls) c.dispose();
    _itemNameCtrls.clear();
    _itemQtyCtrls.clear();
    _itemPriceCtrls.clear();
  }

  Future<void> _pickInvoiceDateTime() async {
    final draft = ref.read(invoiceDraftProvider);
    final notifier = ref.read(invoiceDraftProvider.notifier);

    final date = await showDatePicker(
      context: context,
      initialDate: draft.invoiceDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(draft.invoiceDateTime),
    );
    if (time == null) return;

    notifier.setInvoiceDateTime(DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ));
  }

  Future<void> _pickCatalogItemForRow(int index) async {
    final draft = ref.read(invoiceDraftProvider);
    final bizId = draft.businessId.trim();

    if (bizId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a business first')),
      );
      return;
    }

    final selected = await showModalBottomSheet<CatalogItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CatalogPickerSheet(bizId: bizId),
    );

    if (selected == null) return;

    final notifier = ref.read(invoiceDraftProvider.notifier);
    notifier.updateItemName(index, selected.name);
    notifier.updateItemPrice(index, selected.price);

    // ✅ Update controllers text so UI updates immediately
    if (index >= 0 && index < _itemNameCtrls.length) {
      _itemNameCtrls[index].text = selected.name;
      _itemNameCtrls[index].selection = TextSelection.fromPosition(
        TextPosition(offset: _itemNameCtrls[index].text.length),
      );
    }
    if (index >= 0 && index < _itemPriceCtrls.length) {
      _itemPriceCtrls[index].text = selected.price.toString();
      _itemPriceCtrls[index].selection = TextSelection.fromPosition(
        TextPosition(offset: _itemPriceCtrls[index].text.length),
      );
    }
  }

  // ✅ one save method used by AppBar + bottom button
  Future<void> _saveInvoice() async {
    final draft = ref.read(invoiceDraftProvider);
    final notifier = ref.read(invoiceDraftProvider.notifier);
    final businesses = ref.read(businessListProvider);

    if (businesses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a business first')),
      );
      return;
    }

    if (draft.businessId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a business')),
      );
      return;
    }

    // ✅ Validation: must have at least 1 valid item
    if (!notifier.hasAtLeastOneValidItem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 1 valid item (name required)')),
      );
      return;
    }

    // ✅ Optional: validate phone before save (uncomment if you want)
    // if (!_customerPhoneValid) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('Enter a valid phone number')),
    //   );
    //   return;
    // }

    // ✅ manual mode invoice number required
    final selectedBusiness = ref.read(selectedBusinessProvider);
    final manualMode = selectedBusiness?.invoiceNumberMode == InvoiceNumberMode.manual;
    if (manualMode && draft.customInvoiceNumber.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter invoice number')),
      );
      return;
    }

    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(draft.invoiceDateTime);

    final ok = await AppConfirmDialog.show(
      context,
      title: widget.isEdit ? 'Update invoice?' : 'Save invoice?',
      message:
      'Type: ${draft.status == PaymentStatus.paid ? 'Paid' : 'Unpaid'}\n'
          'Total: ₹${draft.grandTotal.toStringAsFixed(2)}\n'
          'Customer: ${draft.customerName.isEmpty ? 'Customer' : draft.customerName}\n'
          'Date: $dateStr',
      confirmText: widget.isEdit ? 'Update' : 'Save',
    );
    if (!ok) return;

    if (widget.isEdit) {
      final id = widget.editingInvoiceId;
      if (id == null || id.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Missing invoice id to edit')),
        );
        return;
      }
      await ref.read(invoiceListProvider.notifier).updateFromDraft(
        invoiceId: id,
        draft: draft,
      );
    } else {
      await ref.read(invoiceListProvider.notifier).addFromDraft(draft);
    }

    // ✅ upsert customer
    await ref.read(customerListProvider.notifier).upsertFromInvoice(
      name: draft.customerName,
      mobile: draft.customerMobile,
    );

    ref.read(invoiceDraftProvider.notifier).reset();

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(invoiceDraftProvider);
    final notifier = ref.read(invoiceDraftProvider.notifier);

    final profile = ref.watch(businessProfileProvider);
    final isManual = profile.invoiceNumberMode == InvoiceNumberMode.manual;

    final businesses = ref.watch(businessListProvider);
    final selectedBusiness = ref.watch(selectedBusinessProvider);

    // ✅ prevent Dropdown crash: ensure selected value exists
    final currentId = draft.businessId.trim().isNotEmpty
        ? draft.businessId
        : (selectedBusiness?.id ?? (businesses.isNotEmpty ? businesses.first.id : ''));

    final safeBusinessId = businesses.any((b) => b.id == currentId)
        ? currentId
        : (businesses.isNotEmpty ? businesses.first.id : '');

    if (draft.businessId.trim().isEmpty && safeBusinessId.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(invoiceDraftProvider.notifier).setBusinessId(safeBusinessId);
      });
    }

    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(draft.invoiceDateTime);
    final showAddAnother = notifier.hasAtLeastOneValidItem;

    // ✅ Keep item controllers aligned with item count
    _syncItemControllers(draft.items);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Invoice' : 'Create Invoice'),
        actions: [
          IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.save),
            onPressed: _saveInvoice,
          ),
          IconButton(
            onPressed: _resetDraft,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // BUSINESS
          if (businesses.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: safeBusinessId,
              decoration: const InputDecoration(
                labelText: 'Business',
                border: OutlineInputBorder(),
              ),
              items: businesses
                  .map((b) => DropdownMenuItem(
                value: b.id,
                child: Text(b.name.isEmpty ? 'Business' : b.name),
              ))
                  .toList(),
              onChanged: (id) {
                if (id == null) return;
                ref.read(selectedBusinessIdProvider.notifier).state = id;
                notifier.setBusinessId(id);
              },
            )
          else
            const Card(
              child: ListTile(
                leading: Icon(Icons.storefront_outlined),
                title: Text('No business found'),
                subtitle: Text('Add at least 1 business to continue.'),
              ),
            ),

          const SizedBox(height: 12),

          // DATE
          OutlinedButton.icon(
            icon: const Icon(Icons.event),
            label: Text('Invoice Date/Time: $dateStr'),
            onPressed: _pickInvoiceDateTime,
          ),

          const SizedBox(height: 12),

          // ✅ INVOICE TYPE (Paid/Unpaid)
          DropdownButtonFormField<PaymentStatus>(
            initialValue: draft.status,
            decoration: const InputDecoration(
              labelText: 'Invoice Type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: PaymentStatus.pending,
                child: Text('Unpaid'),
              ),
              DropdownMenuItem(
                value: PaymentStatus.paid,
                child: Text('Paid'),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              notifier.setInvoiceStatus(v);
            },
          ),

          const SizedBox(height: 12),

          // CUSTOMER PICKER
          OutlinedButton.icon(
            icon: const Icon(Icons.person_search),
            label: const Text('Choose Customer / Client'),
            onPressed: () async {
              final selected = await showModalBottomSheet<Map<String, String>>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => const _CustomerPickerSheet(),
              );

              if (selected != null) {
                final name = selected['name'] ?? '';
                final mobile = selected['mobile'] ?? '';

                notifier.setCustomerName(name);
                notifier.setCustomerMobile(mobile);

                _nameCtrl.text = name;

                // ✅ sync AppPhoneField like bottom sheets
                setState(() {
                  _customerPhoneE164 = mobile;
                  _customerPhoneValid = true;
                });
              }
            },
          ),

          const SizedBox(height: 12),

          // MANUAL INVOICE NUMBER
          if (isManual) ...[
            TextField(
              controller: _manualInvCtrl,
              decoration: const InputDecoration(
                labelText: 'Invoice Number (Manual)',
                border: OutlineInputBorder(),
                hintText: 'e.g. JM-101',
              ),
              onChanged: notifier.setCustomInvoiceNumber,
            ),
            const SizedBox(height: 12),
          ],

          // CUSTOMER FIELDS
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Customer / Client name',
              border: OutlineInputBorder(),
            ),
            onChanged: notifier.setCustomerName,
          ),
          const SizedBox(height: 12),

          // ✅ Customer phone field (same as your bottom sheets)
          AppPhoneField(
            initialText: _customerPhoneE164,
            label: 'Customer / Client mobile *',
            onChangedE164: (v) {
              _customerPhoneE164 = v;
              notifier.setCustomerMobile(v);
            },
            onValidChanged: (ok) => setState(() => _customerPhoneValid = ok),
          ),

          if (!_customerPhoneValid) ...[
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

          const SizedBox(height: 18),

          // ITEMS HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Items',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              FilledButton.icon(
                onPressed: () {
                  notifier.addItem();
                },
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (draft.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No items. Tap "Add item" to start.'),
            ),

          // ITEMS LIST
          ...List.generate(draft.items.length, (index) {
            final item = draft.items[index];

            final nameCtrl = _itemNameCtrls[index];
            final qtyCtrl = _itemQtyCtrls[index];
            final priceCtrl = _itemPriceCtrls[index];

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Item name *',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => notifier.updateItemName(index, v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            notifier.removeItem(index);

                            // ✅ Keep controllers in sync immediately
                            if (index < _itemNameCtrls.length) {
                              _itemNameCtrls.removeAt(index).dispose();
                              _itemQtyCtrls.removeAt(index).dispose();
                              _itemPriceCtrls.removeAt(index).dispose();
                            }

                            setState(() {});
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _pickCatalogItemForRow(index),
                        icon: const Icon(Icons.list_alt_outlined),
                        label: const Text('Pick from Items Catalog'),
                      ),
                    ),

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: qtyCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Qty *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            onChanged: (v) {
                              final parsed = int.tryParse(v);
                              notifier.updateItemQty(index, parsed ?? 1);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: priceCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Price',
                              border: OutlineInputBorder(),
                              prefixText: '₹ ',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
                            ],
                            onChanged: (v) {
                              final cleaned = v.trim();

                              if (cleaned.isEmpty) {
                                notifier.updateItemPrice(index, 0.0);
                                return;
                              }

                              if (cleaned == '.' || cleaned.endsWith('.')) {
                                return;
                              }

                              final parsed = double.tryParse(cleaned);
                              if (parsed == null) return;

                              notifier.updateItemPrice(index, parsed);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Item total'),
                        Text('₹${item.total.toStringAsFixed(2)}'),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),

          // ✅ Add another item ONLY if at least one valid item exists
          if (showAddAnother) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  notifier.addItem();
                },
                icon: const Icon(Icons.add),
                label: const Text('Add another item'),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // GRAND TOTAL
          Card(
            child: ListTile(
              title: const Text('Grand Total'),
              trailing: Text(
                '₹${draft.grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // BOTTOM SAVE
          FilledButton(
            onPressed: _saveInvoice,
            child: Text(widget.isEdit ? 'Update Invoice' : 'Save Invoice'),
          ),
        ],
      ),
    );
  }
}

class _CustomerPickerSheet extends ConsumerWidget {
  const _CustomerPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customerListProvider);

    return SafeArea(
      child: customers.isEmpty
          ? const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No customers/clients yet'),
      )
          : ListView.separated(
        itemCount: customers.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final c = customers[i];
          return ListTile(
            title: Text(c.name.isEmpty ? 'Customer/Client' : c.name),
            subtitle: Text(c.mobile),
            onTap: () {
              Navigator.pop<Map<String, String>>(context, {
                'name': c.name,
                'mobile': c.mobile,
              });
            },
          );
        },
      ),
    );
  }
}

class _CatalogPickerSheet extends ConsumerStatefulWidget {
  final String bizId;
  const _CatalogPickerSheet({required this.bizId});

  @override
  ConsumerState<_CatalogPickerSheet> createState() => _CatalogPickerSheetState();
}

class _CatalogPickerSheetState extends ConsumerState<_CatalogPickerSheet> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(catalogProvider);

    final visible = all.where((it) {
      if (it.businessIds.isEmpty) return true;
      return it.businessIds.contains(widget.bizId);
    }).toList();

    final q = _searchCtrl.text.trim().toLowerCase();
    final list = q.isEmpty ? visible : visible.where((e) => e.name.toLowerCase().contains(q)).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pick Item',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search item...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No catalog items for this business.\nAdd items from Items page.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final it = list[i];
                    return ListTile(
                      title: Text(it.name.isEmpty ? 'Item' : it.name),
                      subtitle: Text(
                        '₹${it.price.toStringAsFixed(2)} • ${it.unit.name.toUpperCase()}',
                      ),
                      onTap: () => Navigator.pop<CatalogItem>(context, it),
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
