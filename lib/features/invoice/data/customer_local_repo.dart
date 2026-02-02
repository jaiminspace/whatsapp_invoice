import 'package:hive/hive.dart';
import '../domain/customer_model.dart';

class CustomerLocalRepo {
  final Box box;
  CustomerLocalRepo(this.box);

  List<Customer> getAll() {
    final items = box.values
        .whereType<Map>()
        .map((e) => Customer.fromJson(e))
        .toList();

    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  Future<void> upsert(Customer c) async {
    await box.put(c.id, c.toJson());
  }

  Future<void> delete(String id) async {
    await box.delete(id);
  }
}