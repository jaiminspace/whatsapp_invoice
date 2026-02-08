import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'features/invoice/presentation/state/catalog_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  await Hive.openBox('invoices');
  await Hive.openBox('customers');
  await Hive.openBox('settings');

  // ✅ multi-business
  await Hive.openBox('businesses');

  // ✅ logs
  await Hive.openBox('activity_logs');

  // ✅ Open catalog boxes for every existing business
  final businessesBox = Hive.box('businesses');
  final businessIds = businessesBox.values
      .whereType<Map>()
      .map((m) => (m['id'] ?? '').toString().trim())
      .where((id) => id.isNotEmpty)
      .toSet();

  for (final id in businessIds) {
    await Hive.openBox(catalogBoxNameForBiz(id));
  }

  runApp(const ProviderScope(child: MyApp()));
}
