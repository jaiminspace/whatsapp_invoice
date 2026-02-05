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

  // ✅ NEW: load invoice into draft for editing
  void loadFromInvoice(Invoice invoice) {
    state = invoice.draft.copyWith(
      invoiceDateTime: invoice.createdAt,
      items: invoice.draft.items
          .map((e) => e.copyWith(name: e.name.trim()))
          .toList(),
    );
  }


  void setCustomerName(String v) => state = state.copyWith(customerName: v.trim());
  void setCustomerMobile(String v) => state = state.copyWith(customerMobile: v.trim());
  void setCustomInvoiceNumber(String v) => state = state.copyWith(customInvoiceNumber: v.trim());
  void setInvoiceDateTime(DateTime dt) => state = state.copyWith(invoiceDateTime: dt);
  void setBusinessId(String id) => state = state.copyWith(businessId: id);

  // ✅ merged items getter
  List<InvoiceItem> get mergedItems => _mergeDuplicateItems(state.items);

  void removeItem(int index) {
    final updated = [...state.items];
    if (index < 0 || index >= updated.length) return;
    updated.removeAt(index);
    state = state.copyWith(items: updated);
  }

  List<InvoiceItem> _mergeDuplicateItems(List<InvoiceItem> items) {
    final cleaned = items
        .where((e) => e.name.trim().isNotEmpty)
        .map((e) => e.copyWith(name: e.name.trim()))
        .toList();

    final Map<String, InvoiceItem> map = {};

    for (final it in cleaned) {
      final nameKey = it.name.trim().toLowerCase();
      final priceKey = (it.price * 100).round();
      final key = '$nameKey|$priceKey';

      if (!map.containsKey(key)) {
        map[key] = it;
      } else {
        final prev = map[key]!;
        map[key] = prev.copyWith(qty: prev.qty + it.qty);
      }
    }

    return map.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  void _applyMergedItems() {
    state = state.copyWith(items: _mergeDuplicateItems(state.items));
  }

  void addItem() {
    final updated = [...state.items, const InvoiceItem(name: '', qty: 1, price: 0)];
    state = state.copyWith(items: updated);
  }

  void updateItemName(int index, String v) {
    final updated = [...state.items];
    if (index < 0 || index >= updated.length) return;
    updated[index] = updated[index].copyWith(name: v.trim());
    state = state.copyWith(items: updated);
  }

  void updateItemPrice(int index, double v) {
    final updated = [...state.items];
    if (index < 0 || index >= updated.length) return;

    final safePrice = v < 0 ? 0.0 : v;
    updated[index] = updated[index].copyWith(price: safePrice);
    state = state.copyWith(items: updated);

    // ✅ merge after price update
    _applyMergedItems();
  }

  void updateItemQty(int index, int v) {
    final updated = [...state.items];
    if (index < 0 || index >= updated.length) return;

    final safeQty = v < 1 ? 1 : v;
    updated[index] = updated[index].copyWith(qty: safeQty);
    state = state.copyWith(items: updated);
  }
}
