import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive/hive.dart';

import '../../domain/activity_log_model.dart';
import '../../domain/item_catalog_models.dart';
import 'activity_log_notifier.dart';

String catalogBoxNameForBiz(String businessId) => 'catalog_items_$businessId';

/// ✅ Box per business
final catalogBoxProvider = Provider.family<Box, String>((ref, businessId) {
  return Hive.box(catalogBoxNameForBiz(businessId));
});

/// ✅ Provider per business (FAMILY)
final catalogProvider = StateNotifierProvider.family<CatalogNotifier,
    List<CatalogItem>, String>((ref, businessId) {
  return CatalogNotifier(ref: ref, businessId: businessId);
});

class CatalogNotifier extends StateNotifier<List<CatalogItem>> {
  final Ref ref;
  final String businessId;

  StreamSubscription? _sub;

  CatalogNotifier({
    required this.ref,
    required this.businessId,
  }) : super(const []) {
    // initial
    state = _readAll();

    // watch hive changes
    _sub?.cancel();
    _sub = _box.watch().listen((_) {
      state = _readAll();
    });
  }

  Box get _box => ref.read(catalogBoxProvider(businessId));

  List<CatalogItem> _readAll() {
    final list = _box.values
        .whereType<Map>()
        .map((e) => CatalogItem.fromJson(e))
        .where((e) => e.businessId.trim().isEmpty || e.businessId == businessId)
        .toList();

    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
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
  }) async {
    final n = name.trim();
    if (n.isEmpty) return;

    final safePrice = (price.isNaN || price.isInfinite) ? 0.0 : price;

    final item = CatalogItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      businessId: businessId,
      name: n,
      price: safePrice < 0 ? 0.0 : safePrice,
      unit: unit,
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
          'businessId': businessId,
          'name': item.name,
          'price': item.price,
          'unit': item.unit.name,
        },
      ),
    );
  }

  Future<void> update(CatalogItem item) async {
    final safePrice = (item.price.isNaN || item.price.isInfinite)
        ? 0.0
        : (item.price < 0 ? 0.0 : item.price);

    final updated = item.copyWith(
      businessId: businessId,
      name: item.name.trim(),
      price: safePrice,
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
          'businessId': businessId,
          'name': updated.name,
          'price': updated.price,
          'unit': updated.unit.name,
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
          'businessId': businessId,
          'name': old?.name ?? '',
          'price': old?.price ?? 0.0,
          'unit': old?.unit.name ?? UnitType.pcs.name,
        },
      ),
    );
  }
}
