import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/invoice_models.dart';

final invoiceDraftProvider =
NotifierProvider<InvoiceDraftNotifier, InvoiceDraft>(
  InvoiceDraftNotifier.new,
);

class InvoiceDraftNotifier extends Notifier<InvoiceDraft> {
  @override
  InvoiceDraft build() => InvoiceDraft.empty();

  void reset() => state = InvoiceDraft.empty();

  void setCustomerName(String v) =>
      state = state.copyWith(customerName: v.trim());

  void setCustomerMobile(String v) =>
      state = state.copyWith(customerMobile: v.trim());

  void setCustomInvoiceNumber(String v) =>
      state = state.copyWith(customInvoiceNumber: v.trim());

  void setInvoiceDateTime(DateTime dt) =>
      state = state.copyWith(invoiceDateTime: dt);

  // ✅ NEW: business id support
  void setBusinessId(String id) => state = state.copyWith(businessId: id);

  void addItem() {
    final updated = [
      ...state.items,
      const InvoiceItem(name: '', qty: 1, price: 0),
    ];
    state = state.copyWith(items: updated);
  }

  void removeItem(int index) {
    final updated = [...state.items];
    if (index < 0 || index >= updated.length) return;
    updated.removeAt(index);
    state = state.copyWith(items: updated);
  }

  void updateItemName(int index, String v) {
    final updated = [...state.items];
    if (index < 0 || index >= updated.length) return;
    updated[index] = updated[index].copyWith(name: v.trim());
    state = state.copyWith(items: updated);
  }

  void updateItemQty(int index, int v) {
    final updated = [...state.items];
    if (index < 0 || index >= updated.length) return;
    final safeQty = v < 1 ? 1 : v;
    updated[index] = updated[index].copyWith(qty: safeQty);
    state = state.copyWith(items: updated);
  }

  void updateItemPrice(int index, double v) {
    final updated = [...state.items];
    if (index < 0 || index >= updated.length) return;
    final safePrice = v < 0 ? 0.0 : v;
    updated[index] = updated[index].copyWith(price: safePrice);
    state = state.copyWith(items: updated);
  }
}
