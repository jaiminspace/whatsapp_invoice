import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/invoice_models.dart';

class InvoicePdf {
  static Future<Uint8List> buildPdf({
    required Invoice invoice,
    String businessName = 'My Business',
    String businessPhone = '',
    String businessAddress = '',
    String upiId = '',
  }) async {
    final doc = pw.Document();

    final shortId = invoice.id.substring(0, 8).toUpperCase();
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(invoice.createdAt);

    // Build UPI payload to embed in QR
    final upiPayload = (upiId.trim().isEmpty)
        ? ''
        : Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': upiId.trim(),
        'pn': businessName.trim().isEmpty ? 'Payment' : businessName.trim(),
        'am': invoice.total.toStringAsFixed(2),
        'cu': 'INR',
        'tn': 'INV-$shortId',
      },
    ).toString();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return <pw.Widget>[
            // Header
            pw.Text(
              businessName.isEmpty ? 'My Business' : businessName,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            if (businessAddress.trim().isNotEmpty) pw.Text(businessAddress),
            if (businessPhone.trim().isNotEmpty) pw.Text('Phone: $businessPhone'),
            pw.SizedBox(height: 12),
            pw.Divider(),

            // Invoice meta
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Invoice: INV-$shortId'),
                pw.Text(dateStr),
              ],
            ),
            pw.SizedBox(height: 12),

            // Customer
            pw.Text('Bill To:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(invoice.draft.customerName.isEmpty ? 'Customer' : invoice.draft.customerName),
            if (invoice.draft.customerMobile.trim().isNotEmpty)
              pw.Text('Mobile: ${invoice.draft.customerMobile}'),

            pw.SizedBox(height: 16),

            // Items table
            pw.Table.fromTextArray(
              headers: const ['Item', 'Qty', 'Price', 'Total'],
              data: invoice.draft.items.map((e) {
                return [
                  e.name.isEmpty ? '-' : e.name,
                  e.qty.toString(),
                  'Rs. ${e.price.toStringAsFixed(2)}',
                  'Rs. ${e.total.toStringAsFixed(2)}',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
            ),

            pw.SizedBox(height: 16),

            // Grand total box
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey700),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    'Grand Total: Rs. ${invoice.total.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),

            // Payment QR inside the PDF (Uber/Rapido style)
            if (upiPayload.isNotEmpty) ...[
              pw.SizedBox(height: 18),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text('Pay by scanning UPI QR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),

              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey700),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: upiPayload,
                      width: 120,
                      height: 120,
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('UPI ID: ${upiId.trim()}'),
                        pw.Text('Amount: Rs. ${invoice.total.toStringAsFixed(2)}'),
                        pw.SizedBox(height: 6),
                        pw.Text('Scan using any UPI app (GPay/PhonePe/Paytm/BHIM).'),
                        pw.SizedBox(height: 6),
                        pw.Text('Note: INV-$shortId'),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            pw.SizedBox(height: 18),
            pw.Text('Thank you!', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ];
        },
      ),
    );

    return doc.save();
  }
}
