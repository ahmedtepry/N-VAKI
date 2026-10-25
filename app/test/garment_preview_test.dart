import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novaki/core/models.dart';
import 'package:novaki/widgets/garment.dart';

// Renders every garment type in a few colours to test/goldens/garments.png so the artwork can be reviewed.
void main() {
  for (final back in [false, true]) {
  testWidgets('garment preview back=$back', (tester) async {
    tester.view.physicalSize = const Size(1400, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    const items = [
      ['tee', '#141414', '#39FF14', '0'],
      ['tee', '#F4F4F2', '#141414', '0'],
      ['tee', '#CDB89A', '', '0.12'],
      ['jersey', '#F2C318', '#1E9E48', '0'],
      ['jersey', '#1F4FD8', '#F2C318', '-0.1'],
      ['hoodie', '#9AA0A6', '', '0'],
      ['hoodie', '#1B2A49', '', '0.1'],
      ['hoodie', '#EFE6D2', '', '0'],
      ['jacket', '#4C5A3A', '#EFE6D2', '0'],
      ['jacket', '#171717', '#E8FF00', '0'],
      ['shirt', '#9DB9DE', '', '0'],
      ['shirt', '#141414', '', '0'],
    ];
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: RepaintBoundary(
          key: key,
          child: Container(
            color: const Color(0xFFEBDAD7),
            padding: const EdgeInsets.all(16),
            child: Wrap(spacing: 12, runSpacing: 12, children: [
              for (final it in items)
                SizedBox(
                  width: 320,
                  height: 360,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: GarmentView(
                      garment: it[0],
                      color: hexColor(it[1]),
                      accent: it[2].isEmpty ? null : hexColor(it[2]),
                      width: 280,
                      swing: double.parse(it[3]),
                      back: back,
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    ));
    await tester.pump();
    await expectLater(find.byKey(key), matchesGoldenFile(back ? 'goldens/garments_back.png' : 'goldens/garments.png'));
  });
  }
}
