import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive/hive.dart';

import '../../domain/activity_log_model.dart';

/// Hive box provider
final activityLogBoxProvider = Provider<Box>((ref) => Hive.box('activity_logs'));

/// Main logs provider (list)
final activityLogProvider =
NotifierProvider<ActivityLogNotifier, List<ActivityLog>>(
  ActivityLogNotifier.new,
);

class ActivityLogNotifier extends Notifier<List<ActivityLog>> {
  StreamSubscription? _sub;

  @override
  List<ActivityLog> build() {
    final box = ref.read(activityLogBoxProvider);

    List<ActivityLog> readAll() {
      final list = box.values
          .whereType<Map>()
          .map((e) => ActivityLog.fromJson(e))
          .toList();

      // newest first
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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

  Future<void> addLog(ActivityLog log) async {
    final box = ref.read(activityLogBoxProvider);

    // ✅ Prevent duplicates in box (same id)
    // If already present, do nothing
    if (box.containsKey(log.id)) return;

    await box.put(log.id, log.toJson());

    // ✅ DO NOT manually do: state = [log, ...state];
    // because box.watch() will refresh state automatically.
  }

  Future<void> clearAll() async {
    final box = ref.read(activityLogBoxProvider);
    await box.clear();
    state = const [];
  }
}

/// ---------------- Filters / Search providers ----------------

/// Entity filter: null = all
final logEntityFilterProvider = StateProvider<LogEntity?>((ref) => null);

/// search text
final logSearchProvider = StateProvider<String>((ref) => '');

/// filtered logs (search + entity filter)
final filteredLogsProvider = Provider<List<ActivityLog>>((ref) {
  final all = ref.watch(activityLogProvider);
  final entity = ref.watch(logEntityFilterProvider);
  final q = ref.watch(logSearchProvider).trim().toLowerCase();

  Iterable<ActivityLog> list = all;

  if (entity != null) {
    list = list.where((e) => e.entity == entity);
  }

  if (q.isNotEmpty) {
    list = list.where((e) {
      final hay =
      ('${e.title} ${e.message} ${e.entity.name} ${e.action.name}')
          .toLowerCase();
      return hay.contains(q);
    });
  }

  return list.toList();
});
