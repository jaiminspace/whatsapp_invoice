import 'dart:convert';

import 'package:whatsapp_invoice/features/invoice/domain/invoice_models.dart';

String _enumFromString(String s) => s.trim().toLowerCase();

PaymentStatus _parsePaymentStatus(String s) {
  final v = _enumFromString(s);
  return v == 'paid' ? PaymentStatus.paid : PaymentStatus.pending;
}

/// Very small CSV parser for our generated CSV format.
/// Assumes:
/// - header row exists
/// - rows do not contain newlines inside fields
/// - commas are escaped with quotes (as in our exporter)
List<List<String>> _parseCsv(String input) {
  final lines = const LineSplitter().convert(input);
  if (lines.isEmpty) return [];

  List<String> parseLine(String line) {
    final result = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];

      if (ch == '"') {
        // handle escaped quote ""
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        result.add(sb.toString());
        sb.clear();
      } else {
        sb.write(ch);
      }
    }

    result.add(sb.toString());
    return result;
  }

  return lines.map(parseLine).toList();
}

String _fallbackId() {
  // Works on web + mobile without Flutter imports
  return 'imp_${DateTime.now().microsecondsSinceEpoch}';
}

/// CSV export includes only summary columns, not line-items.
/// So we import invoices with a single dummy item = grand total.
/// For full restore (all items), use JSON backup/import.
List<Invoice> importInvoicesFromCsvText(String csvText) {
  final rows = _parseCsv(csvText);
  if (rows.length <= 1) return [];

  // header:
  // invoice_id,date,customer_name,customer_mobile,status,items_count,grand_total
  final dataRows = rows.skip(1);

  final invoices = <Invoice>[];

  for (final r in dataRows) {
    if (r.length < 7) continue;

    final id = r[0].trim();
    final dateStr = r[1].trim();
    final name = r[2].trim();
    final mobile = r[3].trim();
    final statusStr = r[4].trim();
    final totalStr = r[6].trim();

    final createdAt = DateTime.tryParse(dateStr) ?? DateTime.now();
    final total = double.tryParse(totalStr) ?? 0;

    final draft = InvoiceDraft(
      customerName: name,
      customerMobile: mobile,
      items: [
        // CSV does not contain item details
        InvoiceItem(
          name: 'Imported Total',
          qty: 1,
          price: total.toDouble(),
        ),
      ],
      customInvoiceNumber: '', // ✅ REQUIRED (CSV has none)
    );

    invoices.add(
      Invoice(
        id: id.isEmpty ? _fallbackId() : id,
        invoiceNumber: '', // CSV does not include invoice number
        createdAt: createdAt,
        draft: draft,
        status: _parsePaymentStatus(statusStr),
      ),
    );
  }

  return invoices;
}
