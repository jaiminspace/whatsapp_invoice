import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/invoice/domain/invoice_models.dart';

final invoiceDraftProvider =
NotifierProvider<InvoiceDraftNotifier, InvoiceDraft>(
  InvoiceDraftNotifier.new,
);

class InvoiceDraftNotifier extends Notifier<InvoiceDraft> {
  @override
  InvoiceDraft build() => InvoiceDraft.empty();

  void setCustomerName(String v) {
    state = state.copyWith(customerName: v.trim());
  }

  void setCustomerMobile(String v) {
    state = state.copyWith(customerMobile: v.trim());
  }

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

  void updateItemQty(int index, int qty) {
    final updated = [...state.items];
    updated[index] = updated[index].copyWith(qty: qty < 1 ? 1 : qty);
    state = state.copyWith(items: updated);
  }

  void updateItemPrice(int index, double price) {
    final updated = [...state.items];
    updated[index] = updated[index].copyWith(price: price < 0 ? 0 : price);
    state = state.copyWith(items: updated);
  }

  void reset() => state = InvoiceDraft.empty();
}
