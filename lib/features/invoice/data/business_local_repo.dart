import 'package:hive/hive.dart';

import '../domain/business_entity.dart';

class BusinessLocalRepo {
  final Box box;

  BusinessLocalRepo(this.box);

  List<BusinessEntity> getAll() {
    return box.values
        .map((e) => BusinessEntity.fromJson(Map<dynamic, dynamic>.from(e)))
        .toList();
  }

  Future<void> save(BusinessEntity business) async {
    await box.put(business.id, business.toJson());
  }

  Future<void> delete(String id) async {
    await box.delete(id);
  }
}
