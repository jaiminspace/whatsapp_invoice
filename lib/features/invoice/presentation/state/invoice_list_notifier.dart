import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../data/invoice_local_repo.dart';
import '../../domain/business_entity.dart';
import '../../domain/invoice_models.dart';
import '../../domain/activity_log_model.dart';
import 'activity_log_notifier.dart';
import 'business_list_notifier.dart';

final invoiceRepoProvider = Provider<InvoiceLocalRepo>((ref) {
  final box = Hive.box('invoices');
  return InvoiceLocalRepo(box);
});

final invoiceListProvider =
NotifierProvider<InvoiceListNotifier, List<Invoice>>(
  InvoiceListNotifier.new,
);

class InvoiceListNotifier extends Notifier<List<Invoice>> {
  StreamSubscription? _sub;

  /// ✅ no late init issues
  InvoiceLocalRepo get repo => ref.read(invoiceRepoProvider);

  @override
  List<Invoice> build() {
    List<Invoice> readAll() => List<Invoice>.from(repo.getAll());

    final initial = readAll();

    final box = Hive.box('invoices');
    _sub?.cancel();
    _sub = box.watch().listen((_) {
      state = readAll();
    });

    ref.onDispose(() => _sub?.cancel());
    return initial;
  }

  /// Optional helper if UI needs manual refresh
  void refresh() {
    state = List<Invoice>.from(repo.getAll());
  }

  Invoice? getById(String id) {
    try {
      return state.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  // ---------------- Invoice Number ----------------
  // ✅ since BusinessEntity.invoiceCounter does NOT exist,
  // we generate next invoice number from existing invoices count per business.
  String _nextInvoiceNumber({
    required String businessId,
    required bool isManual,
    required String customInvoiceNumber,
  }) {
    if (isManual) {
      final v = customInvoiceNumber.trim();
      return v.isEmpty ? 'INV-${DateTime.now().millisecondsSinceEpoch}' : v;
    }

    final countForBusiness = state.where((e) => e.draft.businessId == businessId).length;
    final next = countForBusiness + 1;
    return 'INV-${next.toString().padLeft(4, '0')}';
  }

  // ================= ADD =================
  Future<void> addFromDraft(InvoiceDraft draft) async {
    final id = const Uuid().v4();

    final business =
    ref.read(businessListProvider.notifier).getById(draft.businessId);

    final isManual = business?.invoiceNumberMode == InvoiceNumberMode.manual;

    final invoiceNumber = _nextInvoiceNumber(
      businessId: draft.businessId,
      isManual: isManual,
      customInvoiceNumber: draft.customInvoiceNumber,
    );

    // ✅ use draft.status as source of truth
    final invoice = Invoice(
      id: id,
      createdAt: draft.invoiceDateTime,
      draft: draft,
      invoiceNumber: invoiceNumber,
      status: draft.status, // pending = unpaid
    );

    await repo.save(invoice);
    state = List<Invoice>.from(repo.getAll());

    await ref.read(activityLogProvider.notifier).addLog(
      ActivityLog.create(
        entity: LogEntity.invoice,
        action: LogAction.create,
        entityId: invoice.id,
        title: 'Invoice created',
        message:
        'Invoice ${invoice.invoiceNumber} created for ${invoice.draft.customerName.isEmpty ? 'Customer' : invoice.draft.customerName}.',
        meta: {
          'invoiceNumber': invoice.invoiceNumber,
          'customerName': invoice.draft.customerName,
          'customerMobile': invoice.draft.customerMobile,
          'grandTotal': invoice.draft.grandTotal,
          'status': invoice.status.name,
          'createdAt': invoice.createdAt.toIso8601String(),
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

    // ✅ keep invoiceNumber, but update date/draft/status
    final updated = old.copyWith(
      createdAt: draft.invoiceDateTime,
      draft: draft,
      status: draft.status,
    );

    await repo.save(updated);
    state = List<Invoice>.from(repo.getAll());

    await ref.read(activityLogProvider.notifier).addLog(
      ActivityLog.create(
        entity: LogEntity.invoice,
        action: LogAction.update,
        entityId: updated.id,
        title: 'Invoice updated',
        message:
        'Invoice ${updated.invoiceNumber} updated for ${updated.draft.customerName.isEmpty ? 'Customer' : updated.draft.customerName}.',
        meta: {
          'invoiceNumber': updated.invoiceNumber,
          'customerName': updated.draft.customerName,
          'customerMobile': updated.draft.customerMobile,
          'grandTotal': updated.draft.grandTotal,
          'status': updated.status.name,
          'createdAt': updated.createdAt.toIso8601String(),
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

    await ref.read(activityLogProvider.notifier).addLog(
      ActivityLog.create(
        entity: LogEntity.invoice,
        action: LogAction.delete,
        entityId: id,
        title: 'Invoice deleted',
        message: old == null
            ? 'Invoice deleted.'
            : 'Invoice ${old.invoiceNumber} deleted.',
        meta: {
          'invoiceNumber': old?.invoiceNumber ?? '',
          'customerName': old?.draft.customerName ?? '',
          'customerMobile': old?.draft.customerMobile ?? '',
          'grandTotal': old?.draft.grandTotal ?? 0,
          'status': old?.status.name ?? '',
          'createdAt': old?.createdAt.toIso8601String() ?? '',
          'businessId': old?.draft.businessId ?? '',
        },
      ),
    );
  }

  // ================= STATUS TOGGLE =================
  Future<void> togglePaymentStatus(Invoice invoice) async {
    final newStatus = invoice.status == PaymentStatus.paid
        ? PaymentStatus.pending
        : PaymentStatus.paid;

    // ✅ update BOTH invoice.status and draft.status
    final updated = invoice.copyWith(
      status: newStatus,
      draft: invoice.draft.copyWith(status: newStatus),
    );

    await repo.save(updated);
    state = List<Invoice>.from(repo.getAll());

    await ref.read(activityLogProvider.notifier).addLog(
      ActivityLog.create(
        entity: LogEntity.invoice,
        action: LogAction.update,
        entityId: updated.id,
        title: 'Invoice payment updated',
        message:
        'Invoice ${updated.invoiceNumber} marked as ${updated.status.name.toUpperCase()}.',
        meta: {
          'invoiceNumber': updated.invoiceNumber,
          'status': updated.status.name,
          'grandTotal': updated.draft.grandTotal,
          'customerName': updated.draft.customerName,
        },
      ),
    );
  }

  // ================= IMPORT =================
  Future<void> importMany(List<Invoice> invoices) async {
    for (final inv in invoices) {
      await repo.save(inv);
    }
    state = List<Invoice>.from(repo.getAll());
  }
}
