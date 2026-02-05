import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../domain/activity_log_model.dart';
import '../../domain/customer_model.dart';
import '../../data/customer_local_repo.dart';
import 'activity_log_notifier.dart';

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

  // ================= CREATE / UPDATE =================

  /// Used from Create Invoice flow (id = mobile). Logs create/update properly.
  Future<void> upsertFromInvoice({
    required String name,
    required String mobile,
    String? address,
  }) async {
    final m = mobile.trim();
    if (m.isEmpty) return;

    final existing = getById(m);
    final isCreate = existing == null;

    final c = Customer(
      id: m,
      name: name.trim(),
      mobile: m,
      address: (address ?? existing?.address ?? '').trim(),
      updatedAt: DateTime.now(),
    );

    await repo.upsert(c);
    state = List<Customer>.from(repo.getAll());

    await ref.read(activityLogProvider.notifier).addLog(
      ActivityLog.create(
        entity: LogEntity.customer,
        action: isCreate ? LogAction.create : LogAction.update,
        entityId: c.id,
        title: isCreate ? 'Customer created' : 'Customer updated',
        message: isCreate
            ? 'Customer "${c.name.isEmpty ? 'Customer' : c.name}" added from invoice.'
            : 'Customer "${c.name.isEmpty ? 'Customer' : c.name}" updated from invoice.',
        meta: {
          'name': c.name,
          'mobile': c.mobile,
          'address': c.address,
          'source': 'invoice',
        },
      ),
    );
  }

  /// Manual add from Customers page (id = mobile).
  Future<void> addCustomer({
    required String name,
    required String mobile,
    String address = '',
  }) async {
    final m = mobile.trim();
    if (m.isEmpty) return;

    final exists = getById(m) != null;
    if (exists) {
      // If already exists, treat as update to avoid duplicates.
      await updateCustomer(id: m, name: name, mobile: m, address: address);
      return;
    }

    final c = Customer(
      id: m,
      name: name.trim(),
      mobile: m,
      address: address.trim(),
      updatedAt: DateTime.now(),
    );

    await repo.upsert(c);
    state = List<Customer>.from(repo.getAll());

    await ref.read(activityLogProvider.notifier).addLog(
      ActivityLog.create(
        entity: LogEntity.customer,
        action: LogAction.create,
        entityId: c.id,
        title: 'Customer created',
        message: 'Customer "${c.name.isEmpty ? 'Customer' : c.name}" added.',
        meta: {'name': c.name, 'mobile': c.mobile, 'address': c.address},
      ),
    );
  }

  Future<void> updateCustomer({
    required String id,
    required String name,
    required String mobile,
    String address = '',
  }) async {
    final old = getById(id);
    if (old == null) return;

    final updated = old.copyWith(
      name: name.trim(),
      mobile: mobile.trim(),
      address: address.trim(),
      updatedAt: DateTime.now(),
    );

    await repo.upsert(updated);
    state = List<Customer>.from(repo.getAll());

    await ref.read(activityLogProvider.notifier).addLog(
      ActivityLog.create(
        entity: LogEntity.customer,
        action: LogAction.update,
        entityId: updated.id,
        title: 'Customer updated',
        message:
        'Customer "${updated.name.isEmpty ? 'Customer' : updated.name}" updated.',
        meta: {
          'name': updated.name,
          'mobile': updated.mobile,
          'address': updated.address,
        },
      ),
    );
  }

  // ================= DELETE =================

  Future<void> deleteCustomer(String id) async {
    final old = getById(id);

    await repo.delete(id);
    state = List<Customer>.from(repo.getAll());

    await ref.read(activityLogProvider.notifier).addLog(
      ActivityLog.create(
        entity: LogEntity.customer,
        action: LogAction.delete,
        entityId: id,
        title: 'Customer deleted',
        message: old == null
            ? 'Customer deleted.'
            : 'Customer "${old.name.isEmpty ? 'Customer' : old.name}" deleted.',
        meta: {'name': old?.name ?? '', 'mobile': old?.mobile ?? ''},
      ),
    );
  }
}
