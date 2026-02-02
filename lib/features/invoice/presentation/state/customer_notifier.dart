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

  Future<void> upsertFromInvoice({
    required String name,
    required String mobile,
  }) async {
    final m = mobile.trim();
    if (m.isEmpty) return;

    final c = Customer(
      id: m,
      name: name.trim(),
      mobile: m,
      updatedAt: DateTime.now(),
    );

    await repo.upsert(c);
    state = List<Customer>.from(repo.getAll());
  }

  Future<void> deleteCustomer(String id) async {
    await repo.delete(id);
    state = List<Customer>.from(repo.getAll());
  }
}