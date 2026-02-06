import 'package:flutter/material.dart';
import 'features/invoice/presentation/pages/splash_page.dart';
import 'features/invoice/presentation/pages/invoice_page_list.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WhatsApp Invoice',
      home: const SplashPage(),
    );
  }
}

/// This is your real home page after splash
class MyAppHome extends StatelessWidget {
  const MyAppHome({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvoiceListPage();
  }
}
