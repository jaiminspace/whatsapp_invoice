import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/invoice_models.dart';
import 'business_list_notifier.dart';

final invoiceDraftProvider =
NotifierProvider<InvoiceDraftNotifier, InvoiceDraft>(
  InvoiceDraftNotifier.new,
);

class InvoiceDraftNotifier extends Notifier<InvoiceDraft> {
  @override
  InvoiceDraft build() {
    // ✅ If a business is already selected / exists, set it as default in new draft
    final defaultBizId = _defaultBusinessId();
    final draft = InvoiceDraft.empty();

    if (defaultBizId.isNotEmpty) {
      return draft.copyWith(businessId: defaultBizId);
    }
    return draft;
  }

  /// ✅ Get default businessId:
  /// 1) selectedBusinessIdProvider if set
  /// 2) else first business in list
  /// 3) else ''
  String _defaultBusinessId() {
    final selectedId = ref.read(selectedBusinessIdProvider);
    if (selectedId != null && selectedId.trim().isNotEmpty) {
      return selectedId.trim();
    }

    final list = ref.read(businessListProvider);
    if (list.isNotEmpty) return list.first.id;

    return '';
  }

  /// ✅ Call this from places where business list may have changed
  /// (optional but prevents "stale businessId" bugs)
  void ensureBusinessIsValid() {
    final list = ref.read(businessListProvider);
    if (list.isEmpty) {
      if (state.businessId.trim().isNotEmpty) {
        state = state.copyWith(businessId: '');
      }
      return;
    }

    final current = state.businessId.trim();
    final exists = list.any((b) => b.id == current);

    if (!exists) {
      final fallback = _defaultBusinessId();
      state = state.copyWith(businessId: fallback);
    }
  }

  /// ✅ Reset draft but keep default business selection
  void reset() {
    final defaultBizId = _defaultBusinessId();
    final fresh = InvoiceDraft.empty();

    state = defaultBizId.isEmpty ? fresh : fresh.copyWith(businessId: defaultBizId);
  }

  void loadFromInvoice(Invoice invoice) {
    // ✅ Keep invoice businessId as it was when invoice was created
    state = invoice.draft.copyWith(
      invoiceDateTime: invoice.createdAt,
      status: invoice.status,
    );

    // ✅ If business got deleted later, fall back safely
    ensureBusinessIsValid();
  }

  void setCustomerName(String v) =>
      state = state.copyWith(customerName: v.trim());

  void setCustomerMobile(String v) =>
      state = state.copyWith(customerMobile: v.trim());

  void setCustomInvoiceNumber(String v) =>
      state = state.copyWith(customInvoiceNumber: v.trim());

  void setInvoiceDateTime(DateTime dt) =>
      state = state.copyWith(invoiceDateTime: dt);

  void setBusinessId(String id) {
    final trimmed = id.trim();
    state = state.copyWith(businessId: trimmed);

    // ✅ also sync selectedBusinessIdProvider (so next invoice opens with this)
    ref.read(selectedBusinessIdProvider.notifier).state =
    trimmed.isEmpty ? null : trimmed;
  }

  void setInvoiceStatus(PaymentStatus status) =>
      state = state.copyWith(status: status);

  // ---------- Validation helpers ----------
  bool isValidItem(InvoiceItem it) {
    final nameOk = it.name.trim().isNotEmpty;
    final qtyOk = it.qty >= 1;
    return nameOk && qtyOk;
  }

  bool get hasAtLeastOneValidItem => state.items.any(isValidItem);

  List<InvoiceItem> get validItems =>
      state.items.where(isValidItem).toList(growable: false);

  // ---------- Duplicate merge ----------
  List<InvoiceItem> get mergedItems => _mergeDuplicateItems(state.items);

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

  // ---------- Items CRUD ----------
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

  void updateItemPrice(int index, double v) {
    final updated = [...state.items];
    if (index < 0 || index >= updated.length) return;
    final safePrice = v < 0 ? 0.0 : v;
    updated[index] = updated[index].copyWith(price: safePrice);
    state = state.copyWith(items: updated);

    // ✅ merge after price update (prevents duplicates)
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
