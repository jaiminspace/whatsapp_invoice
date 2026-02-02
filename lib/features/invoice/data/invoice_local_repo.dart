import 'package:hive/hive.dart';
import '../domain/invoice_models.dart';

class InvoiceLocalRepo {
  final Box box;

  InvoiceLocalRepo(this.box);

  List<Invoice> getAll() {
    final values = box.values.toList();
    final invoices = values
        .whereType<Map>()
        .map((m) => Invoice.fromJson(m))
        .toList();

    invoices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return invoices;
  }

  Future<void> save(Invoice invoice) async {
    await box.put(invoice.id, invoice.toJson());
  }

  Future<void> delete(String id) async {
    await box.delete(id);
  }
}
