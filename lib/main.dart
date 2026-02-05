import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  await Hive.openBox('invoices');
  await Hive.openBox('customers');
  await Hive.openBox('settings');

  // ✅ NEW boxes for multi business + item catalog
  await Hive.openBox('businesses');
  await Hive.openBox('catalog_items');

  // ✅ NEW box for logs
  await Hive.openBox('activity_logs');

  runApp(const ProviderScope(child: MyApp()));
}
