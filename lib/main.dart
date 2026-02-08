import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // ✅ Open ALL boxes before ProviderScope (VERY IMPORTANT)
  await Hive.openBox('invoices');
  await Hive.openBox('customers');
  await Hive.openBox('settings');
  await Hive.openBox('businesses');

  // ✅ Global items catalog (NOT per business)
  await Hive.openBox('catalog_items');

  // ✅ Logs
  await Hive.openBox('activity_logs');

  runApp(const ProviderScope(child: MyApp()));
}
