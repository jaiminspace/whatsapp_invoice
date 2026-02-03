import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/customer_local_repo.dart';
import '../../domain/customer_model.dart';

final customerRepoProvider = Provider<CustomerLocalRepo>((ref) {
  final box = Hive.box('customers'); // MUST be opened in main()
  return CustomerLocalRepo(box);
});

final customerListProvider =
NotifierProvider<CustomerListNotifier, List<Customer>>(
  CustomerListNotifier.new,
);

class CustomerListNotifier extends Notifier<List<Customer>> {
  late final CustomerLocalRepo repo;
  StreamSubscription? _sub;

  @override
  List<Customer> build() {
    repo = ref.read(customerRepoProvider);

    final box = Hive.box('customers');

    final initial = List<Customer>.from(repo.getAll());

    _sub?.cancel();
    _sub = box.watch().listen((_) {
      state = List<Customer>.from(repo.getAll());
    });

    ref.onDispose(() => _sub?.cancel());

    return initial;
  }

  /// Upsert from invoice (mobile is the id)
  Future<void> upsertFromInvoice({
    required String name,
    required String mobile,
  }) async {
    final m = mobile.trim();
    if (m.isEmpty) return;

    final customer = Customer(
      id: m, // ✅ mobile as unique id
      name: name.trim(),
      mobile: m,
      updatedAt: DateTime.now(),
    );

    await repo.upsert(customer);
    state = List<Customer>.from(repo.getAll());
  }

  /// Add customer manually
  Future<void> addCustomer({
    required String name,
    required String mobile,
  }) async {
    final m = mobile.trim();
    if (m.isEmpty) return;

    final customer = Customer(
      id: m,
      name: name.trim(),
      mobile: m,
      updatedAt: DateTime.now(),
    );

    // ✅ use upsert (repo.save doesn't exist in your repo)
    await repo.upsert(customer);
    state = List<Customer>.from(repo.getAll());
  }

  /// Update customer
  Future<void> updateCustomer({
    required String id,
    required String name,
    required String mobile,
  }) async {
    final m = mobile.trim();
    if (m.isEmpty) return;

    // ✅ avoid copyWith(mobile: ...) because your copyWith may not support it
    final updated = Customer(
      id: id, // keep same id
      name: name.trim(),
      mobile: m,
      updatedAt: DateTime.now(),
    );

    await repo.upsert(updated);
    state = List<Customer>.from(repo.getAll());
  }

  Future<void> deleteCustomer(String id) async {
    await repo.delete(id);
    state = List<Customer>.from(repo.getAll());
  }
}
