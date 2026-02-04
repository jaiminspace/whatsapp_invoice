import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'package:whatsapp_invoice/features/invoice/data/invoice_local_repo.dart';
import 'package:whatsapp_invoice/features/invoice/domain/invoice_models.dart';

import 'business_list_notifier.dart';
import '../../domain/business_entity.dart';

final invoiceRepoProvider = Provider<InvoiceLocalRepo>((ref) {
  final box = Hive.box('invoices'); // MUST be opened in main()
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

    // initial load
    final initial = List<Invoice>.from(repo.getAll());

    // watch hive updates
    final box = Hive.box('invoices');
    _sub?.cancel();
    _sub = box.watch().listen((_) {
      state = List<Invoice>.from(repo.getAll());
    });

    ref.onDispose(() => _sub?.cancel());

    return initial;
  }

  // ✅ helper
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

    // business lookup
    final BusinessEntity? business =
    ref.read(businessListProvider.notifier).getById(draft.businessId);

    // fallback if business missing
    final InvoiceNumberMode mode =
        business?.invoiceNumberMode ?? InvoiceNumberMode.auto;

    String invoiceNumber;

    if (mode == InvoiceNumberMode.manual) {
      invoiceNumber = draft.customInvoiceNumber.trim();
      if (invoiceNumber.isEmpty) {
        // fallback if user left empty
        invoiceNumber = 'INV-${id.substring(0, 8).toUpperCase()}';
      }
    } else {
      final int next = (business?.invoiceCounter ?? 0) + 1;
      invoiceNumber = 'INV-${next.toString().padLeft(4, '0')}';

      // update counter only if business exists
      if (business != null) {
        await ref
            .read(businessListProvider.notifier)
            .update(business.copyWith(invoiceCounter: next));
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
  }

  // ================= UPDATE (EDIT) =================
  Future<void> updateFromDraft({
    required String invoiceId,
    required InvoiceDraft draft,
  }) async {
    final old = getById(invoiceId);
    if (old == null) return;

    final updated = Invoice(
      id: old.id,
      createdAt: draft.invoiceDateTime, // ✅ correctly updated
      draft: draft,
      invoiceNumber: old.invoiceNumber, // ✅ keep same number
      status: old.status,               // ✅ keep same status
    );

    await repo.save(updated);
    state = List<Invoice>.from(repo.getAll());
  }


  // ================= DELETE =================
  Future<void> deleteInvoice(String id) async {
    await repo.delete(id);
    state = List<Invoice>.from(repo.getAll());
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
  }

  // ================= IMPORT =================
  Future<void> importMany(List<Invoice> invoices) async {
    for (final inv in invoices) {
      await repo.save(inv);
    }
    state = List<Invoice>.from(repo.getAll());
  }
}
