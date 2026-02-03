import 'package:hive/hive.dart';
import '../domain/item_catalog_models.dart';

class CatalogLocalRepo {
  final Box box;
  CatalogLocalRepo(this.box);

  List<CatalogItem> getAll() {
    return box.values
        .map((e) => CatalogItem.fromJson(Map<dynamic, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> save(CatalogItem item) => box.put(item.id, item.toJson());
  Future<void> delete(String id) => box.delete(id);
}
