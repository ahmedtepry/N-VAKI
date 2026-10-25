import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app.dart';

Color hexColor(String h) {
  var s = h.replaceAll('#', '');
  if (s.length == 6) s = 'FF$s';
  return Color(int.parse(s, radix: 16));
}

Color shade(Color c, double amt) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness + amt).clamp(0.0, 1.0)).toColor();
}

bool isDark(Color c) => c.computeLuminance() < 0.35;

String money(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '$b ${tr('ج.م', 'EGP')}';
}

double toD(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int toI(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

class Variant {
  final String id, colorAr, colorEn, hex, size;
  final String? accent, image;
  int stock;
  Variant({required this.id, required this.colorAr, required this.colorEn, required this.hex, required this.size, this.accent, this.image, required this.stock});
  factory Variant.fromJson(Map<String, dynamic> j) => Variant(
        id: j['id'],
        colorAr: j['color_name_ar'],
        colorEn: j['color_name_en'],
        hex: (j['color_hex'] as String).toUpperCase(),
        size: j['size'],
        accent: j['accent_hex'],
        image: j['image_url'],
        stock: toI(j['stock']),
      );
  String get color => tr(colorAr, colorEn);
}

const sizeOrder = ['XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL'];
int _sizeRank(String s) {
  final i = sizeOrder.indexOf(s.toUpperCase());
  return i < 0 ? 100 : i;
}

class Product {
  final String id, nameAr, nameEn, descAr, descEn, category, garment;
  final double price;
  final double? compareAt;
  final bool featured, active;
  final int sort;
  final List<Variant> variants;
  Product({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.descAr,
    required this.descEn,
    required this.category,
    required this.garment,
    required this.price,
    this.compareAt,
    required this.featured,
    required this.active,
    required this.sort,
    required this.variants,
  });
  factory Product.fromJson(Map<String, dynamic> j) {
    final vs = ((j['product_variants'] as List?) ?? []).map((e) => Variant.fromJson(Map<String, dynamic>.from(e))).toList();
    vs.sort((a, b) {
      final c = _sizeRank(a.size).compareTo(_sizeRank(b.size));
      return c != 0 ? c : a.size.compareTo(b.size);
    });
    return Product(
      id: j['id'],
      nameAr: j['name_ar'],
      nameEn: j['name_en'],
      descAr: j['description_ar'] ?? '',
      descEn: j['description_en'] ?? '',
      category: j['category'] ?? '',
      garment: j['garment'] ?? 'tee',
      price: toD(j['price']),
      compareAt: j['compare_at_price'] == null ? null : toD(j['compare_at_price']),
      featured: j['featured'] == true,
      active: j['active'] != false,
      sort: toI(j['sort']),
      variants: vs,
    );
  }
  String get name => tr(nameAr, nameEn);
  String get desc => tr(descAr, descEn);

  /// distinct colours in the order they first appear
  List<Variant> get colors {
    final seen = <String>{};
    final out = <Variant>[];
    for (final v in variants) {
      if (seen.add(v.hex)) out.add(v);
    }
    return out;
  }

  List<Variant> sizesFor(String hex) => variants.where((v) => v.hex == hex).toList();
  Variant? find(String hex, String size) {
    for (final v in variants) {
      if (v.hex == hex && v.size == size) return v;
    }
    return null;
  }

  int get totalStock => variants.fold(0, (a, v) => a + v.stock);
}

class CartLine {
  final String variantId, productId, nameAr, nameEn, colorAr, colorEn, hex, garment, size;
  final String? accent, image;
  final double price;
  int qty;
  CartLine({
    required this.variantId,
    required this.productId,
    required this.nameAr,
    required this.nameEn,
    required this.colorAr,
    required this.colorEn,
    required this.hex,
    required this.garment,
    required this.size,
    this.accent,
    this.image,
    required this.price,
    this.qty = 1,
  });
  factory CartLine.fromJson(Map<String, dynamic> j) => CartLine(
        variantId: j['variantId'],
        productId: j['productId'],
        nameAr: j['nameAr'],
        nameEn: j['nameEn'],
        colorAr: j['colorAr'],
        colorEn: j['colorEn'],
        hex: j['hex'],
        garment: j['garment'],
        size: j['size'],
        accent: j['accent'],
        image: j['image'],
        price: toD(j['price']),
        qty: toI(j['qty']),
      );
  Map<String, dynamic> toJson() => {
        'variantId': variantId,
        'productId': productId,
        'nameAr': nameAr,
        'nameEn': nameEn,
        'colorAr': colorAr,
        'colorEn': colorEn,
        'hex': hex,
        'garment': garment,
        'size': size,
        'accent': accent,
        'image': image,
        'price': price,
        'qty': qty,
      };
  String get name => tr(nameAr, nameEn);
  String get color => tr(colorAr, colorEn);
}

const orderStatuses = ['new', 'confirmed', 'packed', 'shipped', 'delivered', 'cancelled'];

String statusLabel(String s) {
  switch (s) {
    case 'new':
      return tr('طلب جديد', 'New');
    case 'confirmed':
      return tr('تم التأكيد', 'Confirmed');
    case 'packed':
      return tr('بنجهّز الطلب', 'Preparing');
    case 'shipped':
      return tr('في الطريق', 'Shipped');
    case 'delivered':
      return tr('تم استلام الطلب', 'Received');
    default:
      return tr('ملغي', 'Cancelled');
  }
}

Color statusColor(String s) {
  switch (s) {
    case 'new':
      return const Color(0xFFF79009);
    case 'confirmed':
      return const Color(0xFF2E90FA);
    case 'packed':
      return const Color(0xFF7A5AF8);
    case 'shipped':
      return const Color(0xFF06AED4);
    case 'delivered':
      return const Color(0xFF12B76A);
    default:
      return const Color(0xFFD92D20);
  }
}

String payLabel(String method, String status) {
  if (status == 'paid') return tr('تم الدفع', 'Paid');
  if (method == 'wallet') return status == 'sent' ? tr('محفظة · في انتظار التأكيد', 'Wallet · awaiting check') : tr('محفظة · في انتظار التحويل', 'Wallet · awaiting transfer');
  return tr('الدفع عند الاستلام', 'Cash on delivery');
}

Color payColor(String method, String status) {
  if (status == 'paid') return const Color(0xFF12B76A);
  if (method == 'wallet') return const Color(0xFFF79009);
  return const Color(0xFF86696C);
}

String roleLabel(String r) {
  switch (r) {
    case 'owner':
      return tr('المالك', 'Owner');
    case 'manager':
      return tr('مدير', 'Manager');
    case 'support':
      return tr('خدمة عملاء', 'Support');
    case 'fulfillment':
      return tr('تجهيز وشحن', 'Fulfillment');
    default:
      return tr('عميل', 'Customer');
  }
}

String two(int n) => n.toString().padLeft(2, '0');
String fmtDate(String? iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  return '${d.year}-${two(d.month)}-${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
}

double clampD(double v, double lo, double hi) => math.max(lo, math.min(hi, v));
