import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'api.dart' show Json;
import 'app.dart';
import 'common.dart';
import 'models.dart';

const _wine = PdfColor.fromInt(0xFF6E2A35);
const _rose = PdfColor.fromInt(0xFFEBDAD7);
const _grey = PdfColor.fromInt(0xFF6B5B5E);
const _line = PdfColor.fromInt(0xFFD4BCBA);

Future<(pw.Font, pw.Font)> _fonts() async => (await PdfGoogleFonts.tajawalRegular(), await PdfGoogleFonts.tajawalBold());

String _m(num v) => '${v.toStringAsFixed(v % 1 == 0 ? 0 : 2)} ج.م';

String _payText(Json o) {
  final wallet = o['payment_method'] == 'wallet';
  final st = o['payment_status'];
  if (st == 'paid') return wallet ? 'تم الدفع — محفظة إلكترونية على ${App.i.walletNumber}' : 'تم الدفع';
  if (wallet) return st == 'sent' ? 'محفظة — العميل بلّغ بالتحويل على ${App.i.walletNumber} (راجع الرصيد)' : 'محفظة — في انتظار التحويل على ${App.i.walletNumber}';
  return 'الدفع عند الاستلام — المطلوب تحصيله من العميل';
}

pw.Widget _kv(String k, String v, {pw.Font? bold}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(width: 78, child: pw.Text(k, style: const pw.TextStyle(color: _grey, fontSize: 11))),
        pw.Expanded(child: pw.Text(v, style: pw.TextStyle(font: bold, fontSize: 11))),
      ]),
    );

/// Order sheet for the team: customer, delivery, payment, driver, every item with a packing tick-box.
/// [staff] adds the packing checklist and internal notes; the customer copy is a plain invoice.
Future<Uint8List> orderInvoicePdf(Json o, {bool staff = true, String? driverName}) async {
  final (regular, bold) = await _fonts();
  final items = (o['order_items'] as List? ?? const []).map((e) => Json.from(e)).toList();
  final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));
  final hasPin = o['dest_lat'] != null && o['dest_lng'] != null;
  final pin = hasPin ? 'https://maps.google.com/?q=${o['dest_lat']},${o['dest_lng']}' : null;
  final disc = toD(o['discount']);
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    textDirection: pw.TextDirection.rtl,
    margin: const pw.EdgeInsets.all(28),
    build: (_) => [
      pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: const pw.BoxDecoration(color: _wine, borderRadius: pw.BorderRadius.all(pw.Radius.circular(10))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(staff ? 'أمر تجهيز طلب' : 'فاتورة', style: pw.TextStyle(font: bold, fontSize: 18, color: PdfColors.white)),
            pw.SizedBox(height: 4),
            pw.Text(fmtDate(o['created_at']), textDirection: pw.TextDirection.ltr, style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(App.i.brand, style: pw.TextStyle(font: bold, fontSize: 20, color: _rose)),
            pw.SizedBox(height: 4),
            pw.Text('#${o['order_no']}', textDirection: pw.TextDirection.ltr, style: pw.TextStyle(font: bold, fontSize: 14, color: PdfColors.white)),
          ]),
        ]),
      ),
      pw.SizedBox(height: 14),
      _kv('العميل', '${o['customer_name']}', bold: bold),
      _kv('الموبايل', '${o['phone']}'),
      _kv('العنوان', '${o['city']} — ${o['address']}'),
      if (pin != null) _kv('الموقع', 'محدد على الخريطة: $pin'),
      if ((o['notes'] ?? '').toString().isNotEmpty) _kv('ملاحظات', '${o['notes']}'),
      _kv('الدفع', _payText(o), bold: bold),
      if ((o['wallet_ref'] ?? '').toString().isNotEmpty) _kv('من رقم', '${o['wallet_ref']}'),
      _kv('الحالة', statusLabel('${o['status']}')),
      if (staff) _kv('السائق', driverName ?? (o['courier_name'] ?? 'لسه متحددش').toString(), bold: bold),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: [if (staff) '✓', 'المنتج', 'اللون', 'المقاس', 'الكمية', 'السعر', 'الإجمالي'],
        data: [
          for (final it in items)
            [
              if (staff) '☐',
              '${it['name_ar']}',
              '${it['color_name_ar']}',
              '${it['size']}',
              '${it['qty']}',
              _m(toD(it['unit_price'])),
              _m(toD(it['unit_price']) * toI(it['qty'])),
            ],
        ],
        headerStyle: pw.TextStyle(font: bold, color: PdfColors.white, fontSize: 11),
        headerDecoration: const pw.BoxDecoration(color: _wine),
        cellStyle: const pw.TextStyle(fontSize: 11),
        cellAlignment: pw.Alignment.centerRight,
        border: pw.TableBorder.all(color: _line),
        cellPadding: const pw.EdgeInsets.all(6),
      ),
      pw.SizedBox(height: 12),
      pw.Align(
        alignment: pw.Alignment.centerLeft,
        child: pw.SizedBox(
          width: 230,
          child: pw.Column(children: [
            _kv('المنتجات', _m(toD(o['subtotal']))),
            if (disc > 0) _kv('الخصم', '- ${_m(disc)}${o['coupon_code'] != null ? '  (${o['coupon_code']})' : ''}'),
            _kv('الشحن', toD(o['shipping_fee']) == 0 ? 'مجاني' : _m(toD(o['shipping_fee']))),
            pw.Divider(color: _line),
            _kv(o['payment_status'] == 'paid' ? 'الإجمالي (مدفوع)' : 'المطلوب تحصيله', _m(toD(o['total'])), bold: bold),
          ]),
        ),
      ),
      if (staff) ...[
        pw.SizedBox(height: 18),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _line), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
          child: pw.Text('☐ تم فحص القطع   ☐ تم التغليف   ☐ تم تسليمه للسائق   ☐ تم تحصيل المبلغ / تأكيد الدفع', style: const pw.TextStyle(fontSize: 11)),
        ),
      ],
      pw.SizedBox(height: 14),
      pw.Divider(color: _line),
      pw.Text('شكرًا لاختيارك ${App.i.brand}', style: const pw.TextStyle(color: _grey, fontSize: 10)),
    ],
  ));
  return doc.save();
}

/// Generate and open the share sheet (WhatsApp, Drive, print...).
Future<void> shareInvoice(Json order, {bool staff = true, String? driverName}) async {
  try {
    final bytes = await orderInvoicePdf(order, staff: staff, driverName: driverName);
    await Printing.sharePdf(bytes: bytes, filename: 'novaki-order-${order['order_no']}.pdf');
  } catch (e) {
    toast(tr('مقدرناش نجهّز الفاتورة. اتأكد من النت وجرّب تاني.', 'Could not build the invoice. Check your connection.'));
  }
}
