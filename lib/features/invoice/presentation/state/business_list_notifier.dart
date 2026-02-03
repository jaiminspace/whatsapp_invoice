import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../domain/business_models.dart';
import '../../data/business_local_repo.dart';

final businessRepoProvider = Provider<BusinessLocalRepo>((ref) {
  final box = Hive.box('businesses');
  return BusinessLocalRepo(box);
});

final businessListProvider =
NotifierProvider<BusinessListNotifier, List<Business>>(
  BusinessListNotifier.new,
);

final selectedBusinessIdProvider = StateProvider<String>((ref) => '');

final selectedBusinessProvider = Provider<Business?>((ref) {
  final list = ref.watch(businessListProvider);
  final selectedId = ref.watch(selectedBusinessIdProvider);
  if (list.isEmpty) return null;
  if (selectedId.trim().isEmpty) return list.first; // default
  return list.firstWhere(
        (b) => b.id == selectedId,
    orElse: () => list.first,
  );
});

class BusinessListNotifier extends Notifier<List<Business>> {
  late final BusinessLocalRepo repo;
  StreamSubscription? _sub;

  @override
  List<Business> build() {
    repo = ref.read(businessRepoProvider);
    final initial = List<Business>.from(repo.getAll());

    final box = Hive.box('businesses');
    _sub?.cancel();
    _sub = box.watch().listen((_) {
      state = List<Business>.from(repo.getAll());
    });

    ref.onDispose(() => _sub?.cancel());
    return initial;
  }

  Future<void> addBusiness({
    required String name,
    required String phone,
    required String address,
    required String upiId,
  }) async {
    final id = const Uuid().v4();
    final b = Business(
      id: id,
      name: name.trim(),
      phone: phone.trim(),
      address: address.trim(),
      upiId: upiId.trim(),
    );
    await repo.save(b);
    state = List<Business>.from(repo.getAll());

    // auto-select first business if none selected yet
    final selected = ref.read(selectedBusinessIdProvider);
    if (selected.trim().isEmpty) {
      ref.read(selectedBusinessIdProvider.notifier).state = id;
    }
  }

  Future<void> updateBusiness(Business b) async {
    await repo.save(b);
    state = List<Business>.from(repo.getAll());
  }

  Future<void> deleteBusiness(String id) async {
    await repo.delete(id);
    state = List<Business>.from(repo.getAll());
  }
}
