import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/catalog_notifier.dart';
import '../../domain/item_catalog_models.dart';
import '../../../../core/ui/app_confirm_dialog.dart';

class ItemsPage extends ConsumerStatefulWidget {
  const ItemsPage({super.key});

  @override
  ConsumerState<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends ConsumerState<ItemsPage> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(catalogProvider);

    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? items
        : items.where((e) => e.name.toLowerCase().contains(q)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Items (Catalog)')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddOrEdit(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
      body: Column(
        children: [
          // ✅ Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search item name...',
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
            child: items.isEmpty
                ? const Center(child: Text('No items yet.\nTap + to add one.'))
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
                final it = filtered[i];
                return ListTile(
                  title: Text(it.name.isEmpty ? 'Item' : it.name),
                  subtitle: Text('₹${it.price.toStringAsFixed(2)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: () =>
                            _openAddOrEdit(context, ref, item: it),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: () async {
                          final ok = await AppConfirmDialog.show(
                            context,
                            title: 'Delete item?',
                            message: 'This will remove "${it.name}".',
                            confirmText: 'Delete',
                          );
                          if (!ok) return;

                          await ref
                              .read(catalogProvider.notifier)
                              .delete(it.id);
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

  Future<void> _openAddOrEdit(
      BuildContext context,
      WidgetRef ref, {
        CatalogItem? item,
      }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ItemFormSheet(item: item),
    );
  }
}

class _ItemFormSheet extends ConsumerStatefulWidget {
  final CatalogItem? item;

  const _ItemFormSheet({this.item});

  @override
  ConsumerState<_ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends ConsumerState<_ItemFormSheet> {
  late final TextEditingController nameCtrl;
  late final TextEditingController priceCtrl;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    nameCtrl = TextEditingController(text: it?.name ?? '');
    priceCtrl = TextEditingController(
      text: it == null ? '' : it!.price.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;

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
            isEdit ? 'Edit Item' : 'Add Item',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Item name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Default price',
              border: OutlineInputBorder(),
              prefixText: '₹ ',
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Item name required')),
                );
                return;
              }

              final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;

              if (isEdit) {
                await ref
                    .read(catalogProvider.notifier)
                    .update(widget.item!.copyWith(name: name, price: price));
              } else {
                await ref.read(catalogProvider.notifier).add(name, price);
              }

              if (mounted) Navigator.pop(context);
            },
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
