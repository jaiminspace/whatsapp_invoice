import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../data/catalog_local_repo.dart';
import '../../domain/item_catalog_models.dart';

final catalogRepoProvider = Provider<CatalogLocalRepo>((ref) {
  final box = Hive.box('catalog_items');
  return CatalogLocalRepo(box);
});

final catalogProvider = NotifierProvider<CatalogNotifier, List<CatalogItem>>(
  CatalogNotifier.new,
);

class CatalogNotifier extends Notifier<List<CatalogItem>> {
  late final CatalogLocalRepo repo;
  StreamSubscription? _sub;

  @override
  List<CatalogItem> build() {
    repo = ref.read(catalogRepoProvider);
    final initial = List<CatalogItem>.from(repo.getAll());

    final box = Hive.box('catalog_items');
    _sub?.cancel();
    _sub = box.watch().listen((_) {
      state = List<CatalogItem>.from(repo.getAll());
    });

    ref.onDispose(() => _sub?.cancel());
    return initial;
  }

  Future<void> add(String name, double price) async {
    final item = CatalogItem(
      id: const Uuid().v4(),
      name: name.trim(),
      price: price < 0 ? 0 : price,
    );
    await repo.save(item);
    state = List<CatalogItem>.from(repo.getAll());
  }

  Future<void> update(CatalogItem item) async {
    await repo.save(item);
    state = List<CatalogItem>.from(repo.getAll());
  }

  Future<void> delete(String id) async {
    await repo.delete(id);
    state = List<CatalogItem>.from(repo.getAll());
  }
}
