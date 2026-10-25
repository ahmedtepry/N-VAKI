import 'package:flutter/material.dart';

/// Every permission the owner can switch on or off for a team member.
class PermInfo {
  final String key, ar, en, hintAr, hintEn;
  final IconData icon;
  const PermInfo(this.key, this.ar, this.en, this.hintAr, this.hintEn, this.icon);
}

const permCatalog = [
  PermInfo('orders_view', 'مشاهدة الطلبات', 'View orders', 'يشوف الطلبات وتفاصيلها', 'See orders and details', Icons.inventory_2_outlined),
  PermInfo('orders_manage', 'إدارة الطلبات', 'Manage orders', 'يؤكد ويشحن ويلغي ويبعت تحديثات للعميل', 'Confirm, ship, cancel and post updates', Icons.local_shipping_outlined),
  PermInfo('chat', 'خدمة العملاء (الشات)', 'Customer chat', 'يرد على محادثات العملاء', 'Reply to customer conversations', Icons.forum_outlined),
  PermInfo('catalog_edit', 'تعديل المنتجات', 'Edit products', 'يضيف ويعدّل ويحذف منتجات وألوان وصور', 'Add, edit and delete products, colours, photos', Icons.checkroom_outlined),
  PermInfo('prices_edit', 'تعديل الأسعار', 'Edit prices', 'يغيّر السعر والسعر قبل الخصم', 'Change price and compare-at price', Icons.sell_outlined),
  PermInfo('stock_edit', 'تعديل المخزون', 'Edit stock', 'يزوّد وينقّص الكميات', 'Increase and decrease quantities', Icons.warehouse_outlined),
  PermInfo('categories_edit', 'إدارة الأقسام', 'Manage categories', 'يضيف ويشيل أقسام المتجر', 'Add and remove store sections', Icons.category_outlined),
  PermInfo('sizes_edit', 'إدارة المقاسات', 'Manage sizes', 'يضيف ويشيل مقاسات', 'Add and remove sizes', Icons.straighten_outlined),
  PermInfo('coupons_edit', 'الكوبونات', 'Coupons', 'ينشئ ويوقف كوبونات الخصم', 'Create and stop discount coupons', Icons.confirmation_number_outlined),
  PermInfo('settings_edit', 'إعدادات المتجر', 'Store settings', 'الشحن، ساعات الدعم، الشريط، قفل المتجر', 'Shipping, support hours, ticker, close store', Icons.tune_rounded),
  PermInfo('customers_view', 'مشاهدة العملاء', 'View customers', 'يشوف قائمة العملاء وإجمالي مشترياتهم', 'See the customer list and spending', Icons.people_outline_rounded),
  PermInfo('customers_block', 'حظر العملاء', 'Block customers', 'يحظر عميل أو يرجّعه', 'Block or unblock a customer', Icons.block_outlined),
  PermInfo('reports_view', 'التقارير والمبيعات', 'Reports & sales', 'يشوف المبيعات والإيرادات', 'See sales and revenue', Icons.insights_rounded),
  PermInfo('drivers_assign', 'توزيع الطلبات على السواقين', 'Assign drivers', 'يحدد السائق المسؤول عن كل طلب', 'Choose the driver for each order', Icons.two_wheeler_outlined),
  PermInfo('driver', 'سائق توصيل', 'Delivery driver', 'يشوف الطلبات المسلّمة له ويحدّث التوصيل ويشارك موقعه', 'Sees orders assigned to him, updates delivery and shares his location', Icons.delivery_dining_outlined),
];

PermInfo? permInfo(String key) {
  for (final p in permCatalog) {
    if (p.key == key) return p;
  }
  return null;
}
