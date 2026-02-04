import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive/hive.dart';

import '../../data/business_local_repo.dart';
import '../../domain/business_entity.dart';

final businessRepoProvider = Provider<BusinessLocalRepo>((ref) {
  final box = Hive.box('businesses'); // MUST be opened in main()
  return BusinessLocalRepo(box);
});

final businessListProvider =
NotifierProvider<BusinessListNotifier, List<BusinessEntity>>(
  BusinessListNotifier.new,
);

final selectedBusinessIdProvider = StateProvider<String>((ref) => '');

final selectedBusinessProvider = Provider<BusinessEntity?>((ref) {
  final list = ref.watch(businessListProvider);
  final selectedId = ref.watch(selectedBusinessIdProvider);

  if (list.isEmpty) return null;
  if (selectedId.trim().isEmpty) return list.first;

  return list.firstWhere(
        (b) => b.id == selectedId,
    orElse: () => list.first,
  );
});

class BusinessListNotifier extends Notifier<List<BusinessEntity>> {
  late final BusinessLocalRepo repo;
  StreamSubscription? _sub;

  @override
  List<BusinessEntity> build() {
    repo = ref.read(businessRepoProvider);

    final box = Hive.box('businesses');

    // initial
    final initial = List<BusinessEntity>.from(repo.getAll());

    // auto refresh on Hive changes
    _sub?.cancel();
    _sub = box.watch().listen((_) {
      state = List<BusinessEntity>.from(repo.getAll());
    });

    ref.onDispose(() => _sub?.cancel());

    return initial;
  }

  BusinessEntity? getById(String id) {
    try {
      return state.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> add(BusinessEntity business) async {
    await repo.save(business);
    state = List<BusinessEntity>.from(repo.getAll());

    final selected = ref.read(selectedBusinessIdProvider);
    if (selected.trim().isEmpty) {
      ref.read(selectedBusinessIdProvider.notifier).state = business.id;
    }
  }

  Future<void> update(BusinessEntity business) async {
    await repo.save(business);
    state = List<BusinessEntity>.from(repo.getAll());
  }

  Future<void> delete(String id) async {
    await repo.delete(id);
    state = List<BusinessEntity>.from(repo.getAll());

    final selected = ref.read(selectedBusinessIdProvider);
    if (selected == id) {
      ref.read(selectedBusinessIdProvider.notifier).state =
      state.isNotEmpty ? state.first.id : '';
    }
  }
}
