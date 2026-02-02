String _csvEscape(String v) {
  final s = v.replaceAll('"', '""');
  if (s.contains(',') || s.contains('\n') || s.contains('"')) {
    return '"$s"';
  }
  return s;
}

String _enumToString(dynamic e) {
  // Works everywhere (web/mobile), no .name needed
  // Example: PaymentStatus.pending -> "pending"
  final raw = e.toString();
  final dot = raw.indexOf('.');
  return dot == -1 ? raw : raw.substring(dot + 1);
}

String invoicesToCsv(List invoices) {
  final buffer = StringBuffer();
  buffer.writeln(
    'invoice_id,date,customer_name,customer_mobile,status,items_count,grand_total',
  );

  for (final inv in invoices) {
    final id = inv.id.toString();
    final date = inv.createdAt.toIso8601String();
    final name = inv.draft.customerName.toString();
    final mobile = inv.draft.customerMobile.toString();
    final status = _enumToString(inv.status);
    final itemsCount = inv.draft.items.length.toString();
    final total = inv.total.toStringAsFixed(2);

    buffer.writeln([
      _csvEscape(id),
      _csvEscape(date),
      _csvEscape(name),
      _csvEscape(mobile),
      _csvEscape(status),
      _csvEscape(itemsCount),
      _csvEscape(total),
    ].join(','));
  }

  return buffer.toString();
}
