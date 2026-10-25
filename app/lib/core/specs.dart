import 'app.dart';

/// Default fabric + measurement data per garment type (shown on the product page).
/// Measurements are flat garment measurements in cm, +/- 1-2 cm.
class SizeSpec {
  final String size;
  final double chest, length, shoulder, sleeve;
  final String height, weight;
  const SizeSpec(this.size, this.chest, this.length, this.shoulder, this.sleeve, this.height, this.weight);
}

const _order = ['XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL'];
const _heights = {
  'XS': ['155-165', '48-58'],
  'S': ['160-170', '55-68'],
  'M': ['168-176', '65-78'],
  'L': ['174-182', '75-88'],
  'XL': ['180-188', '85-98'],
  'XXL': ['185-195', '95-110'],
  '3XL': ['190-200', '105-125'],
};
// chest, length, shoulder, sleeve at size M
const _base = {
  'tee': [54.0, 71.0, 47.0, 21.0],
  'jersey': [53.0, 73.0, 46.0, 22.0],
  'hoodie': [58.0, 69.0, 52.0, 62.0],
  'jacket': [57.0, 70.0, 50.0, 63.0],
  'shirt': [55.0, 74.0, 46.0, 63.0],
};

SizeSpec? sizeSpec(String garment, String size) {
  final i = _order.indexOf(size.toUpperCase());
  if (i < 0) return null;
  final b = _base[garment] ?? _base['tee']!;
  final d = (i - 2).toDouble();
  final hw = _heights[_order[i]]!;
  return SizeSpec(_order[i], b[0] + 2 * d, b[1] + 2 * d, b[2] + 1.5 * d, b[3] + 1 * d, hw[0], hw[1]);
}

class FabricInfo {
  final String material, weight, fit, care;
  const FabricInfo(this.material, this.weight, this.fit, this.care);
}

FabricInfo fabricFor(String garment) {
  switch (garment) {
    case 'jersey':
      return FabricInfo(tr('بوليستر دراي-فيت بيتنفّس', 'Breathable dry-fit polyester'), '150 g/m²', tr('قصّة رياضية مريحة', 'Athletic relaxed fit'), tr('غسيل بارد 30°، من غير مكوى مباشر على الطباعة', 'Cold wash 30°, no direct iron on print'));
    case 'hoodie':
      return FabricInfo(tr('قطن وبوليستر فليس مبطّن من جوّه', 'Cotton-poly fleece, brushed inside'), '380 g/m²', tr('أوفر سايز مريح', 'Relaxed oversized'), tr('غسيل بارد 30° مقلوب، تنشيف في الظل', 'Cold wash 30° inside out, dry in shade'));
    case 'jacket':
      return FabricInfo(tr('خارجي بوليستر مقاوم للرياح وبطانة ناعمة', 'Wind-resistant polyester shell, soft lining'), '260 g/m²', tr('قصّة عادية بسوستة كاملة', 'Regular fit, full zip'), tr('غسيل بارد 30°، من غير مبيّض', 'Cold wash 30°, no bleach'));
    case 'shirt':
      return FabricInfo(tr('قطن بوبلين ناعم', 'Soft cotton poplin'), '120 g/m²', tr('قصّة عادية بأزرار', 'Regular fit, buttoned'), tr('غسيل 30° وكوي متوسط', 'Wash 30°, medium iron'));
    default:
      return FabricInfo(tr('قطن 100% ممشّط', '100% combed cotton'), '220 g/m²', tr('أوفر سايز مريح', 'Relaxed oversized'), tr('غسيل بارد 30° مقلوب، من غير مبيّض', 'Cold wash 30° inside out, no bleach'));
  }
}
