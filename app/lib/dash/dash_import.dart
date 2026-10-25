import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../core/api.dart';
import '../core/app.dart';
import '../core/common.dart';
import '../core/models.dart';
import '../core/theme.dart';
import 'dash_admin.dart' show palette, garments;

/// One spreadsheet row = one size of one colour of one product.
class _Row {
  final int line;
  String nameAr = '', nameEn = '', descAr = '', descEn = '', category = '', garment = 'tee', colorAr = '', colorEn = '', hex = '', size = '', image = '';
  double price = 0;
  double? compare;
  int stock = 0;
  _Row(this.line);
}

const _aliases = {
  'name_ar': ['name_ar', 'اسم المنتج', 'الاسم', 'الاسم عربي', 'اسم عربي'],
  'name_en': ['name_en', 'name', 'product', 'الاسم انجليزي', 'اسم انجليزي', 'الاسم بالانجليزي'],
  'price': ['price', 'السعر', 'سعر البيع', 'سعر'],
  'compare': ['compare_price', 'compare_at_price', 'old_price', 'السعر قبل الخصم'],
  'category': ['category', 'القسم'],
  'garment': ['garment', 'type', 'النوع', 'الشكل'],
  'color_ar': ['color_ar', 'اللون', 'اللون عربي'],
  'color_en': ['color_en', 'color', 'colour', 'اللون انجليزي'],
  'color_hex': ['color_hex', 'hex', 'كود اللون'],
  'size': ['size', 'المقاس'],
  'stock': ['stock', 'qty', 'quantity', 'الكمية', 'المخزون'],
  'image': ['image', 'photo', 'image_url', 'الصورة', 'صورة'],
  'desc_ar': ['description_ar', 'desc_ar', 'الوصف', 'وصف'],
  'desc_en': ['description_en', 'desc_en', 'الوصف انجليزي'],
};

