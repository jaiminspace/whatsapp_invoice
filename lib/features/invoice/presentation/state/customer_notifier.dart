import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'package:whatsapp_invoice/features/invoice/data/customer_local_repo.dart';
import 'package:whatsapp_invoice/features/invoice/domain/customer_model.dart';

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

    final box = Hive.box('customers');

    _sub?.cancel();
    _sub = box.watch().listen((_) {
      state = List<Customer>.from(repo.getAll());
    });

    ref.onDispose(() => _sub?.cancel());

    return List<Customer>.from(repo.getAll());
  }

  Customer? getById(String id) {
    try {
      return state.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Used from invoice save flow (id = mobile)
  Future<void> upsertFromInvoice({
    required String name,
    required String mobile,
  }) async {
    final m = mobile.trim();
    if (m.isEmpty) return;

    final old = getById(m);

    final c = Customer(
      id: m,
      name: name.trim(),
      mobile: m,
      address: old?.address,
      imagePath: old?.imagePath,
      createdAt: old?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await repo.upsert(c);
    state = List<Customer>.from(repo.getAll());
  }

  Future<void> addCustomer({
    required String name,
    required String mobile,
    required String address,
    String? imagePath,
  }) async {
    final m = mobile.trim();
    final id = m.isNotEmpty
        ? m
        : DateTime.now().microsecondsSinceEpoch.toString();

    final now = DateTime.now();

    final customer = Customer(
      id: id,
      name: name.trim(),
      mobile: m,
      address: address.trim().isEmpty ? null : address.trim(),
      imagePath: (imagePath ?? '').trim().isEmpty ? null : imagePath!.trim(),
      createdAt: now,
      updatedAt: now,
    );

    await repo.upsert(customer);
    state = List<Customer>.from(repo.getAll());
  }

  Future<void> updateCustomer({
    required String id,
    required String name,
    required String mobile,
    required String address,
    String? imagePath,
  }) async {
    final old = getById(id);
    if (old == null) return;

    final m = mobile.trim();
    final newId = m.isNotEmpty ? m : old.id;

    // if id changes (mobile changed), delete old key first
    if (newId != old.id) {
      await repo.delete(old.id);
    }

    final updated = Customer(
      id: newId,
      name: name.trim(),
      mobile: m,
      address: address.trim().isEmpty ? null : address.trim(),
      imagePath: (imagePath ?? old.imagePath ?? '').trim().isEmpty
          ? null
          : (imagePath ?? old.imagePath)!.trim(),
      createdAt: old.createdAt,
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
