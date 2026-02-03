import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive/hive.dart';

import '../../domain/business_entity.dart';
import '../../data/business_local_repo.dart';

/// --------------------
/// Repository Provider
/// --------------------
final businessRepoProvider = Provider<BusinessLocalRepo>((ref) {
  final box = Hive.box('businesses'); // MUST be opened in main()
  return BusinessLocalRepo(box);
});

/// --------------------
/// Business List Provider
/// --------------------
final businessListProvider =
NotifierProvider<BusinessListNotifier, List<BusinessEntity>>(
  BusinessListNotifier.new,
);

/// --------------------
/// Selected Business ID
/// --------------------
final selectedBusinessIdProvider = StateProvider<String>((ref) => '');

/// --------------------
/// Selected Business (derived)
/// --------------------
final selectedBusinessProvider = Provider<BusinessEntity?>((ref) {
  final list = ref.watch(businessListProvider);
  final selectedId = ref.watch(selectedBusinessIdProvider);

  if (list.isEmpty) return null;

  if (selectedId.trim().isEmpty) {
    return list.first; // default business
  }

  return list.firstWhere(
        (b) => b.id == selectedId,
    orElse: () => list.first,
  );
});

/// --------------------
/// Notifier
/// --------------------
class BusinessListNotifier extends Notifier<List<BusinessEntity>> {
  late final BusinessLocalRepo repo;
  StreamSubscription? _sub;

  @override
  List<BusinessEntity> build() {
    repo = ref.read(businessRepoProvider);

    final initial = List<BusinessEntity>.from(repo.getAll());

    final box = Hive.box('businesses');
    _sub?.cancel();
    _sub = box.watch().listen((_) {
      state = List<BusinessEntity>.from(repo.getAll());
    });

    ref.onDispose(() => _sub?.cancel());

    return initial;
  }

  /// --------------------
  /// Helpers
  /// --------------------
  BusinessEntity getById(String id) {
    if (state.isEmpty) {
      throw StateError('No businesses available. Add a business first.');
    }

    return state.firstWhere(
          (b) => b.id == id,
      orElse: () => state.first,
    );
  }

  /// --------------------
  /// CRUD
  /// --------------------
  Future<void> add(BusinessEntity business) async {
    await repo.save(business);
    state = List<BusinessEntity>.from(repo.getAll());

    // Auto-select first business if none selected yet
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

    // If deleted business was selected → reset selection
    final selected = ref.read(selectedBusinessIdProvider);
    if (selected == id) {
      ref.read(selectedBusinessIdProvider.notifier).state =
      state.isNotEmpty ? state.first.id : '';
    }
  }
}