String _norm(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

List<List<String>> _readSheet(Uint8List bytes, String name) {
  if (name.toLowerCase().endsWith('.csv')) {
    final text = utf8.decode(bytes, allowMalformed: true).replaceFirst('﻿', '');
    return const LineSplitter().convert(text).where((l) => l.trim().isNotEmpty).map(_csvLine).toList();
  }
  final book = xl.Excel.decodeBytes(bytes);
  final sheet = book.tables.values.first;
  return [
    for (final r in sheet.rows)
      [for (final c in r) c?.value == null ? '' : '${c!.value}'.trim()]
  ].where((r) => r.any((c) => c.isNotEmpty)).toList();
}

List<String> _csvLine(String l) {
  final out = <String>[];
  var cur = StringBuffer();
  var q = false;
  for (var i = 0; i < l.length; i++) {
    final ch = l[i];
    if (ch == '"') {
      if (q && i + 1 < l.length && l[i + 1] == '"') {
        cur.write('"');
        i++;
      } else {
        q = !q;
      }
    } else if ((ch == ',' || ch == ';') && !q) {
      out.add(cur.toString().trim());
      cur = StringBuffer();
    } else {
      cur.write(ch);
    }
  }
  out.add(cur.toString().trim());
  return out;
}

class ImportScreen extends StatefulWidget {
  const ImportScreen();
  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  String? fileName;
  List<_Row> rows = [];
  final problems = <String>[];
  final images = <String, PlatformFile>{};
  bool busy = false;
  String progress = '';
  bool done = false;

  Future<void> _pickSheet() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'csv'], withData: true);
    if (r == null || r.files.isEmpty || r.files.first.bytes == null) return;
    final f = r.files.first;
    setState(() {
      problems.clear();
      rows = [];
      fileName = f.name;
    });
    try {
      _parse(_readSheet(f.bytes!, f.name));
    } catch (_) {
      problems.add(tr('مقدرناش نقرأ الملف. اتأكد إنه xlsx أو csv.', 'Could not read the file. Use xlsx or csv.'));
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickImages() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true, withData: true);
    if (r == null) return;
    setState(() {
      for (final f in r.files) {
        if (f.bytes != null) images[_norm(f.name)] = f;
      }
    });
  }

  void _parse(List<List<String>> table) {
    if (table.length < 2) {
      problems.add(tr('الملف فاضي أو مفيهوش صفوف.', 'The file has no data rows.'));
      return;
    }
    final head = table.first.map(_norm).toList();
    int col(String key) {
      for (final a in _aliases[key]!) {
        final i = head.indexOf(_norm(a));
        if (i >= 0) return i;
      }
      return -1;
    }

    final c = {for (final k in _aliases.keys) k: col(k)};
    if (c['price']! < 0 || (c['name_ar']! < 0 && c['name_en']! < 0)) {
      problems.add(tr('لازم يبقى فيه عمود للاسم (name_ar أو name_en) وعمود السعر (price).', 'The sheet needs a name column (name_ar or name_en) and a price column.'));
      return;
    }
    String cell(List<String> r, String k) => (c[k]! >= 0 && c[k]! < r.length) ? r[c[k]!] : '';
    final cats = App.i.categories.map((e) => '${e['slug']}').toSet();
    for (var i = 1; i < table.length; i++) {
      final r = table[i];
      final x = _Row(i + 1)
        ..nameAr = cell(r, 'name_ar')
        ..nameEn = cell(r, 'name_en')
        ..descAr = cell(r, 'desc_ar')
        ..descEn = cell(r, 'desc_en')
        ..colorAr = cell(r, 'color_ar')
        ..colorEn = cell(r, 'color_en')
        ..image = cell(r, 'image')
        ..size = cell(r, 'size').toUpperCase();
      if (x.nameAr.isEmpty) x.nameAr = x.nameEn;
      if (x.nameEn.isEmpty) x.nameEn = x.nameAr;
      x.price = double.tryParse(cell(r, 'price').replaceAll(',', '')) ?? -1;
      x.compare = double.tryParse(cell(r, 'compare').replaceAll(',', ''));
      x.stock = int.tryParse(cell(r, 'stock').split('.').first) ?? 0;
      final g = _norm(cell(r, 'garment'));
      x.garment = garments.containsKey(g) ? g : (garments.entries.where((e) => e.value[0] == g || _norm(e.value[1]) == g).map((e) => e.key).firstOrNull ?? 'tee');
      var cat = _norm(cell(r, 'category'));
      if (cat.isEmpty || !cats.contains(cat)) {
        final byName = App.i.categories.where((e) => _norm('${e['name_ar']}') == cat || _norm('${e['name_en']}') == cat).firstOrNull;
        cat = byName != null ? '${byName['slug']}' : garments[x.garment]![2];
      }
      x.category = cat;
      var hex = cell(r, 'color_hex');
      if (!RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(hex)) {
        hex = '';
        for (final p in palette) {
          if (_norm(p[0]) == _norm(x.colorAr) || _norm(p[1]) == _norm(x.colorEn) || _norm(p[1]) == _norm(x.colorAr) || _norm(p[0]) == _norm(x.colorEn)) {
            hex = p[2];
            if (x.colorAr.isEmpty) x.colorAr = p[0];
            if (x.colorEn.isEmpty) x.colorEn = p[1];
          }
        }
      }
      if (hex.isNotEmpty && !hex.startsWith('#')) hex = '#$hex';
      x.hex = hex.toUpperCase();
      if (x.colorAr.isEmpty) x.colorAr = x.colorEn;
      if (x.colorEn.isEmpty) x.colorEn = x.colorAr;
      if (x.size.isEmpty) x.size = 'M';
      final why = <String>[];
      if (x.nameAr.isEmpty) why.add(tr('بدون اسم', 'no name'));
      if (x.price < 0) why.add(tr('سعر غير صحيح', 'bad price'));
      if (x.hex.isEmpty) why.add(tr('اللون غير معروف — اكتب كود اللون #RRGGBB أو اسم من القائمة', 'unknown colour — give a #RRGGBB code or a known name'));
      if (why.isNotEmpty) {
        problems.add(tr('صف ${x.line}: ${why.join('، ')}', 'Row ${x.line}: ${why.join(', ')}'));
      } else {
        rows.add(x);
      }
    }
  }

  Future<String?> _imageUrl(String productId, String hex, String ref) async {
    if (ref.isEmpty) return null;
    if (ref.startsWith('http')) return ref;
    final f = images[_norm(ref)];
    if (f == null) return null;
    final ext = f.name.toLowerCase().endsWith('png') ? 'png' : 'jpg';
    final path = 'products/$productId/${hex.substring(1)}-${DateTime.now().millisecondsSinceEpoch}.$ext';
    final bucket = App.i.db.storage.from('novaki-products');
    await bucket.uploadBinary(path, f.bytes!, fileOptions: FileOptions(contentType: ext == 'png' ? 'image/png' : 'image/jpeg', upsert: true));
    return bucket.getPublicUrl(path);
  }

  Future<void> _run() async {
    setState(() {
      busy = true;
      progress = '';
    });
    try {
      final db = App.i.db;
      final existing = (await db.from('products').select('id, name_ar, name_en')).map((e) => Json.from(e)).toList();
      final groups = <String, List<_Row>>{};
      for (final r in rows) {
        groups.putIfAbsent('${_norm(r.nameEn)}|${_norm(r.nameAr)}', () => []).add(r);
      }
      var n = 0, created = 0, updated = 0, missingImgs = 0;
      for (final g in groups.values) {
        n++;
        setState(() => progress = tr('$n من ${groups.length}: ${g.first.nameAr}', '$n of ${groups.length}: ${g.first.nameEn}'));
        final f = g.first;
        final body = {
          'name_ar': f.nameAr,
          'name_en': f.nameEn,
          if (f.descAr.isNotEmpty) 'description_ar': f.descAr,
          if (f.descEn.isNotEmpty) 'description_en': f.descEn,
          'price': f.price,
          'compare_at_price': f.compare,
          'category': f.category,
          'garment': f.garment,
        };
        final match = existing.where((e) => _norm('${e['name_en']}') == _norm(f.nameEn) || _norm('${e['name_ar']}') == _norm(f.nameAr)).firstOrNull;
        String pid;
        if (match != null) {
          pid = match['id'];
          await db.from('products').update(body).eq('id', pid);
          updated++;
        } else {
          final row = await db.from('products').insert(body).select('id').single();
          pid = row['id'];
          existing.add({'id': pid, 'name_ar': f.nameAr, 'name_en': f.nameEn});
          created++;
        }
        final urls = <String, String?>{};
        for (final r in g) {
          if (!urls.containsKey(r.hex)) {
            urls[r.hex] = await _imageUrl(pid, r.hex, r.image);
            if (r.image.isNotEmpty && urls[r.hex] == null) missingImgs++;
          }
        }
        await db.from('product_variants').upsert([
          for (final r in g)
            {
              'product_id': pid,
              'color_name_ar': r.colorAr,
              'color_name_en': r.colorEn,
              'color_hex': r.hex,
              'size': r.size,
              'stock': r.stock,
              if (urls[r.hex] != null) 'image_url': urls[r.hex],
            }
        ], onConflict: 'product_id,color_hex,size');
      }
      if (!mounted) return;
      setState(() {
        done = true;
        progress = tr('تم: $created منتج جديد، $updated اتحدّث${missingImgs > 0 ? '، $missingImgs صورة مالقيناهاش' : ''}. المنتجات ظهرت في التطبيق فورًا.',
            'Done: $created new, $updated updated${missingImgs > 0 ? ', $missingImgs images not found' : ''}. Products are live in the app now.');
      });
    } catch (e) {
      toastError(e);
      if (mounted) setState(() => progress = '');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = rows.map((r) => '${_norm(r.nameEn)}|${_norm(r.nameAr)}').toSet().length;
    final refs = rows.map((r) => r.image).where((e) => e.isNotEmpty && !e.startsWith('http')).toSet();
    final missing = refs.where((e) => !images.containsKey(_norm(e))).length;
    return Scaffold(
      appBar: AppBar(title: Text(tr('استيراد من إكسيل', 'IMPORT FROM EXCEL'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 30), children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
          child: Text(
            tr('كل صف = مقاس واحد للون واحد من منتج.\nالأعمدة: name_ar, name_en, price, compare_price, category, garment, color_ar, color_en, color_hex, size, stock, image, description_ar, description_en.\nعمود image: اسم ملف الصورة (هترفعها هنا) أو لينك مباشر.\nلو المنتج موجود بنفس الاسم بيتحدّث، وإلا بيتضاف. من غير APK جديد، المنتجات بتظهر لحظيًا.',
                'One row = one size of one colour of a product.\nColumns: name_ar, name_en, price, compare_price, category, garment, color_ar, color_en, color_hex, size, stock, image, description_ar, description_en.\nimage: a file name (pick the files below) or a direct link.\nExisting products with the same name are updated, others are added. Live in the app instantly, no new APK.'),
            style: const TextStyle(height: 1.5, fontSize: 12.5),
          ),
        ),
        const SizedBox(height: 14),
        NeonButton(fileName == null ? tr('اختار ملف الإكسيل', 'Pick the spreadsheet') : fileName!, icon: Icons.table_chart_outlined, outline: true, onPressed: busy ? null : _pickSheet),
        const SizedBox(height: 10),
        NeonButton(images.isEmpty ? tr('اختار الصور (اختياري)', 'Pick the images (optional)') : tr('${images.length} صورة مختارة', '${images.length} images selected'), icon: Icons.photo_library_outlined, outline: true, onPressed: busy ? null : _pickImages),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(tr('جاهز للاستيراد: $products منتج · ${rows.length} صف', 'Ready: $products products · ${rows.length} rows'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          if (missing > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Text(tr('$missing صورة مذكورة في الملف ومش مختارة', '$missing images named in the sheet are not selected'), style: const TextStyle(color: C.warn, fontSize: 12.5))),
          const SizedBox(height: 8),
          for (final r in rows.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: hexColor(r.hex), shape: BoxShape.circle, border: Border.all(color: C.line))),
                const SizedBox(width: 8),
                Expanded(child: Text('${r.nameAr} · ${r.colorAr} · ${r.size} · x${r.stock}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5))),
                Text(money(r.price), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              ]),
            ),
          if (rows.length > 6) Text(tr('... و${rows.length - 6} صف كمان', '... and ${rows.length - 6} more rows'), style: TextStyle(color: C.mute, fontSize: 12)),
        ],
        if (problems.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(tr('ملاحظات (الصفوف دي هتتجاهل):', 'Issues (these rows are skipped):'), style: const TextStyle(color: C.danger, fontWeight: FontWeight.w800)),
          for (final p in problems.take(10)) Padding(padding: const EdgeInsets.only(top: 3), child: Text('• $p', style: const TextStyle(fontSize: 12.5, height: 1.35))),
        ],
        if (rows.isNotEmpty && !done) ...[
          const SizedBox(height: 22),
          NeonButton(tr('استيراد دلوقتي', 'Import now'), icon: Icons.cloud_upload_outlined, loading: busy, onPressed: busy ? null : _run),
        ],
        if (progress.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 14), child: Text(progress, style: TextStyle(fontWeight: FontWeight.w800, color: done ? C.ok : C.ink))),
      ]),
    );
  }
}
