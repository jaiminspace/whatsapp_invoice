// file: invoice_pdf.dart

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/invoice_models.dart';

class InvoicePdf {
  static Future<List<int>> buildPdf({
    required Invoice invoice,
    required String businessName,
    required String businessPhone,
    required String businessAddress,
    required String upiId,
  }) async {
    final doc = pw.Document();

    final total = invoice.total.toStringAsFixed(2);

    // ✅ Universal UPI QR payload
    final hasUpi = upiId.trim().isNotEmpty;
    final upiData = hasUpi
        ? 'upi://pay?pa=${upiId.trim()}'
        '&pn=${Uri.encodeComponent(businessName.trim().isEmpty ? 'Business' : businessName.trim())}'
        '&am=$total'
        '&cu=INR'
        : '';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                businessName.trim().isEmpty ? 'Business' : businessName.trim(),
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              if (businessPhone.trim().isNotEmpty)
                pw.Text('Phone: ${businessPhone.trim()}'),
              if (businessAddress.trim().isNotEmpty)
                pw.Text('Address: ${businessAddress.trim()}'),

              pw.SizedBox(height: 12),
              pw.Divider(),

              pw.Text(
                'Customer: ${invoice.draft.customerName.isEmpty ? 'Customer' : invoice.draft.customerName}',
                style: pw.TextStyle(fontSize: 12),
              ),
              if (invoice.draft.customerMobile.trim().isNotEmpty)
                pw.Text('Mobile: ${invoice.draft.customerMobile.trim()}'),

              pw.SizedBox(height: 12),

              // Items
              pw.Text('Items', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),

              ...invoice.draft.items.map((e) {
                return pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(child: pw.Text(e.name.isEmpty ? '-' : e.name)),
                    pw.Text('${e.qty} × ₹${e.price.toStringAsFixed(2)}'),
                    pw.SizedBox(width: 10),
                    pw.Text('₹${e.total.toStringAsFixed(2)}'),
                  ],
                );
              }).toList(),

              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Grand Total',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('₹$total',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),

              pw.SizedBox(height: 16),

              // ✅ QR inside PDF (no QrCode used)
              if (hasUpi) ...[
                pw.Text('Scan to Pay (UPI)',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Center(child: _upiQr(upiData)),
                pw.SizedBox(height: 6),
                pw.Center(
                  child: pw.Text(
                    upiId.trim(),
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ),
              ] else ...[
                pw.Text(
                  'UPI not configured. Add UPI ID in Business details to generate QR.',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _upiQr(String data) {
    return pw.Container(
      width: 180,
      height: 180,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.BarcodeWidget(
        barcode: pw.Barcode.qrCode(),
        data: data,
        width: 160,
        height: 160,
        color: PdfColors.black,
        backgroundColor: PdfColors.white,
      ),
    );
  }
}
