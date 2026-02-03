import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'package:whatsapp_invoice/features/invoice/data/invoice_local_repo.dart';
import 'package:whatsapp_invoice/features/invoice/domain/invoice_models.dart';

// ✅ Needed for manual/auto invoice number mode
import '../state/business_profile_notifier.dart';
import '../../domain/business_profile.dart';

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

    // Initial load
    final initial = List<Invoice>.from(repo.getAll());

    // Auto-refresh when Hive changes
    final box = Hive.box('invoices');
    _sub?.cancel();
    _sub = box.watch().listen((_) {
      state = List<Invoice>.from(repo.getAll());
    });

    ref.onDispose(() {
      _sub?.cancel();
    });

    return initial;
  }

  // ================= INVOICE NUMBERING =================

  String _nextInvoiceNumber() {
    final box = Hive.box('settings'); // ensure this box is opened in main
    final last = box.get('invoice_counter', defaultValue: 0) as int;
    final next = last + 1;
    box.put('invoice_counter', next);

    return 'INV-${next.toString().padLeft(4, '0')}';
  }

  bool _invoiceNumberExists(String invNo) {
    final n = invNo.trim();
    if (n.isEmpty) return false;
    return state.any((e) => e.invoiceNumber.trim() == n);
  }

  // ================= CRUD =================

  Future<void> addFromDraft(InvoiceDraft draft) async {
    final id = const Uuid().v4();

    final profile = ref.read(businessProfileProvider);
    final isManual = profile.invoiceNumberMode == InvoiceNumberMode.manual;

    String invoiceNumber;

    if (isManual) {
      final manual = draft.customInvoiceNumber.trim();

      // If empty -> fallback to auto
      invoiceNumber = manual.isEmpty ? _nextInvoiceNumber() : manual;

      // If duplicate -> fallback to auto
      if (_invoiceNumberExists(invoiceNumber)) {
        invoiceNumber = _nextInvoiceNumber();
      }
    } else {
      invoiceNumber = _nextInvoiceNumber();
    }

    final invoice = Invoice(
      id: id,
      invoiceNumber: invoiceNumber,
      createdAt: draft.invoiceDateTime,
      draft: draft,
      status: PaymentStatus.pending,
    );

    await repo.save(invoice);

    // Force new list instance (extra safety; Hive watch will also update)
    state = List<Invoice>.from(repo.getAll());
  }

  Future<void> deleteInvoice(String id) async {
    await repo.delete(id);
    state = List<Invoice>.from(repo.getAll());
  }

  Future<void> togglePaymentStatus(Invoice invoice) async {
    final updated = invoice.copyWith(
      status: invoice.status == PaymentStatus.paid
          ? PaymentStatus.pending
          : PaymentStatus.paid,
    );

    await repo.save(updated);
    state = List<Invoice>.from(repo.getAll());
  }

  Future<void> importMany(List<Invoice> invoices) async {
    for (final inv in invoices) {
      await repo.save(inv);
    }
    state = List<Invoice>.from(repo.getAll());
  }
}
