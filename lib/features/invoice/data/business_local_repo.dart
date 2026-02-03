import 'package:hive/hive.dart';
import '../domain/business_models.dart';

class BusinessLocalRepo {
  final Box box;
  BusinessLocalRepo(this.box);

  List<Business> getAll() {
    return box.values
        .map((e) => Business.fromJson(Map<dynamic, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> save(Business b) => box.put(b.id, b.toJson());
  Future<void> delete(String id) => box.delete(id);
}
