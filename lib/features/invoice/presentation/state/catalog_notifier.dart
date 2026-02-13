import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../domain/activity_log_model.dart';
import '../../domain/item_catalog_models.dart';
import 'activity_log_notifier.dart';

const String kCatalogBoxName = 'catalog_items';

/// ✅ Single box for all items (NOT per business)
final catalogBoxProvider = Provider<Box>((ref) {
  return Hive.box(kCatalogBoxName);
});

/// ✅ Catalog list for all items
final catalogProvider =
NotifierProvider<CatalogNotifier, List<CatalogItem>>(CatalogNotifier.new);

class CatalogNotifier extends Notifier<List<CatalogItem>> {
  StreamSubscription? _sub;

  Box get _box => ref.read(catalogBoxProvider);

  List<CatalogItem> _readAll() {
    final list = _box.values
        .whereType<Map>()
        .map((e) => CatalogItem.fromJson(e))
        .toList();

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

  Future<void> add({
    required String name,
    required double price,
    required UnitType unit,
    required List<String> businessIds,
  }) async {
    final n = name.trim();
    if (n.isEmpty) return;

    final safePrice = (price.isNaN || price.isInfinite) ? 0.0 : price;
    final bizIds = businessIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    final item = CatalogItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: n,
      price: safePrice < 0 ? 0.0 : safePrice,
      unit: unit,
      businessIds: bizIds, // ✅ [] => global item for all businesses
      updatedAt: DateTime.now(),
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
        'New item "${item.name.isEmpty ? 'Item' : item.name}" added (Unit: ${item.unit.name}) at ₹${item.price.toStringAsFixed(2)}.',
        meta: {
          'name': item.name,
          'price': item.price,
          'unit': item.unit.name,
          'businessIds': item.businessIds,
        },
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
      businessIds: item.businessIds
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList(),
      updatedAt: DateTime.now(),
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
        'Item "${updated.name.isEmpty ? 'Item' : updated.name}" updated. Unit: ${updated.unit.name}. Price: ₹${updated.price.toStringAsFixed(2)}.',
        meta: {
          'name': updated.name,
          'price': updated.price,
          'unit': updated.unit.name,
          'businessIds': updated.businessIds,
        },
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
        meta: {
          'name': old?.name ?? '',
          'price': old?.price ?? 0.0,
          'unit': old?.unit.name ?? UnitType.pcs.name,
          'businessIds': old?.businessIds ?? const <String>[],
        },
      ),
    );
  }
}
