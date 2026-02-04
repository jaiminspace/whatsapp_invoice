import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/invoice_models.dart';
import '../state/invoice_list_notifier.dart';
import '../utils/invoice_pdf.dart';

// ✅ Multi-business
import '../state/business_list_notifier.dart';

class InvoiceDetailPage extends ConsumerWidget {
  final Invoice invoice;

  const InvoiceDetailPage({super.key, required this.invoice});

  // ✅ Merge duplicates ONLY for display
  List<InvoiceItem> _mergeDuplicateItems(List<InvoiceItem> items) {
    final cleaned = items
        .where((e) => e.name.trim().isNotEmpty)
        .map((e) => e.copyWith(name: e.name.trim()))
        .toList();

    final Map<String, InvoiceItem> map = {};

    for (final it in cleaned) {
      final nameKey = it.name.trim().toLowerCase();
      final priceKey = (it.price * 100).round(); // 2 decimals stable
      final key = '$nameKey|$priceKey';

      if (!map.containsKey(key)) {
        map[key] = it;
      } else {
        final prev = map[key]!;
        map[key] = prev.copyWith(qty: prev.qty + it.qty);
      }
    }

    return map.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  String _shareCaption({
    required String customerName,
    required String invoiceNumber,
    required double total,
    required String businessName,
    required bool hasUpi,
  }) {
    final name = customerName.isEmpty ? 'Customer' : customerName;
    final base =
        'Hi $name, here is your invoice ($invoiceNumber) from $businessName. Total: ₹${total.toStringAsFixed(2)}.';
    if (!hasUpi) return '$base Thank you!';
    return '$base I’m sharing the invoice PDF with payment QR inside. You can scan and pay using any UPI app. Thank you!';
  }

  Future<void> _openWhatsApp(String message) async {
    final encoded = Uri.encodeComponent(message);
    final url = Uri.parse('https://wa.me/?text=$encoded');

    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok) {
      final alt = Uri.parse('https://web.whatsapp.com/send?text=$encoded');
      await launchUrl(alt, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ IMPORTANT FIX: use INVOICE items, not draft provider items
    final mergedItems = _mergeDuplicateItems(invoice.draft.items);

    // ✅ get business from invoice.draft.businessId
    final businesses = ref.watch(businessListProvider);
    final businessId = invoice.draft.businessId;

    final business = businesses.isEmpty
        ? null
        : businesses.firstWhere(
            (b) => b.id == businessId,
            orElse: () => businesses.first,
          );

    final businessName = (business?.name.trim().isNotEmpty ?? false)
        ? business!.name.trim()
        : 'Business';

    final hasUpi = (business?.upiId.trim().isNotEmpty ?? false);

    // ✅ Use invoice.createdAt (already draft.invoiceDateTime when saving)
    final dateStr = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(invoice.createdAt);

    final invNo = invoice.invoiceNumber.trim().isNotEmpty
        ? invoice.invoiceNumber.trim()
        : 'INV-${invoice.id.substring(0, 8).toUpperCase()}';

    final caption = _shareCaption(
      customerName: invoice.draft.customerName,
      invoiceNumber: invNo,
      total: invoice.total,
      businessName: businessName,
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
                    ? 'Customer / Client'
                    : invoice.draft.customerName,
              ),
              subtitle: Text('$invNo • Created: $dateStr'),
              trailing: Text(
                '₹${invoice.total.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (mergedItems.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text('No items'),
                    )
                  else
                    ...mergedItems.map((e) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.name.isEmpty ? '-' : e.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text('${e.qty} × ₹${e.price.toStringAsFixed(0)}'),
                            const SizedBox(width: 12),
                            Text(
                              '₹${e.total.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
                      'Business: $businessName',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),

                  if ((business?.phone.trim().isNotEmpty ?? false))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Phone: ${business!.phone}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),

                  if ((business?.upiId.trim().isNotEmpty ?? false))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'UPI: ${business!.upiId} (QR will be inside PDF)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          FilledButton.icon(
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Share Invoice PDF (with QR)'),
            onPressed: () async {
              final pdfBytes = await InvoicePdf.buildPdf(
                invoice: invoice,
                businessName: businessName,
                businessPhone: business?.phone ?? '',
                businessAddress: business?.address ?? '',
                upiId: business?.upiId ?? '',
              );

              await Printing.sharePdf(
                bytes: Uint8List.fromList(pdfBytes),
                filename: 'invoice_$invNo.pdf',
              );
            },
          ),

          const SizedBox(height: 10),

          OutlinedButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Print / Save as PDF'),
            onPressed: () async {
              await Printing.layoutPdf(
                onLayout: (_) async {
                  final pdfBytes = await InvoicePdf.buildPdf(
                    invoice: invoice,
                    businessName: businessName,
                    businessPhone: business?.phone ?? '',
                    businessAddress: business?.address ?? '',
                    upiId: business?.upiId ?? '',
                  );
                  return Uint8List.fromList(pdfBytes);
                },
                name: 'invoice_$invNo',
              );
            },
          ),

          const SizedBox(height: 10),

          FilledButton.icon(
            icon: Image.asset(
              'assets/icons/whatsapp.png',
              width: 22,
              height: 22,
            ),
            label: const Text('Send WhatsApp Message'),
            onPressed: () => _openWhatsApp(caption),
          ),

          const SizedBox(height: 10),

          FilledButton(
            onPressed: () async {
              await ref
                  .read(invoiceListProvider.notifier)
                  .togglePaymentStatus(invoice);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(
              invoice.status == PaymentStatus.paid
                  ? 'Mark as Pending'
                  : 'Mark as Paid',
            ),
          ),
        ],
      ),
    );
  }
}
