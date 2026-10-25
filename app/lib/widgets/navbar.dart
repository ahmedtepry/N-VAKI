import 'package:flutter/material.dart';
import '../core/app.dart';
import '../core/common.dart';
import '../core/theme.dart';
import '../screens/account.dart';
import '../screens/cart.dart';

/// Bottom bar: Home · Saved · Bag · Account. [current] highlights a tab (-1 = none).
/// On the home screen pass [onTap] to handle taps in place; elsewhere the default handler navigates.
class NavBar extends StatelessWidget {
  final int current;
  final ValueChanged<int>? onTap;
  const NavBar({this.current = -1, this.onTap});

  void _go(BuildContext context, int i) {
    if (onTap != null) return onTap!(i);
    final nav = Navigator.of(context);
    switch (i) {
      case 0:
        nav.popUntil((r) => r.isFirst);
        break;
      case 1:
        App.i.showSaved();
        nav.popUntil((r) => r.isFirst);
        break;
      case 2:
        if (current != 2) nav.pushReplacement(fadeRoute(const CartScreen()));
        break;
      case 3:
        if (current != 3) nav.pushReplacement(fadeRoute(const AccountScreen()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = <List<Object>>[
      [Icons.home_outlined, Icons.home_rounded, tr('الرئيسية', 'Home')],
      [Icons.favorite_border_rounded, Icons.favorite_rounded, tr('المفضلة', 'Saved')],
      [Icons.shopping_bag_outlined, Icons.shopping_bag_rounded, tr('الشنطة', 'Bag')],
      [Icons.person_outline_rounded, Icons.person_rounded, tr('حسابي', 'Account')],
    ];
    return Container(
      decoration: BoxDecoration(color: C.bg, border: Border(top: BorderSide(color: C.line))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: InkResponse(
                  onTap: () => _go(context, i),
                  radius: 36,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                      decoration: BoxDecoration(color: current == i ? C.tint : Colors.transparent, borderRadius: BorderRadius.circular(20)),
                      child: Badge2(i == 2 ? App.i.cartCount : 0, Icon(current == i ? items[i][1] as IconData : items[i][0] as IconData, size: 23, color: current == i ? C.neon : C.ink)),
                    ),
                    const SizedBox(height: 2),
                    Text(items[i][2] as String, style: TextStyle(fontSize: 10.5, fontWeight: current == i ? FontWeight.w900 : FontWeight.w600, color: current == i ? C.neon : C.mute)),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
