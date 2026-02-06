import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive/hive.dart';

import '../../domain/activity_log_model.dart';
import '../../domain/business_entity.dart';
import 'activity_log_notifier.dart';

final businessBoxProvider = Provider<Box>((ref) => Hive.box('businesses'));

final businessListProvider =
NotifierProvider<BusinessListNotifier, List<BusinessEntity>>(
  BusinessListNotifier.new,
);

final selectedBusinessIdProvider = StateProvider<String?>((ref) => null);

final selectedBusinessProvider = Provider<BusinessEntity?>((ref) {
  final list = ref.watch(businessListProvider);
  final id = ref.watch(selectedBusinessIdProvider);

  if (list.isEmpty) return null;
  if (id == null || id.trim().isEmpty) return list.first;

  return list.firstWhere((b) => b.id == id, orElse: () => list.first);
});

class BusinessListNotifier extends Notifier<List<BusinessEntity>> {
  StreamSubscription? _sub;

  @override
  List<BusinessEntity> build() {
    final box = ref.read(businessBoxProvider);

    List<BusinessEntity> readAll() {
      final list = box.values
          .whereType<Map>()
          .map((e) => BusinessEntity.fromJson(e))
          .toList();

      list.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return list;
    }

    final initial = readAll();

    _sub?.cancel();
    _sub = box.watch().listen((_) {
      state = readAll();
    });

    ref.onDispose(() => _sub?.cancel());
    return initial;
  }

  BusinessEntity? getById(String id) {
    try {
      return state.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  // ---------------- CRUD ----------------

  Future<void> addBusiness(BusinessEntity b) async {
    final box = ref.read(businessBoxProvider);
    await box.put(b.id, b.toJson());

    final hasLogo =
        (b.logoBase64 ?? '').trim().isNotEmpty || (b.imagePath ?? '').trim().isNotEmpty;

    await ref.read(activityLogProvider.notifier).addLog(
      ActivityLog.create(
        entity: LogEntity.business,
        action: LogAction.create,
        entityId: b.id,
        title: 'Business created',
        message: 'Business "${b.name.isEmpty ? 'Business' : b.name}" added.',
        meta: {
          'name': b.name,
          'phone': b.phone,
          'upiId': b.upiId,
          'hasLogo': hasLogo,
        },
      ),
    );

    // ✅ don’t manually mutate state; Hive watch will refresh state
  }

  Future<void> updateBusiness(BusinessEntity b) async {
    final box = ref.read(businessBoxProvider);
    await box.put(b.id, b.toJson());

    final hasLogo =
        (b.logoBase64 ?? '').trim().isNotEmpty || (b.imagePath ?? '').trim().isNotEmpty;

    await ref.read(activityLogProvider.notifier).addLog(
      ActivityLog.create(
        entity: LogEntity.business,
        action: LogAction.update,
        entityId: b.id,
        title: 'Business updated',
        message:
        'Business "${b.name.isEmpty ? 'Business' : b.name}" updated.',
        meta: {
          'name': b.name,
          'phone': b.phone,
          'upiId': b.upiId,
          'hasLogo': hasLogo,
        },
      ),
    );
  }

  Future<void> deleteBusiness(String id) async {
    final old = getById(id);
    final box = ref.read(businessBoxProvider);

    await box.delete(id);

    await ref.read(activityLogProvider.notifier).addLog(
      ActivityLog.create(
        entity: LogEntity.business,
        action: LogAction.delete,
        entityId: id,
        title: 'Business deleted',
        message: old == null
            ? 'Business deleted.'
            : 'Business "${old.name.isEmpty ? 'Business' : old.name}" deleted.',
        meta: {'name': old?.name ?? ''},
      ),
    );
  }

  // ✅ Aliases (so your UI can call add/update/delete)
  Future<void> add(BusinessEntity b) => addBusiness(b);
  Future<void> update(BusinessEntity b) => updateBusiness(b);
  Future<void> delete(String id) => deleteBusiness(id);
}
