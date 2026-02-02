import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'package:whatsapp_invoice/features/invoice/data/invoice_local_repo.dart';
import 'package:whatsapp_invoice/features/invoice/domain/invoice_models.dart';

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

    // ✅ Initial load (NEW list instance)
    final initial = List<Invoice>.from(repo.getAll());

    // ✅ Auto refresh whenever Hive changes
    final box = Hive.box('invoices');

    _sub?.cancel();
    _sub = box.watch().listen((event) {
      // ✅ VERY IMPORTANT: always create a NEW List instance
      state = List<Invoice>.from(repo.getAll());
    });

    ref.onDispose(() {
      _sub?.cancel();
    });

    return initial;
  }

  Future<void> addFromDraft(InvoiceDraft draft) async {
    final id = const Uuid().v4();

    final invoice = Invoice(
      id: id,
      createdAt: DateTime.now(),
      draft: draft,
      status: PaymentStatus.pending,
    );

    await repo.save(invoice);

    // ✅ Extra safety: set state immediately (new list instance)
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
}
