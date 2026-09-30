import 'package:cowfarm/state/game_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

FilledButton _btn(WidgetTester tester, String key) => tester.widget<FilledButton>(
  find.descendant(of: find.byKey(Key(key)), matching: find.byType(FilledButton)),
);

void main() {
  testWidgets('商店：六種小牛與四項升級，顯示費用；錢不夠或滿級就停用', (tester) async {
    final (m, api, _) = await loadedModel();
    await pumpApp(tester, m);
    m.selectTab(AppTab.shop);
    await tester.pump();

    for (final t in ['dairy', 'dual', 'beef']) {
      for (final s in ['cow', 'bull']) {
        expect(_btn(tester, 'buy-$t-$s').onPressed, isNotNull, reason: '$t $s');
      }
    }
    expect(find.textContaining('1,000 幣'), findsNWidgets(6));
    expect(_btn(tester, 'up-pen').onPressed, isNotNull);
    expect(_btn(tester, 'up-bucket').onPressed, isNotNull);
    expect(_btn(tester, 'up-warehouse').onPressed, isNull); // 5,000 > 1,500
    expect(find.text('目前 0 級・容量 150 → 225・5,000 幣・金幣不夠'), findsOneWidget);
    expect(find.text('目前 0 級・容量 24 → 36・200 幣'), findsOneWidget);
    expect(find.text('目前 1 級・4 → 5 格・420 幣'), findsOneWidget);
    expect(_btn(tester, 'up-fresh').onPressed, isNull); // 已滿級
    expect(find.text('目前 4 級・已滿級'), findsOneWidget);

    await tester.tap(find.byKey(const Key('buy-beef-bull')));
    await tester.pump();
    await tester.pump();
    expect(api.calls, contains('buy:beef:true'));

    await tester.tap(find.byKey(const Key('up-bucket')));
    await tester.pump();
    await tester.pump();
    expect(api.calls, contains('upgrade:bucket'));
  });

  testWidgets('錢不夠買小牛', (tester) async {
    final (m, _, _) = await loadedModel(api: FakeGameApi(state: sampleStateJson(coins: 500)));
    await pumpApp(tester, m);
    m.selectTab(AppTab.shop);
    await tester.pump();
    expect(_btn(tester, 'buy-dairy-cow').onPressed, isNull);
    expect(_btn(tester, 'up-bucket').onPressed, isNotNull); // 200 買得起
  });

  testWidgets('牛舍滿了不能買小牛', (tester) async {
    final (m, _, _) = await loadedModel(api: FakeGameApi(state: sampleStateJson(penFull: true)));
    await pumpApp(tester, m);
    m.selectTab(AppTab.shop);
    await tester.pump();
    expect(_btn(tester, 'buy-dairy-cow').onPressed, isNull);
    expect(find.text('牛舍滿了，先擴建或出貨'), findsOneWidget);
  });
}
