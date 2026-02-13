import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'package:snap_invoice/features/invoice/data/customer_local_repo.dart';
import 'package:snap_invoice/features/invoice/domain/customer_model.dart';

// ✅ logs (same pattern as CatalogNotifier)
import '../../domain/activity_log_model.dart';
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

  String _safeName(String raw) {
    final n = raw.trim();
    return n.isEmpty ? 'Customer' : n;
  }

  /// Unified add/update used by CustomersPage bottomsheet.
  ///
  /// imagePath rule:
  /// - null  => KEEP old image (edit case)
  /// - ''    => CLEAR image
  /// - non-empty => SET image
  Future<void> upsertCustomer({
    Customer? editing,
    required String name,
    required String mobile,
    String? address,
    String? imagePath,
  }) async {
    final now = DateTime.now();
    final trimmedName = name.trim();
    final m = mobile.trim();

    final old = editing;
    final oldId = old?.id;

    final newId = m.isNotEmpty
        ? m
        : (oldId ?? DateTime.now().microsecondsSinceEpoch.toString());

    // If editing and id changes, delete old key
    if (old != null && oldId != null && newId != oldId) {
      await repo.delete(oldId);
    }

    final resolvedAddress =
    (address ?? '').trim().isEmpty ? null : address!.trim();

    String? resolvedImagePath;
    if (old == null) {
      // add
      resolvedImagePath =
      (imagePath ?? '').trim().isEmpty ? null : imagePath!.trim();
    } else {
      // edit
      if (imagePath == null) {
        resolvedImagePath = old.imagePath; // keep
      } else {
        final t = imagePath.trim();
        resolvedImagePath = t.isEmpty ? null : t; // '' clears, non-empty sets
      }
    }

    final customer = Customer(
      id: newId,
      name: trimmedName,
      mobile: m,
      address: resolvedAddress,
      imagePath: resolvedImagePath,
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
    );

    final isEdit = old != null;

    await repo.upsert(customer);
    state = List<Customer>.from(repo.getAll());

    // ✅ LOGS
    if (!isEdit) {
      await ref.read(activityLogProvider.notifier).addLog(
        ActivityLog.create(
          entity: LogEntity.customer,
          action: LogAction.create,
          entityId: customer.id,
          title: 'Customer created',
          message:
          'New customer "${_safeName(customer.name)}" added (Phone: ${customer.mobile}).',
          meta: {
            'name': customer.name,
            'mobile': customer.mobile,
            'address': customer.address ?? '',
            'imagePath': customer.imagePath ?? '',
          },
        ),
      );
    } else {
      final oldName = _safeName(old!.name);
      final newName = _safeName(customer.name);

      await ref.read(activityLogProvider.notifier).addLog(
        ActivityLog.create(
          entity: LogEntity.customer,
          action: LogAction.update,
          entityId: customer.id,
          title: 'Customer updated',
          message: oldName == newName
              ? 'Customer "$newName" updated (Phone: ${customer.mobile}).'
              : 'Customer "$oldName" updated to "$newName" (Phone: ${customer.mobile}).',
          meta: {
            'name': customer.name,
            'mobile': customer.mobile,
            'address': customer.address ?? '',
            'imagePath': customer.imagePath ?? '',
          },
        ),
      );
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

    final wasNew = old == null;

    await repo.upsert(c);
    state = List<Customer>.from(repo.getAll());

    // ✅ Optional logs (only if NEW, or name changed)
    if (wasNew) {
      await ref.read(activityLogProvider.notifier).addLog(
        ActivityLog.create(
          entity: LogEntity.customer,
          action: LogAction.create,
          entityId: c.id,
          title: 'Customer created',
          message:
          'New customer "${_safeName(c.name)}" added from invoice (Phone: ${c.mobile}).',
          meta: {
            'name': c.name,
            'mobile': c.mobile,
            'address': c.address ?? '',
            'imagePath': c.imagePath ?? '',
            'source': 'invoice',
          },
        ),
      );
    } else if ((old?.name ?? '').trim() != c.name.trim() &&
        c.name.trim().isNotEmpty) {
      await ref.read(activityLogProvider.notifier).addLog(
        ActivityLog.create(
          entity: LogEntity.customer,
          action: LogAction.update,
          entityId: c.id,
          title: 'Customer updated',
          message:
          'Customer "${_safeName(old?.name ?? '')}" updated from invoice to "${_safeName(c.name)}".',
          meta: {
            'name': c.name,
            'mobile': c.mobile,
            'address': c.address ?? '',
            'imagePath': c.imagePath ?? '',
            'source': 'invoice',
          },
        ),
      );
    }
  }

  Future<void> addCustomer({
    required String name,
    required String mobile,
    String? address,
    String? imagePath,
  }) async {
    await upsertCustomer(
      editing: null,
      name: name,
      mobile: mobile,
      address: address,
      imagePath: imagePath,
    );
  }

  Future<void> updateCustomer({
    required String id,
    required String name,
    required String mobile,
    String? address,
    String? imagePath,
  }) async {
    final old = getById(id);
    if (old == null) return;

    await upsertCustomer(
      editing: old,
      name: name,
      mobile: mobile,
      address: address,
      imagePath: imagePath,
    );
  }

  Future<void> deleteCustomer(String id) async {
    final old = getById(id);

    await repo.delete(id);
    state = List<Customer>.from(repo.getAll());

    // ✅ LOG
    await ref.read(activityLogProvider.notifier).addLog(
      ActivityLog.create(
        entity: LogEntity.customer,
        action: LogAction.delete,
        entityId: id,
        title: 'Customer deleted',
        message: old == null
            ? 'Customer deleted.'
            : 'Customer "${_safeName(old.name)}" deleted (Phone: ${old.mobile}).',
        meta: {
          'name': old?.name ?? '',
          'mobile': old?.mobile ?? '',
          'address': old?.address ?? '',
          'imagePath': old?.imagePath ?? '',
        },
      ),
    );
  }
}
