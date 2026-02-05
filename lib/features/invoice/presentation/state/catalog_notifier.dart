import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../domain/activity_log_model.dart';
import '../../domain/item_catalog_models.dart';
import 'activity_log_notifier.dart';

const kCatalogBoxName = 'catalog_items';

final catalogBoxProvider = Provider<Box>((ref) => Hive.box(kCatalogBoxName));

final catalogProvider = NotifierProvider<CatalogNotifier, List<CatalogItem>>(
  CatalogNotifier.new,
);

class CatalogNotifier extends Notifier<List<CatalogItem>> {
  StreamSubscription? _sub;

  Box get _box => ref.read(catalogBoxProvider);

  List<CatalogItem> _readAll() {
    final list = _box.values
        .whereType<Map>()
        .map((e) => CatalogItem.fromJson(e))
        .toList();

    // A–Z sorting
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  @override
  List<CatalogItem> build() {
    final initial = _readAll();

    _sub?.cancel();
    _sub = _box.watch().listen((_) {
      state = _readAll();
    });

    ref.onDispose(() => _sub?.cancel());
    return initial;
  }

  CatalogItem? getById(String id) {
    try {
      return state.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> add(String name, double price) async {
    final n = name.trim();
    if (n.isEmpty) return;

    final safePrice = (price.isNaN || price.isInfinite) ? 0.0 : price;

    final item = CatalogItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: n,
      price: safePrice < 0 ? 0.0 : safePrice,
      updatedAt: DateTime.now(), // ✅ required
    );

    await _box.put(item.id, item.toJson());
    state = _readAll();

    await ref.read(activityLogProvider.notifier).addLog(
      ActivityLog.create(
        entity: LogEntity.item,
        action: LogAction.create,
        entityId: item.id,
        title: 'Item created',
        message:
        'New item "${item.name.isEmpty ? 'Item' : item.name}" added at ₹${item.price.toStringAsFixed(2)}.',
        meta: {'name': item.name, 'price': item.price},
      ),
    );
  }

  Future<void> update(CatalogItem item) async {
    final safePrice = (item.price.isNaN || item.price.isInfinite)
        ? 0.0
        : (item.price < 0 ? 0.0 : item.price);

    final updated = item.copyWith(
      name: item.name.trim(),
      price: safePrice,
      updatedAt: DateTime.now(), // ✅ required
    );

    await _box.put(updated.id, updated.toJson());
    state = _readAll();

    await ref.read(activityLogProvider.notifier).addLog(
      ActivityLog.create(
        entity: LogEntity.item,
        action: LogAction.update,
        entityId: updated.id,
        title: 'Item updated',
        message:
        'Item "${updated.name.isEmpty ? 'Item' : updated.name}" updated. Price: ₹${updated.price.toStringAsFixed(2)}.',
        meta: {'name': updated.name, 'price': updated.price},
      ),
    );
  }

  Future<void> delete(String id) async {
    final old = getById(id);

    await _box.delete(id);
    state = _readAll();

    await ref.read(activityLogProvider.notifier).addLog(
      ActivityLog.create(
        entity: LogEntity.item,
        action: LogAction.delete,
        entityId: id,
        title: 'Item deleted',
        message: old == null
            ? 'Item deleted.'
            : 'Item "${old.name.isEmpty ? 'Item' : old.name}" deleted.',
        meta: {'name': old?.name ?? '', 'price': old?.price ?? 0.0},
      ),
    );
  }
}
