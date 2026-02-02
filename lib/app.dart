import 'package:flutter/material.dart';
import 'package:whatsapp_invoice/features/invoice/presentation/pages/invoice_page_list.dart';

import 'features/invoice/presentation/pages/dashboard_page.dart';
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WhatsApp Invoice',
      theme: ThemeData(useMaterial3: true),
      home: const InvoiceListPage(),
    );
  }
}