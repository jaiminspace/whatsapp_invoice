import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/customer_local_repo.dart';
import '../../domain/customer_model.dart';

final customerRepoProvider = Provider<CustomerLocalRepo>((ref) {
  final box = Hive.box('customers');
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

    // Refresh when hive box changes
    final box = Hive.box('customers');
    _sub?.cancel();
    _sub = box.watch().listen((_) {
      state = List<Customer>.from(repo.getAll());
    });

    ref.onDispose(() => _sub?.cancel());

    return List<Customer>.from(repo.getAll());
  }

  Future<void> upsertFromInvoice({
    required String name,
    required String mobile,
  }) async {
    final m = mobile.trim();
    if (m.isEmpty) return;

    final customer = Customer(
      id: m,
      name: name.trim(),
      mobile: m,
      address: '', // invoice flow doesn’t collect address
      updatedAt: DateTime.now(),
    );

    await repo.upsert(customer);
    state = List<Customer>.from(repo.getAll());
  }

  Future<void> addCustomer({
    required String name,
    required String mobile,
    String address = '',
  }) async {
    final m = mobile.trim();
    if (m.isEmpty) return;

    final customer = Customer(
      id: m,
      name: name.trim(),
      mobile: m,
      address: address.trim(),
      updatedAt: DateTime.now(),
    );

    await repo.upsert(customer); // ✅ upsert = add if not exists
    state = List<Customer>.from(repo.getAll());
  }

  Future<void> updateCustomer({
    required String id,
    required String name,
    required String mobile,
    String address = '',
  }) async {
    // In our app, id==mobile. If user changes mobile, we "move" record.
    final newMobile = mobile.trim();
    if (newMobile.isEmpty) return;

    final existing = state.where((e) => e.id == id).toList();
    if (existing.isEmpty) return;

    final updated = Customer(
      id: newMobile,
      name: name.trim(),
      mobile: newMobile,
      address: address.trim(),
      updatedAt: DateTime.now(),
    );

    if (id != newMobile) {
      // delete old key, save new key
      await repo.delete(id);
    }

    await repo.upsert(updated);
    state = List<Customer>.from(repo.getAll());
  }

  Future<void> deleteCustomer(String id) async {
    await repo.delete(id);
    state = List<Customer>.from(repo.getAll());
  }
}
