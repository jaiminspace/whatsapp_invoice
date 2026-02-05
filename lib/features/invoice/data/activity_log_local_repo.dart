import 'package:hive/hive.dart';
import '../domain/activity_log_model.dart';

class ActivityLogLocalRepo {
  final Box box;
  ActivityLogLocalRepo(this.box);

  List<ActivityLog> getAll() {
    final list = box.values
        .whereType<Map>()
        .map((e) => ActivityLog.fromJson(e))
        .toList();

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> add(ActivityLog log) async {
    await box.put(log.id, log.toJson());
  }

  Future<void> clearAll() async {
    await box.clear();
  }

  Future<void> deleteById(String id) async {
    await box.delete(id);
  }
}
