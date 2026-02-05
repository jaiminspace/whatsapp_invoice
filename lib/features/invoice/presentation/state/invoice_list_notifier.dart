import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../data/invoice_local_repo.dart';
import '../../domain/activity_log_model.dart';
import '../../domain/invoice_models.dart';
import 'activity_log_notifier.dart';
import 'business_list_notifier.dart';
import '../../domain/business_entity.dart';

final invoiceRepoProvider = Provider<InvoiceLocalRepo>((ref) {
  final box = Hive.box('invoices');
  return InvoiceLocalRepo(box);
});

final invoiceListProvider = NotifierProvider<InvoiceListNotifier, List<Invoice>>(
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

    final business = ref.read(businessListProvider.notifier).getById(draft.businessId);

    String invoiceNumber;

    if (business?.invoiceNumberMode == InvoiceNumberMode.manual) {
      invoiceNumber = draft.customInvoiceNumber.trim();
    } else {
      final current = business?.invoiceCounter ?? 0;
      final next = current + 1;
      invoiceNumber = 'INV-${next.toString().padLeft(4, '0')}';

      if (business != null) {
        await ref.read(businessListProvider.notifier).updateBusiness(
          business.copyWith(invoiceCounter: next),
        );
      }
    }

    final invoice = Invoice(
      id: id,
      createdAt: draft.invoiceDateTime,
      draft: draft,
      invoiceNumber: invoiceNumber,
      status: PaymentStatus.pending,
    );

    await repo.save(invoice);
    state = List<Invoice>.from(repo.getAll());

    // ✅ LOG
    final cust = invoice.draft.customerName.trim().isEmpty ? 'Customer' : invoice.draft.customerName.trim();
    await ref.read(activityLogProvider.notifier).addLog(
      ActivityLog.create(
        entity: LogEntity.invoice,
        action: LogAction.create,
        entityId: invoice.id,
        title: 'Invoice created',
        message:
        'New invoice "$invoiceNumber" created for $cust. Total: ₹${invoice.total.toStringAsFixed(2)}.',
        meta: {
          'invoiceNumber': invoiceNumber,
          'customerName': invoice.draft.customerName,
          'customerMobile': invoice.draft.customerMobile,
          'total': invoice.total,
          'status': invoice.status.name,
          'businessId': invoice.draft.businessId,
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

    // keep invoice number (unless old business/manual and user typed new one)
    var invoiceNumber = old.invoiceNumber;
    final business = ref.read(businessListProvider.notifier).getById(draft.businessId);

    if (business?.invoiceNumberMode == InvoiceNumberMode.manual) {
      final entered = draft.customInvoiceNumber.trim();
      if (entered.isNotEmpty) invoiceNumber = entered;
    }

    final updated = Invoice(
      id: old.id,
      createdAt: draft.invoiceDateTime, // date can change
      draft: draft,
      invoiceNumber: invoiceNumber,
      status: old.status, // keep paid/unpaid
    );

    await repo.save(updated);
    state = List<Invoice>.from(repo.getAll());

    // ✅ LOG
    final cust = updated.draft.customerName.trim().isEmpty ? 'Customer' : updated.draft.customerName.trim();
    await ref.read(activityLogProvider.notifier).addLog(
      ActivityLog.create(
        entity: LogEntity.invoice,
        action: LogAction.update,
        entityId: updated.id,
        title: 'Invoice updated',
        message:
        'Invoice "$invoiceNumber" updated for $cust. Total: ₹${updated.total.toStringAsFixed(2)}.',
        meta: {
          'invoiceNumber': invoiceNumber,
          'customerName': updated.draft.customerName,
          'customerMobile': updated.draft.customerMobile,
          'total': updated.total,
          'status': updated.status.name,
          'businessId': updated.draft.businessId,
        },
      ),
    );
  }

  // ================= DELETE =================
  Future<void> deleteInvoice(String id) async {
    final old = getById(id);

    await repo.delete(id);
    state = List<Invoice>.from(repo.getAll());

    // ✅ LOG
    final invNo = old?.invoiceNumber ?? 'Invoice';
    final cust = (old?.draft.customerName.trim().isNotEmpty ?? false)
        ? old!.draft.customerName.trim()
        : 'Customer';

    await ref.read(activityLogProvider.notifier).addLog(
      ActivityLog.create(
        entity: LogEntity.invoice,
        action: LogAction.delete,
        entityId: id,
        title: 'Invoice deleted',
        message: old == null
            ? 'Invoice deleted.'
            : 'Invoice "$invNo" deleted for $cust. Total was ₹${old.total.toStringAsFixed(2)}.',
        meta: {
          'invoiceNumber': old?.invoiceNumber ?? '',
          'customerName': old?.draft.customerName ?? '',
          'customerMobile': old?.draft.customerMobile ?? '',
          'total': old?.total ?? 0.0,
          'status': old?.status.name ?? '',
          'businessId': old?.draft.businessId ?? '',
        },
      ),
    );
  }

  // ================= STATUS =================
  Future<void> togglePaymentStatus(Invoice invoice) async {
    final updated = Invoice(
      id: invoice.id,
      createdAt: invoice.createdAt,
      draft: invoice.draft,
      invoiceNumber: invoice.invoiceNumber,
      status: invoice.status == PaymentStatus.paid ? PaymentStatus.pending : PaymentStatus.paid,
    );

    await repo.save(updated);
    state = List<Invoice>.from(repo.getAll());

    // ✅ LOG
    final cust = updated.draft.customerName.trim().isEmpty ? 'Customer' : updated.draft.customerName.trim();
    await ref.read(activityLogProvider.notifier).addLog(
      ActivityLog.create(
        entity: LogEntity.invoice,
        action: LogAction.update,
        entityId: updated.id,
        title: 'Payment status changed',
        message:
        'Invoice "${updated.invoiceNumber}" marked as ${updated.status == PaymentStatus.paid ? 'PAID' : 'UNPAID'} for $cust.',
        meta: {
          'invoiceNumber': updated.invoiceNumber,
          'status': updated.status.name,
          'total': updated.total,
        },
      ),
    );
  }
}
