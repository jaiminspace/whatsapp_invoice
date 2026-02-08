import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../state/invoice_list_notifier.dart';
import '../state/customer_notifier.dart';

import '../../../../core/ui/app_confirm_dialog.dart';
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
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _manualInvCtrl;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(invoiceDraftProvider);
    _nameCtrl = TextEditingController(text: draft.customerName);
    _mobileCtrl = TextEditingController(text: draft.customerMobile);
    _manualInvCtrl = TextEditingController(text: draft.customInvoiceNumber);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _manualInvCtrl.dispose();
    super.dispose();
  }

  void _resetDraft() {
    ref.read(invoiceDraftProvider.notifier).reset();
    _nameCtrl.text = '';
    _mobileCtrl.text = '';
    _manualInvCtrl.text = '';
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

    // ✅ IMPORTANT for units later:
    // notifier.updateItemUnit(index, selected.unit);  // (add this when invoice item supports unit)
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Invoice' : 'Create Invoice'),
        actions: [
          IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.save),
            onPressed: _saveInvoice, // ✅ TOP SAVE
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
                _mobileCtrl.text = mobile;
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

          TextField(
            controller: _mobileCtrl,
            decoration: const InputDecoration(
              labelText: 'Customer / Client mobile',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
            onChanged: notifier.setCustomerMobile,
          ),

          const SizedBox(height: 18),

          // ITEMS HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Items',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              FilledButton.icon(
                onPressed: notifier.addItem,
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
                            decoration: const InputDecoration(
                              labelText: 'Item name *',
                              border: OutlineInputBorder(),
                            ),
                            controller: TextEditingController(text: item.name)
                              ..selection = TextSelection.fromPosition(
                                TextPosition(offset: item.name.length),
                              ),
                            onChanged: (v) => notifier.updateItemName(index, v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => notifier.removeItem(index),
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
                            decoration: const InputDecoration(
                              labelText: 'Qty *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            controller:
                            TextEditingController(text: item.qty.toString())
                              ..selection = TextSelection.fromPosition(
                                TextPosition(
                                  offset: item.qty.toString().length,
                                ),
                              ),
                            onChanged: (v) => notifier.updateItemQty(
                              index,
                              int.tryParse(v) ?? 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Price',
                              border: OutlineInputBorder(),
                              prefixText: '₹ ',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            controller: TextEditingController(
                              text: item.price.toStringAsFixed(2),
                            )..selection = TextSelection.fromPosition(
                              TextPosition(
                                offset: item.price.toStringAsFixed(2).length,
                              ),
                            ),
                            onChanged: (v) => notifier.updateItemPrice(
                              index,
                              double.tryParse(v) ?? 0.0,
                            ),
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
                onPressed: notifier.addItem,
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
                style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // BOTTOM SAVE (keep it)
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

    // ✅ Filter items for selected business:
    // - if item.businessIds is empty => global for all
    // - else must contain selected bizId
    final visible = all.where((it) {
      if (it.businessIds.isEmpty) return true;
      return it.businessIds.contains(widget.bizId);
    }).toList();

    final q = _searchCtrl.text.trim().toLowerCase();
    final list = q.isEmpty
        ? visible
        : visible.where((e) => e.name.toLowerCase().contains(q)).toList();

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


