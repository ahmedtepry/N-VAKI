import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../core/api.dart';
import '../core/app.dart';
import '../core/common.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/garment.dart';
import 'dash_import.dart';

const palette = [
  ['أسود', 'Black', '#141414'],
  ['أبيض', 'White', '#F4F4F2'],
  ['رمادي', 'Grey', '#9AA0A6'],
  ['كحلي', 'Navy', '#1B2A49'],
  ['أزرق', 'Blue', '#1F4FD8'],
  ['سماوي', 'Sky', '#9DB9DE'],
  ['أخضر زيتي', 'Olive', '#4C5A3A'],
  ['أخضر', 'Green', '#1E9E48'],
  ['أصفر', 'Yellow', '#F2C318'],
  ['برتقالي', 'Orange', '#F26B21'],
  ['أحمر', 'Red', '#D92D20'],
  ['بوردو', 'Burgundy', '#6D1F2F'],
  ['بني', 'Brown', '#6B4A36'],
  ['رملي', 'Sand', '#CDB89A'],
  ['كريمي', 'Cream', '#EFE6D2'],
  ['وردي', 'Pink', '#E8A6B6'],
];

const garments = {
  'tee': ['تيشيرت', 'Tee', 'tees'],
  'jersey': ['جيرسي', 'Jersey', 'jerseys'],
  'hoodie': ['هودي', 'Hoodie', 'hoodies'],
  'jacket': ['جاكيت', 'Jacket', 'jackets'],
  'shirt': ['قميص', 'Shirt', 'shirts'],
};

