import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/invoice_models.dart';

final invoiceDraftProvider =
NotifierProvider<InvoiceDraftNotifier, InvoiceDraft>(
  InvoiceDraftNotifier.new,
);

class InvoiceDraftNotifier extends Notifier<InvoiceDraft> {
  @override
  InvoiceDraft build() => InvoiceDraft.initial();

  void reset() => state = InvoiceDraft.initial();

  void setCustomerName(String v) => state = state.copyWith(customerName: v);
  void setCustomerMobile(String v) => state = state.copyWith(customerMobile: v);

  // ✅ NEW
  void setCustomInvoiceNumber(String v) =>
      state = state.copyWith(customInvoiceNumber: v);

  void addItem() {
    final updated = [...state.items, const InvoiceItem(name: '', qty: 1, price: 0)];
    state = state.copyWith(items: updated);
  }

  void removeItem(int index) {
    final updated = [...state.items]..removeAt(index);
    state = state.copyWith(items: updated);
  }

  void updateItemName(int index, String v) {
    final updated = [...state.items];
    updated[index] = updated[index].copyWith(name: v);
    state = state.copyWith(items: updated);
  }

  void updateItemQty(int index, int v) {
    final updated = [...state.items];
    updated[index] = updated[index].copyWith(qty: v);
    state = state.copyWith(items: updated);
  }

  void updateItemPrice(int index, double v) {
    final updated = [...state.items];
    updated[index] = updated[index].copyWith(price: v);
    state = state.copyWith(items: updated);
  }
}
