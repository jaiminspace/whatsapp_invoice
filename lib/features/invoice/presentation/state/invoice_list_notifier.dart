import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../data/invoice_local_repo.dart';
import '../../domain/invoice_models.dart';

import '../../domain/activity_log_model.dart';
import 'activity_log_notifier.dart';

import 'business_list_notifier.dart';
import '../../domain/business_entity.dart';

final invoiceRepoProvider = Provider<InvoiceLocalRepo>((ref) {
  final box = Hive.box('invoices');
  return InvoiceLocalRepo(box);
});

final invoiceListProvider =
NotifierProvider<InvoiceListNotifier, List<Invoice>>(
  InvoiceListNotifier.new,
);

class InvoiceListNotifier extends Notifier<List<Invoice>> {
  late final InvoiceLocalRepo repo;
  StreamSubscription? _sub;

  @override
  List<Invoice> build() {
    repo = ref.read(invoiceRepoProvider);

    final initial = List<Invoice>.from(repo.getAll());

    final box = Hive.box('invoices');
    _sub?.cancel();
    _sub = box.watch().listen((_) {
      state = List<Invoice>.from(repo.getAll());
    });

    ref.onDispose(() => _sub?.cancel());
    return initial;
  }

  Invoice? getById(String id) {
    try {
      return state.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  // ================= ADD =================
  Future<void> addFromDraft(InvoiceDraft draft) async {
    final id = const Uuid().v4();

    final business =
    ref.read(businessListProvider.notifier).getById(draft.businessId);

    String invoiceNumber;

    if (business?.invoiceNumberMode == InvoiceNumberMode.manual) {
      invoiceNumber = draft.customInvoiceNumber.trim();
    } else {
      final next = (business?.invoiceCounter ?? 0) + 1;
      invoiceNumber = 'INV-${next.toString().padLeft(4, '0')}';

      if (business != null) {
        await ref
            .read(businessListProvider.notifier)
            .updateBusiness(business.copyWith(invoiceCounter: next));
      }
    }

    final invoice = Invoice(
      id: id,
      createdAt: draft.invoiceDateTime,
      draft: draft,
      invoiceNumber: invoiceNumber,
      status: draft.status, // ✅ NEW: use selected invoice type
    );

    await repo.save(invoice);
    state = List.from(repo.getAll());

    await ref.read(activityLogProvider.notifier).addLog(
      ActivityLog.create(
        entity: LogEntity.invoice,
        action: LogAction.create,
        entityId: invoice.id,
        title: 'Invoice created',
        message:
        'New invoice "$invoiceNumber" created for "${draft.customerName.isEmpty ? 'Customer' : draft.customerName}".',
        meta: {
          'invoiceNumber': invoiceNumber,
          'total': invoice.total,
          'status': invoice.status.name,
          'customerName': draft.customerName,
        },
      ),
    );
  }

  // ================= UPDATE (EDIT) =================
  Future<void> updateFromDraft({
    required String invoiceId,
    required InvoiceDraft draft,
  }) async {
    final old = getById(invoiceId);
    if (old == null) return;

    final updated = old.copyWith(
      draft: draft,
      createdAt: draft.invoiceDateTime,
      status: draft.status, // ✅ NEW: update status from UI
    );

    await repo.save(updated);
    state = List.from(repo.getAll());

    await ref.read(activityLogProvider.notifier).addLog(
      ActivityLog.create(
        entity: LogEntity.invoice,
        action: LogAction.update,
        entityId: updated.id,
        title: 'Invoice updated',
        message:
        'Invoice "${updated.invoiceNumber}" updated for "${draft.customerName.isEmpty ? 'Customer' : draft.customerName}".',
        meta: {
          'invoiceNumber': updated.invoiceNumber,
          'total': updated.total,
          'status': updated.status.name,
        },
      ),
    );
  }

  // ================= DELETE =================
  Future<void> deleteInvoice(String id) async {
    final old = getById(id);

    await repo.delete(id);
    state = List<Invoice>.from(repo.getAll());

    await ref.read(activityLogProvider.notifier).addLog(
      ActivityLog.create(
        entity: LogEntity.invoice,
        action: LogAction.delete,
        entityId: id,
        title: 'Invoice deleted',
        message: old == null
            ? 'Invoice deleted.'
            : 'Invoice "${old.invoiceNumber}" deleted.',
        meta: {
          'invoiceNumber': old?.invoiceNumber ?? '',
          'total': old?.total ?? 0.0,
        },
      ),
    );
  }

  // ================= STATUS =================
  Future<void> togglePaymentStatus(Invoice invoice) async {
    final updated = invoice.copyWith(
      status: invoice.status == PaymentStatus.paid
          ? PaymentStatus.pending
          : PaymentStatus.paid,
    );

    await repo.save(updated);
    state = List<Invoice>.from(repo.getAll());

    await ref.read(activityLogProvider.notifier).addLog(
      ActivityLog.create(
        entity: LogEntity.invoice,
        action: LogAction.update,
        entityId: invoice.id,
        title: 'Payment status changed',
        message:
        'Invoice "${updated.invoiceNumber}" marked as ${updated.status == PaymentStatus.paid ? 'PAID' : 'UNPAID'}.',
        meta: {
          'invoiceNumber': updated.invoiceNumber,
          'status': updated.status.name,
        },
      ),
    );
  }

  Future<void> refresh() async {
    // force pull latest from Hive
    state = List<Invoice>.from(repo.getAll());
  }
}
