import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/invoice_local_repo.dart';
import '../../domain/invoice_models.dart';

const String kInvoicesBoxName = 'invoices';

final invoiceRepoProvider = Provider<InvoiceLocalRepo>((ref) {
  final box = Hive.box(kInvoicesBoxName);
  return InvoiceLocalRepo(box);
});

final invoiceListProvider =
NotifierProvider<InvoiceListNotifier, List<Invoice>>(InvoiceListNotifier.new);

class InvoiceListNotifier extends Notifier<List<Invoice>> {
  StreamSubscription? _sub;

  InvoiceLocalRepo get _repo => ref.read(invoiceRepoProvider);

  @override
  List<Invoice> build() {
    // ✅ initial load
    final initial = List<Invoice>.from(_repo.getAll());

    // ✅ start watching once; safe even if build runs again
    _sub?.cancel();
    final box = Hive.box(kInvoicesBoxName);
    _sub = box.watch().listen((_) {
      state = List<Invoice>.from(_repo.getAll());
    });

    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
    });

    return initial;
  }

  // -------------------------
  // CRUD
  // -------------------------

  Future<void> delete(String invoiceId) async {
    await _repo.delete(invoiceId);
  }

  Invoice? getById(String id) {
    try {
      return state.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  // -------------------------
  // Status toggle (keeps draft/status in sync)
  // -------------------------
  Future<void> togglePaymentStatus(String invoiceId) async {
    final old = getById(invoiceId);
    if (old == null) return;

    final newStatus = old.status == PaymentStatus.paid
        ? PaymentStatus.pending
        : PaymentStatus.paid;

    final updated = old.copyWith(
      status: newStatus,
      draft: old.draft.copyWith(status: newStatus),
    );

    await _repo.save(updated);
  }

  // -------------------------
  // Draft-based
  // -------------------------

  Future<void> addFromDraft(InvoiceDraft draft) async {
    final id = _newId();
    final invoiceNumber = _resolveInvoiceNumberForNewInvoice(draft);

    final invoice = Invoice(
      id: id,
      createdAt: draft.invoiceDateTime,
      draft: draft,
      invoiceNumber: invoiceNumber, // ✅ required
      status: draft.status,
    );

    await _repo.save(invoice);
  }

  Future<void> updateFromDraft({
    required String invoiceId,
    required InvoiceDraft draft,
  }) async {
    final old = getById(invoiceId);
    if (old == null) return;

    // ✅ keep old.invoiceNumber unless you want to allow changing it
    final updated = old.copyWith(
      createdAt: draft.invoiceDateTime,
      draft: draft,
      status: draft.status,
      // invoiceNumber: old.invoiceNumber,
    );

    await _repo.save(updated);
  }

  // -------------------------
  // Helpers
  // -------------------------

  String _newId() => 'inv_${DateTime.now().microsecondsSinceEpoch}';

  String _resolveInvoiceNumberForNewInvoice(InvoiceDraft draft) {
    // ✅ manual number if user entered
    final manual = draft.customInvoiceNumber.trim();
    if (manual.isNotEmpty) return manual;

    // ✅ auto per business
    final bizId = draft.businessId.trim();
    final next = _nextAutoInvoiceNumberForBusiness(bizId);
    return next;
  }

  String _nextAutoInvoiceNumberForBusiness(String businessId) {
    final bizKey = businessId.trim();

    final count = state.where((inv) {
      return inv.draft.businessId.trim() == bizKey;
    }).length;

    final next = count + 1;
    return 'INV-${next.toString().padLeft(4, '0')}';
  }
}
