import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novaki/core/models.dart';
import 'package:novaki/widgets/rack.dart';

Product _p(int i, String g, String hex, String? acc) => Product(
      id: 'p$i',
      nameAr: 'x',
      nameEn: 'x',
      descAr: '',
      descEn: '',
      category: g,
      garment: g,
      price: 100,
      featured: false,
      active: true,
      sort: i,
      variants: [Variant(id: 'v$i', colorAr: 'a', colorEn: 'a', hex: hex, size: 'M', accent: acc, stock: 5)],
    );

void main() {
  testWidgets('rack preview', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    tester.view.physicalSize = const Size(1170, 1560);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final items = [
      _p(0, 'tee', '#141414', '#6E2A35'),
      _p(1, 'hoodie', '#9AA0A6', null),
      _p(2, 'jersey', '#F2C318', '#1E9E48'),
      _p(3, 'jacket', '#4C5A3A', '#EFE6D2'),
      _p(4, 'shirt', '#9DB9DE', null),
      _p(5, 'tee', '#F4F4F2', '#141414'),
      _p(6, 'hoodie', '#1B2A49', null),
    ];
    final k = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFEBDAD7),
        body: RepaintBoundary(key: k, child: Container(color: const Color(0xFFEBDAD7), padding: const EdgeInsets.only(top: 40), child: RackView(items: items, onFocus: (_) {}, onOpen: (_) {}))),
      ),
    ));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await expectLater(find.byKey(k), matchesGoldenFile('goldens/rack_rest.png'));
    // finger drags the hangers: capture while still touching
    final g = await tester.startGesture(const Offset(195, 300));
    for (var i = 0; i < 6; i++) {
      await g.moveBy(const Offset(-26, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await expectLater(find.byKey(k), matchesGoldenFile('goldens/rack_drag.png'));
    await g.up();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await expectLater(find.byKey(k), matchesGoldenFile('goldens/rack_after.png'));
  });
}
