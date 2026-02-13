import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BackupZipService {
  static const String kAppPrefix = 'snap_invoice_backup';

  // boxes
  static const String boxInvoices = 'invoices';
  static const String boxCustomers = 'customers';
  static const String boxBusinesses = 'businesses';
  static const String boxCatalog = 'catalog_items';
  static const String boxLogs = 'activity_logs';
  static const String boxSettings = 'settings';

  // image folders inside zip
  static const String imgBizDir = 'images/business';
  static const String imgCustomerDir = 'images/customer';
  static const String imgItemDir = 'images/item';

  static String _fmt2(int v) => v.toString().padLeft(2, '0');

  static String buildReadableStamp(DateTime dt) {
    return '${dt.year}-${_fmt2(dt.month)}-${_fmt2(dt.day)}_${_fmt2(dt.hour)}-${_fmt2(dt.minute)}-${_fmt2(dt.second)}';
  }

  /// ✅ creates zip in temp dir and returns File
  static Future<File> exportZipBackup() async {
    // Ensure boxes are open (avoid "Box not found")
    await _ensureBoxesOpen();

    final now = DateTime.now();
    final stamp = buildReadableStamp(now);
    final zipName = '${kAppPrefix}_$stamp.zip';

    final tempDir = await getTemporaryDirectory();
    final zipPath = p.join(tempDir.path, zipName);

    final archive = Archive();

    // --- export each box as CSV ---
    archive.addFile(_csvFile('invoices.csv', _boxToCsv(boxInvoices, imageMapper: _invoiceImageMapper)));
    archive.addFile(_csvFile('customers.csv', _boxToCsv(boxCustomers, imageMapper: _customerImageMapper)));
    archive.addFile(_csvFile('businesses.csv', _boxToCsv(boxBusinesses, imageMapper: _businessImageMapper)));
    archive.addFile(_csvFile('items.csv', _boxToCsv(boxCatalog, imageMapper: _itemImageMapper)));
    archive.addFile(_csvFile('activity_logs.csv', _boxToCsv(boxLogs)));
    archive.addFile(_csvFile('settings.csv', _boxToCsv(boxSettings)));

    // --- collect images referenced by records and add into archive ---
    await _addImagesFromBox(
      archive: archive,
      boxName: boxBusinesses,
      imageField: 'imagePath',
      zipDir: imgBizDir,
      filePrefix: 'biz_',
    );

    await _addImagesFromBox(
      archive: archive,
      boxName: boxCustomers,
      imageField: 'imagePath', // ✅ confirm with you
      zipDir: imgCustomerDir,
      filePrefix: 'cust_',
    );

    // If Catalog items have images, enable this:
    await _addImagesFromBox(
      archive: archive,
      boxName: boxCatalog,
      imageField: 'imagePath', // if not exists, safe (will skip)
      zipDir: imgItemDir,
      filePrefix: 'item_',
    );

    // write zip
    final zipBytes = ZipEncoder().encode(archive);
    final file = File(zipPath);
    await file.writeAsBytes(zipBytes!, flush: true);
    return file;
  }

  /// ✅ Import zip, optionally wipe existing data
  static Future<int> importZipBackup({
    required Uint8List zipBytes,
    bool wipeBeforeImport = false,
  }) async {
    await _ensureBoxesOpen();

    final docs = await getApplicationDocumentsDirectory();
    final extractDir = Directory(p.join(docs.path, 'backup_extract'));
    if (extractDir.existsSync()) {
      await extractDir.delete(recursive: true);
    }
    await extractDir.create(recursive: true);

    final archive = ZipDecoder().decodeBytes(zipBytes);

    // extract files
    for (final f in archive) {
      final outPath = p.join(extractDir.path, f.name);
      if (f.isFile) {
        final outFile = File(outPath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(f.content as List<int>, flush: true);
      } else {
        Directory(outPath).createSync(recursive: true);
      }
    }

    if (wipeBeforeImport) {
      await _wipeAll();
    }

    // import csvs (if present)
    final imported = <String, int>{};

    imported[boxBusinesses] = await _importCsvIntoBox(
      boxName: boxBusinesses,
      csvFile: File(p.join(extractDir.path, 'businesses.csv')),
      extractRoot: extractDir.path,
    );

    imported[boxCustomers] = await _importCsvIntoBox(
      boxName: boxCustomers,
      csvFile: File(p.join(extractDir.path, 'customers.csv')),
      extractRoot: extractDir.path,
    );

    imported[boxCatalog] = await _importCsvIntoBox(
      boxName: boxCatalog,
      csvFile: File(p.join(extractDir.path, 'items.csv')),
      extractRoot: extractDir.path,
    );

    imported[boxInvoices] = await _importCsvIntoBox(
      boxName: boxInvoices,
      csvFile: File(p.join(extractDir.path, 'invoices.csv')),
      extractRoot: extractDir.path,
    );

    imported[boxLogs] = await _importCsvIntoBox(
      boxName: boxLogs,
      csvFile: File(p.join(extractDir.path, 'activity_logs.csv')),
      extractRoot: extractDir.path,
    );

    imported[boxSettings] = await _importCsvIntoBox(
      boxName: boxSettings,
      csvFile: File(p.join(extractDir.path, 'settings.csv')),
      extractRoot: extractDir.path,
    );

    // return total records imported
    return imported.values.fold<int>(0, (p0, e) => p0 + e);
  }

  // ----------------------- internals -----------------------

  static Future<void> _ensureBoxesOpen() async {
    // In case you call import/export before main opens them
    if (!Hive.isBoxOpen(boxInvoices)) await Hive.openBox(boxInvoices);
    if (!Hive.isBoxOpen(boxCustomers)) await Hive.openBox(boxCustomers);
    if (!Hive.isBoxOpen(boxBusinesses)) await Hive.openBox(boxBusinesses);
    if (!Hive.isBoxOpen(boxCatalog)) await Hive.openBox(boxCatalog);
    if (!Hive.isBoxOpen(boxLogs)) await Hive.openBox(boxLogs);
    if (!Hive.isBoxOpen(boxSettings)) await Hive.openBox(boxSettings);
  }

  static Future<void> _wipeAll() async {
    await Hive.box(boxInvoices).clear();
    await Hive.box(boxCustomers).clear();
    await Hive.box(boxBusinesses).clear();
    await Hive.box(boxCatalog).clear();
    await Hive.box(boxLogs).clear();
    // settings: you can choose NOT to wipe settings if you want
    // await Hive.box(boxSettings).clear();
  }

  static ArchiveFile _csvFile(String name, String csv) {
    final bytes = utf8.encode(csv);
    return ArchiveFile(name, bytes.length, bytes);
  }

  /// Convert a Hive box values (Map) into CSV:
  /// CSV columns: key,json
  static String _boxToCsv(
      String boxName, {
        Map<String, dynamic> Function(Map<String, dynamic> json)? imageMapper,
      }) {
    final box = Hive.box(boxName);

    final sb = StringBuffer();
    sb.writeln('key,json');

    for (final k in box.keys) {
      final raw = box.get(k);
      if (raw is! Map) continue;

      final map = Map<String, dynamic>.from(raw);
      final fixed = imageMapper == null ? map : imageMapper(map);

      final key = k.toString();
      final jsonStr = jsonEncode(fixed);

      // CSV-safe: wrap with quotes and escape quotes
      final escKey = _csvEscape(key);
      final escJson = _csvEscape(jsonStr);
      sb.writeln('$escKey,$escJson');
    }
    return sb.toString();
  }

  static String _csvEscape(String v) {
    final s = v.replaceAll('"', '""');
    return '"$s"';
  }

  /// Adds images referenced by `imageField` for each record in a box.
  /// Stores inside zip as images/.../<prefix><id>.<ext>
  /// Also rewrites record's imagePath in CSV via mappers.
  static Future<void> _addImagesFromBox({
    required Archive archive,
    required String boxName,
    required String imageField,
    required String zipDir,
    required String filePrefix,
  }) async {
    final box = Hive.box(boxName);

    for (final k in box.keys) {
      final raw = box.get(k);
      if (raw is! Map) continue;

      final map = Map<String, dynamic>.from(raw);
      final path = (map[imageField] ?? '').toString().trim();
      if (path.isEmpty) continue;

      final file = File(path);
      if (!file.existsSync()) continue;

      final ext = p.extension(file.path).isEmpty ? '.jpg' : p.extension(file.path);
      final id = (map['id'] ?? k.toString()).toString();
      final zipPath = p.join(zipDir, '$filePrefix$id$ext').replaceAll('\\', '/');

      try {
        final bytes = await file.readAsBytes();
        archive.addFile(ArchiveFile(zipPath, bytes.length, bytes));
      } catch (_) {
        // ignore unreadable files
      }
    }
  }

  // ---------- image mappers: convert absolute paths -> portable paths ----------
  static Map<String, dynamic> _businessImageMapper(Map<String, dynamic> json) {
    return _mapImagePath(json, field: 'imagePath', zipDir: imgBizDir, prefix: 'biz_');
  }

  static Map<String, dynamic> _customerImageMapper(Map<String, dynamic> json) {
    return _mapImagePath(json, field: 'imagePath', zipDir: imgCustomerDir, prefix: 'cust_');
  }

  static Map<String, dynamic> _itemImageMapper(Map<String, dynamic> json) {
    return _mapImagePath(json, field: 'imagePath', zipDir: imgItemDir, prefix: 'item_');
  }

  static Map<String, dynamic> _invoiceImageMapper(Map<String, dynamic> json) {
    // invoices usually don't have imagePath - keep as is
    return json;
  }

  static Map<String, dynamic> _mapImagePath(
      Map<String, dynamic> json, {
        required String field,
        required String zipDir,
        required String prefix,
      }) {
    final out = Map<String, dynamic>.from(json);
    final raw = (out[field] ?? '').toString().trim();
    if (raw.isEmpty) return out;

    final ext = p.extension(raw).isEmpty ? '.jpg' : p.extension(raw);
    final id = (out['id'] ?? '').toString().trim();
    if (id.isEmpty) return out;

    out[field] = p.join(zipDir, '$prefix$id$ext').replaceAll('\\', '/'); // portable
    return out;
  }

  // ---------- import csv into hive box ----------
  static Future<int> _importCsvIntoBox({
    required String boxName,
    required File csvFile,
    required String extractRoot,
  }) async {
    if (!csvFile.existsSync()) return 0;

    final text = await csvFile.readAsString();
    final lines = const LineSplitter().convert(text);
    if (lines.length <= 1) return 0;

    final box = Hive.box(boxName);

    int count = 0;

    // skip header
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = _splitCsv2(line);
      if (parts.length < 2) continue;

      final key = parts[0];
      final jsonStr = parts[1];

      try {
        final decoded = jsonDecode(jsonStr);
        if (decoded is! Map) continue;

        final map = Map<String, dynamic>.from(decoded);

        // restore portable image paths -> real device paths
        _restoreImagePathIfNeeded(map, extractRoot);

        await box.put(key, map);
        count++;
      } catch (_) {
        // ignore bad rows
      }
    }

    return count;
  }

  static void _restoreImagePathIfNeeded(
      Map<String, dynamic> json,
      String extractRoot,
      ) {
    final imgPath = (json['imagePath'] ?? '').toString().trim();
    if (imgPath.isEmpty) return;

    // if it's portable "images/..."
    if (imgPath.startsWith('images/')) {
      final full = p.join(extractRoot, imgPath);
      json['imagePath'] = full;
    }
  }

  /// Splits a CSV row with exactly 2 columns key,json where both are quoted.
  static List<String> _splitCsv2(String line) {
    // because we always export as: "key","json"
    // We'll parse minimally with quote handling.
    final out = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];

      if (ch == '"') {
        // escaped quote
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        out.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    out.add(buf.toString());
    return out;
  }
}
