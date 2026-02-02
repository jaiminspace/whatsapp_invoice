import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/invoice_models.dart';
import '../state/business_profile_notifier.dart';
import '../state/invoice_list_notifier.dart';
import '../utils/invoice_pdf.dart';

class InvoiceDetailPage extends ConsumerWidget {
  final Invoice invoice;
  const InvoiceDetailPage({super.key, required this.invoice});

  String _shareCaption({
    required String customerName,
    required String shortId,
    required double total,
    required String businessName,
    required bool hasUpi,
  }) {
    final name = customerName.isEmpty ? 'Customer' : customerName;
    final base =
        'Hi $name, here is your invoice (INV-$shortId) from $businessName. Total: ₹${total.toStringAsFixed(2)}.';
    if (!hasUpi) return '$base Thank you!';
    return '$base I’m sharing the invoice PDF with payment QR inside. You can scan and pay using any UPI app. Thank you!';
  }

  Future<void> _openWhatsApp(String message) async {
    final encoded = Uri.encodeComponent(message);

    // Web + mobile compatible
    final url = Uri.parse('https://wa.me/?text=$encoded');

    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok) {
      final alt = Uri.parse('https://web.whatsapp.com/send?text=$encoded');
      await launchUrl(alt, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(businessProfileProvider);
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(invoice.createdAt);
    final shortId = invoice.id.substring(0, 8).toUpperCase();

    final hasUpi = profile.upiId.trim().isNotEmpty;

    final caption = _shareCaption(
      customerName: invoice.draft.customerName,
      shortId: shortId,
      total: invoice.total,
      businessName: profile.name,
      hasUpi: hasUpi,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Invoice Detail')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: Text(
                invoice.draft.customerName.isEmpty
                    ? 'Customer'
                    : invoice.draft.customerName,
              ),
              subtitle: Text('INV-$shortId • Created: $dateStr'),
              trailing: Text(
                '₹${invoice.total.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Items',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...invoice.draft.items.map((e) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text(e.name.isEmpty ? '-' : e.name)),
                          Text('${e.qty} × ₹${e.price.toStringAsFixed(0)}'),
                          const SizedBox(width: 12),
                          Text('₹${e.total.toStringAsFixed(0)}'),
                        ],
                      ),
                    );
                  }),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Grand Total',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '₹${invoice.total.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Business: ${profile.name}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (profile.phone.trim().isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Phone: ${profile.phone}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  if (hasUpi)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'UPI: ${profile.upiId} (QR will be inside PDF)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Share PDF (PDF already contains QR if UPI ID is set)
          FilledButton.icon(
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Share Invoice PDF (with QR)'),
            onPressed: () async {
              final bytes = await InvoicePdf.buildPdf(
                invoice: invoice,
                businessName: profile.name,
                businessPhone: profile.phone,
                businessAddress: profile.address,
                upiId: profile.upiId,
              );

              await Printing.sharePdf(
                bytes: bytes,
                filename: 'invoice_$shortId.pdf',
              );
            },
          ),

          const SizedBox(height: 10),

          OutlinedButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Print / Save as PDF'),
            onPressed: () async {
              await Printing.layoutPdf(
                onLayout: (_) async => InvoicePdf.buildPdf(
                  invoice: invoice,
                  businessName: profile.name,
                  businessPhone: profile.phone,
                  businessAddress: profile.address,
                  upiId: profile.upiId,
                ),
                name: 'invoice_$shortId',
              );
            },
          ),

          const SizedBox(height: 10),

          // Send WhatsApp message (text only)
          FilledButton.icon(
            icon: Image.asset(
              'assets/icons/whatsapp.png',
              width: 22,
              height: 22,
            ),
            label: const Text('Send WhatsApp Message'),
            onPressed: () => _openWhatsApp(caption),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () async {
              await ref.read(invoiceListProvider.notifier).togglePaymentStatus(invoice);
              Navigator.pop(context);
              // ✅ tell list to refresh
            },
            child: Text(
              invoice.status == PaymentStatus.paid ? 'Mark as Pending' : 'Mark as Paid',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasUpi
                ? 'Tip: Share the PDF first (it contains the payment QR). Then send the WhatsApp message for context.'
                : 'Tip: Add your UPI ID in Settings to include payment QR inside the PDF invoice.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
