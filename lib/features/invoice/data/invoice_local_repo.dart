import 'package:hive/hive.dart';

import '../domain/invoice_models.dart';

class InvoiceLocalRepo {
  final Box box;
  InvoiceLocalRepo(this.box);

  List<Invoice> getAll() {
    final list = box.values
        .whereType<Map>()
        .map((e) => Invoice.fromJson(e))
        .toList();

    // newest first
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Invoice? getById(String id) {
    final raw = box.get(id);
    if (raw is Map) return Invoice.fromJson(raw);
    return null;
  }

  Future<void> save(Invoice invoice) async {
    await box.put(invoice.id, invoice.toJson());
  }

  /// ✅ compatibility alias (so other files can call upsert)
  Future<void> upsert(Invoice invoice) => save(invoice);

  Future<void> delete(String id) async {
    await box.delete(id);
  }

  Future<void> clear() async {
    await box.clear();
  }
}