// ===================================================== CATALOG =====================================================
class CatalogTab extends StatefulWidget {
  const CatalogTab();
  @override
  State<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<CatalogTab> {
  List<Product>? items;
  Object? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.products(all: true);
      if (mounted) setState(() {
            items = r;
            error = null;
          });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _open(Product? p) async {
    await Navigator.of(context).push(fadeRoute(ProductEditScreen(product: p)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (App.i.can('catalog_edit'))
          FloatingActionButton.small(
            heroTag: 'import',
            backgroundColor: C.card,
            foregroundColor: C.ink,
            elevation: 0,
            shape: CircleBorder(side: BorderSide(color: C.ink)),
            tooltip: tr('استيراد من إكسيل', 'Import from Excel'),
            onPressed: () async {
              await Navigator.of(context).push(fadeRoute(const ImportScreen()));
              _load();
            },
            child: const Icon(Icons.upload_file_rounded),
          ),
        const SizedBox(height: 10),
        FloatingActionButton.extended(
        heroTag: 'new',
        backgroundColor: C.neon,
        foregroundColor: C.onNeon,
        elevation: 0,
        shape: StadiumBorder(side: BorderSide(color: C.ink)),
        onPressed: () => _open(null),
        icon: const Icon(Icons.add),
        label: Text(tr('منتج جديد', 'NEW PRODUCT'), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        ),
      ]),
      body: error != null
          ? ErrorRetry(error!, _load)
          : items == null
              ? const Loading()
              : items!.isEmpty
                  ? Empty(tr('مفيش منتجات. ضيف أول منتج.', 'No products yet. Add the first one.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: C.ink,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                        itemCount: items!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final p = items![i];
                          final c = p.colors.isEmpty ? null : p.colors.first;
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _open(p),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
                              child: Row(children: [
                                SizedBox(width: 54, child: GarmentView(garment: p.garment, color: c == null ? C.mute : hexColor(c.hex), accent: c?.accent == null ? null : hexColor(c!.accent!), width: 46, shadow: false)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(p.name, style: TextStyle(fontWeight: FontWeight.w800, color: p.active ? C.ink : C.mute)),
                                    const SizedBox(height: 2),
                                    Text('${money(p.price)}  ·  ${tr('مخزون', 'stock')} ${p.totalStock}', style: TextStyle(fontSize: 12, color: p.totalStock <= 5 ? C.warn : C.mute)),
                                  ]),
                                ),
                                if (!p.active) StatusChip(tr('مخفي', 'Hidden'), C.mute),
                                Icon(Icons.chevron_right_rounded, color: C.mute),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class ProductEditScreen extends StatefulWidget {
  final Product? product;
  const ProductEditScreen({this.product});
  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  final key = GlobalKey<FormState>();
  late final nameAr = TextEditingController(text: widget.product?.nameAr ?? '');
  late final nameEn = TextEditingController(text: widget.product?.nameEn ?? '');
  late final descAr = TextEditingController(text: widget.product?.descAr ?? '');
  late final descEn = TextEditingController(text: widget.product?.descEn ?? '');
  late final price = TextEditingController(text: widget.product == null ? '' : widget.product!.price.round().toString());
  late final compare = TextEditingController(text: widget.product?.compareAt == null ? '' : widget.product!.compareAt!.round().toString());
  late String garment = widget.product?.garment ?? 'tee';
  late String category = widget.product?.category ?? (App.i.categories.isNotEmpty ? '${App.i.categories.first['slug']}' : 'tees');
  late bool active = widget.product?.active ?? true;
  late bool featured = widget.product?.featured ?? false;
  Product? p;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    p = widget.product;
  }

  @override
  void dispose() {
    for (final c in [nameAr, nameEn, descAr, descEn, price, compare]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _reload() async {
    if (p == null) return;
    try {
      final all = await Api.products(all: true);
      final f = all.where((e) => e.id == p!.id);
      if (f.isNotEmpty && mounted) setState(() => p = f.first);
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!key.currentState!.validate()) return;
    setState(() => busy = true);
    final body = {
      'name_ar': nameAr.text.trim(),
      'name_en': nameEn.text.trim(),
      'description_ar': descAr.text.trim(),
      'description_en': descEn.text.trim(),
      'price': double.parse(price.text.trim()),
      'compare_at_price': compare.text.trim().isEmpty ? null : double.parse(compare.text.trim()),
      'garment': garment,
      'category': category,
      'active': active,
      'featured': featured,
    };
    try {
      if (p == null) {
        final row = await App.i.db.from('products').insert(body).select().single();
        final np = Product.fromJson({...Json.from(row), 'product_variants': []});
        if (mounted) setState(() => p = np);
        toast(tr('اتحفظ. ضيف الألوان والمقاسات.', 'Saved. Now add colours and sizes.'));
      } else {
        await App.i.db.from('products').update(body).eq('id', p!.id);
        toast(tr('اتحفظ ✓', 'Saved ✓'));
      }
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _addColor() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _AddColorSheet(product: p!),
    );
    if (added == true) _reload();
  }

  Future<void> _stock(Variant v, int delta) async {
    final n = (v.stock + delta).clamp(0, 9999);
    if (n == v.stock) return;
    if (!App.i.can('stock_edit')) {
      toast(tr('مفيش صلاحية لتعديل المخزون', 'No permission to edit stock'));
      return;
    }
    try {
      await App.i.db.from('product_variants').update({'stock': n}).eq('id', v.id);
      setState(() => v.stock = n);
    } catch (e) {
      toastError(e);
    }
  }

  Future<void> _photo(Variant c) async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1400, imageQuality: 85);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final path = 'products/${p!.id}/${c.hex.substring(1)}-${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bucket = App.i.db.storage.from('novaki-products');
      await bucket.uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
      final url = bucket.getPublicUrl(path);
      await App.i.db.from('product_variants').update({'image_url': url}).eq('product_id', p!.id).eq('color_hex', c.hex);
      toast(tr('اتحطت الصورة ✓', 'Photo added ✓'));
      _reload();
    } catch (e) {
      toastError(e);
    }
  }

  Future<void> _removePhoto(Variant c) async {
    try {
      await App.i.db.from('product_variants').update({'image_url': null}).eq('product_id', p!.id).eq('color_hex', c.hex);
      _reload();
    } catch (e) {
      toastError(e);
    }
  }

  Future<void> _deleteColor(Variant c) async {
    if (!await confirmDialog(context, tr('تحذف اللون ده؟', 'Delete this colour?'), body: c.color)) return;
    try {
      await App.i.db.from('product_variants').delete().eq('product_id', p!.id).eq('color_hex', c.hex);
      _reload();
    } catch (e) {
      toastError(e);
    }
  }

  Future<void> _deleteProduct() async {
    if (!await confirmDialog(context, tr('تحذف المنتج نهائيًا؟', 'Delete this product?'), body: tr('الأفضل تخفيه بدل ما تحذفه.', 'Hiding it is usually better than deleting.'))) return;
    try {
      await App.i.db.from('products').delete().eq('id', p!.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      toastError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pr = p;
    return Scaffold(
      appBar: AppBar(title: Text(widget.product == null && pr == null ? tr('منتج جديد', 'NEW PRODUCT') : tr('تعديل المنتج', 'EDIT PRODUCT')), actions: [
        if (pr != null) IconButton(onPressed: _deleteProduct, icon: const Icon(Icons.delete_outline, color: C.danger)),
      ]),
      body: Form(
        key: key,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
          TextFormField(controller: nameAr, decoration: InputDecoration(labelText: tr('الاسم بالعربي', 'Name (Arabic)')), validator: (v) => (v ?? '').trim().length < 2 ? tr('مطلوب', 'Required') : null),
          TextFormField(controller: nameEn, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: tr('الاسم بالإنجليزي', 'Name (English)')), validator: (v) => (v ?? '').trim().length < 2 ? tr('مطلوب', 'Required') : null),
          Row(children: [
            Expanded(child: TextFormField(controller: price, enabled: App.i.can('prices_edit'), keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('السعر', 'Price')), validator: (v) => double.tryParse((v ?? '').trim()) == null ? tr('رقم', 'Number') : null)),
            const SizedBox(width: 16),
            Expanded(child: TextFormField(controller: compare, enabled: App.i.can('prices_edit'), keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('السعر قبل الخصم', 'Compare-at')), validator: (v) => (v ?? '').trim().isEmpty || double.tryParse(v!.trim()) != null ? null : tr('رقم', 'Number'))),
          ]),
          TextFormField(controller: descAr, maxLines: 2, decoration: InputDecoration(labelText: tr('الوصف بالعربي', 'Description (Arabic)'))),
          TextFormField(controller: descEn, maxLines: 2, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: tr('الوصف بالإنجليزي', 'Description (English)'))),
          const SizedBox(height: 16),
          Text(tr('النوع', 'GARMENT'), style: TextStyle(fontSize: 11, color: C.mute, letterSpacing: 1.4)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in garments.entries)
              ChoiceChip(
                label: Text(tr(e.value[0], e.value[1]), style: TextStyle(fontWeight: FontWeight.w800, color: garment == e.key ? C.ink : C.mute)),
                selected: garment == e.key,
                selectedColor: C.tint,
                backgroundColor: C.card,
                showCheckmark: false,
                side: BorderSide(color: garment == e.key ? C.ink : C.line),
                onSelected: (_) => setState(() => garment = e.key),
              ),
          ]),
          const SizedBox(height: 12),
          Text(tr('القسم', 'CATEGORY'), style: TextStyle(fontSize: 11, color: C.mute, letterSpacing: 1.4)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in App.i.categories)
              ChoiceChip(
                label: Text(tr('${c['name_ar']}', '${c['name_en']}'), style: TextStyle(fontWeight: FontWeight.w800, color: category == c['slug'] ? C.ink : C.mute)),
                selected: category == c['slug'],
                selectedColor: C.tint,
                backgroundColor: C.card,
                showCheckmark: false,
                side: BorderSide(color: category == c['slug'] ? C.ink : C.line),
                onSelected: (_) => setState(() => category = '${c['slug']}'),
              ),
          ]),
          SwitchListTile(contentPadding: EdgeInsets.zero, activeColor: C.ink, activeTrackColor: C.neon, title: Text(tr('ظاهر في المتجر', 'Visible in store')), value: active, onChanged: (v) => setState(() => active = v)),
          SwitchListTile(contentPadding: EdgeInsets.zero, activeColor: C.ink, activeTrackColor: C.neon, title: Text(tr('مميّز', 'Featured')), value: featured, onChanged: (v) => setState(() => featured = v)),
          const SizedBox(height: 8),
          NeonButton(tr('حفظ', 'Save'), onPressed: _save, loading: busy),
          if (pr != null) ...[
            const SizedBox(height: 28),
            Row(children: [
              Text(tr('الألوان والمخزون', 'COLOURS & STOCK'), style: TextStyle(fontSize: 11, color: C.mute, letterSpacing: 1.4, fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton.icon(onPressed: _addColor, icon: Icon(Icons.add, size: 18, color: C.ink), label: Text(tr('لون', 'Colour'), style: TextStyle(color: C.ink, fontWeight: FontWeight.w800))),
            ]),
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(tr('تقدر ترفع صورة حقيقية لكل لون (القطعة كاملة على خلفية بيضاء). هتتعلق على الشماعة بدل الرسم.', 'Upload a real photo per colour (whole garment on a white background). It will hang on the rack instead of the drawing.'), style: TextStyle(color: C.mute, fontSize: 12, height: 1.4))),
            if (pr.colors.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(tr('ضيف لون عشان المنتج يظهر في المتجر.', 'Add a colour so the product shows up in the store.'), style: const TextStyle(color: C.warn))),
            for (final c in pr.colors)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 18, height: 18, decoration: BoxDecoration(color: hexColor(c.hex), shape: BoxShape.circle, border: Border.all(color: C.ink.withValues(alpha: 0.3)))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(c.color, style: const TextStyle(fontWeight: FontWeight.w800))),
                    if (c.image != null)
                      IconButton(visualDensity: VisualDensity.compact, tooltip: tr('شيل الصورة', 'Remove photo'), onPressed: () => _removePhoto(c), icon: Icon(Icons.hide_image_outlined, size: 19, color: C.mute)),
                    IconButton(visualDensity: VisualDensity.compact, tooltip: tr('صورة', 'Photo'), onPressed: () => _photo(c), icon: Icon(c.image != null ? Icons.image : Icons.add_photo_alternate_outlined, size: 20, color: c.image != null ? C.ok : C.ink)),
                    IconButton(visualDensity: VisualDensity.compact, onPressed: () => _deleteColor(c), icon: Icon(Icons.close, size: 18, color: C.mute)),
                  ]),
                  for (final v in pr.sizesFor(c.hex))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        SizedBox(width: 44, child: Text(v.size, style: const TextStyle(fontWeight: FontWeight.w800))),
                        _step(Icons.remove, () => _stock(v, -1)),
                        SizedBox(width: 48, child: Center(child: Text('${v.stock}', style: TextStyle(fontWeight: FontWeight.w900, color: v.stock <= 3 ? C.warn : C.ink)))),
                        _step(Icons.add, () => _stock(v, 1)),
                        const SizedBox(width: 10),
                        _step(null, () => _stock(v, 10), label: '+10'),
                      ]),
                    ),
                ]),
              ),
          ],
        ]),
      ),
    );
  }

  Widget _step(IconData? i, VoidCallback f, {String? label}) => InkWell(
        onTap: f,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minWidth: 30),
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: C.ink, width: 1)),
          child: i != null ? Icon(i, size: 16) : Text(label ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
        ),
      );
}

