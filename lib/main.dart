import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/adapters.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('invoices'); // our local DB box
  await Hive.openBox('settings');
  await Hive.openBox('customers');

  runApp(ProviderScope(child: const MyApp()));
}

