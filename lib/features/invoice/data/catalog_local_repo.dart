import 'package:hive/hive.dart';

import '../domain/item_catalog_models.dart';

class CatalogLocalRepo {
  final Box box;
  CatalogLocalRepo(this.box);

  List<CatalogItem> getAll() {
    final items = box.values
        .whereType<Map>()
        .map((e) => CatalogItem.fromJson(e))
        .toList();

    // newest first
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  Future<void> upsert(CatalogItem item) async {
    await box.put(item.id, item.toJson());
  }

  Future<void> delete(String id) async {
    await box.delete(id);
  }
}