class _AddColorSheet extends StatefulWidget {
  final Product product;
  const _AddColorSheet({required this.product});
  @override
  State<_AddColorSheet> createState() => _AddColorSheetState();
}

class _AddColorSheetState extends State<_AddColorSheet> {
  int? sel;
  int? acc;
  final sizes = <String>{'S', 'M', 'L', 'XL'};
  List<String> sizeChoices = const ['XS', 'S', 'M', 'L', 'XL', 'XXL'];

  @override
  void initState() {
    super.initState();
    Api.sizes().then((r) {
      if (mounted && r.isNotEmpty) setState(() => sizeChoices = r.map((e) => '${e['code']}').toList());
    }).catchError((_) {});
  }
  final stock = TextEditingController(text: '10');
  bool busy = false;

  @override
  void dispose() {
    stock.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (sel == null || sizes.isEmpty) {
      toast(tr('اختار لون ومقاس واحد على الأقل', 'Pick a colour and at least one size'));
      return;
    }
    final c = palette[sel!];
    final n = int.tryParse(stock.text.trim()) ?? 0;
    setState(() => busy = true);
    try {
      await App.i.db.from('product_variants').insert([
        for (final s in sizes)
          {
            'product_id': widget.product.id,
            'color_name_ar': c[0],
            'color_name_en': c[1],
            'color_hex': c[2],
            'accent_hex': acc == null ? null : palette[acc!][2],
            'size': s,
            'stock': n,
          }
      ]);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      toastError(e);
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _swatches(int? current, void Function(int?) onPick, {bool none = false}) => Wrap(spacing: 10, runSpacing: 10, children: [
        if (none)
          GestureDetector(
            onTap: () => onPick(null),
            child: Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: current == null ? C.ink : C.line, width: current == null ? 2 : 1)), child: Icon(Icons.block, size: 16, color: C.mute)),
          ),
        for (var i = 0; i < palette.length; i++)
          GestureDetector(
            onTap: () => onPick(i),
            child: Container(width: 34, height: 34, decoration: BoxDecoration(color: hexColor(palette[i][2]), shape: BoxShape.circle, border: Border.all(color: current == i ? C.ink : C.line, width: current == i ? 2.4 : 1))),
          ),
      ]);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 18, 22, MediaQuery.of(context).viewInsets.bottom + 22),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(tr('إضافة لون', 'ADD COLOUR'), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.4)),
          const SizedBox(height: 14),
          _swatches(sel, (v) => setState(() => sel = v)),
          if (sel != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(tr(palette[sel!][0], palette[sel!][1]), style: TextStyle(color: C.mute))),
          const SizedBox(height: 18),
          Text(tr('لون التفاصيل (اختياري)', 'Accent colour (optional)'), style: TextStyle(fontSize: 12, color: C.mute)),
          const SizedBox(height: 8),
          _swatches(acc, (v) => setState(() => acc = v), none: true),
          const SizedBox(height: 18),
          Text(tr('المقاسات', 'Sizes'), style: TextStyle(fontSize: 12, color: C.mute)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final s in sizeChoices)
              FilterChip(
                label: Text(s, style: const TextStyle(fontWeight: FontWeight.w800)),
                selected: sizes.contains(s),
                selectedColor: C.tint,
                backgroundColor: C.card,
                showCheckmark: false,
                side: BorderSide(color: sizes.contains(s) ? C.ink : C.line),
                onSelected: (v) => setState(() => v ? sizes.add(s) : sizes.remove(s)),
              ),
          ]),
          TextField(controller: stock, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('المخزون لكل مقاس', 'Stock per size'))),
          const SizedBox(height: 20),
          NeonButton(tr('إضافة', 'Add'), onPressed: _save, loading: busy),
        ]),
      ),
    );
  }
}

