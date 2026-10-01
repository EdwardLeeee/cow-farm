import 'package:cowfarm/state/game_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

FilledButton _btn(WidgetTester tester, String key) =>
    tester.widget<FilledButton>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(FilledButton)));

Future<void> _openShop(WidgetTester tester, GameModel m) async {
  await pumpApp(tester, m);
  m.selectTab(AppTab.shop);
  await tester.pump();
  await tester.pump(); // 等 GET /v1/shop
}

void main() {
  testWidgets('商店（S19）：三個等級，各自顯示價格與用途、公母、稀有度機率', (tester) async {
    final (m, api, _) = await loadedModel();
    await _openShop(tester, m);
    expect(api.calls, contains('shop'));
    expect(find.text('買 A 級（3,200 幣）'), findsOneWidget);
    expect(find.text('買 B 級（1,700 幣）'), findsOneWidget);
    expect(find.text('買 C 級（900 幣）'), findsOneWidget);
    // 金幣 1,500：只買得起 C
    expect(_btn(tester, 'buy-grade-A').onPressed, isNull);
    expect(_btn(tester, 'buy-grade-B').onPressed, isNull);
    expect(_btn(tester, 'buy-grade-C').onPressed, isNotNull);
    expect(find.text('用途：乳牛 45.0%、耕牛 27.5%、肉牛 27.5%'), findsNWidgets(3));
    expect(find.text('公母：公 50.0%、母 50.0%'), findsNWidgets(3));
    expect(find.text('稀有度：一般 90.0%、優良 8.0%、稀有 1.5%、傳說 0.5%'), findsOneWidget); // C
    expect(find.text('稀有度：一般 50.0%、優良 40.0%、稀有 7.5%、傳說 2.5%'), findsOneWidget); // A
  });

  testWidgets('買 C 級之後顯示抽到的牛', (tester) async {
    final (m, api, _) = await loadedModel();
    await _openShop(tester, m);
    await tester.tap(find.byKey(const Key('buy-grade-C')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(api.calls, contains('shop-buy:C'));
    expect(find.byKey(const Key('drawn-cow')), findsOneWidget);
    expect(find.text('C 級抽到的牛'), findsOneWidget);
    expect(find.text('肉牛・公・稀有（牛 #6）'), findsOneWidget);
    await tester.tap(find.byKey(const Key('drawn-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('drawn-cow')), findsNothing);
  });

  testWidgets('升級：顯示效果與費用；錢不夠或滿級就停用', (tester) async {
    final (m, api, _) = await loadedModel();
    await _openShop(tester, m);
    await tester.scrollUntilVisible(find.byKey(const Key('up-fresh')), 200);
    expect(find.text('目前 1 級・6 → 7 格・420 幣'), findsOneWidget);
    expect(find.text('目前 0 級・容量 24 → 36・200 幣'), findsOneWidget);
    expect(find.text('目前 0 級・容量 150 → 225・5,000 幣・金幣不夠'), findsOneWidget);
    expect(find.text('目前 4 級・已滿級'), findsOneWidget);
    expect(_btn(tester, 'up-warehouse').onPressed, isNull);
    expect(_btn(tester, 'up-fresh').onPressed, isNull);
    await tester.tap(find.byKey(const Key('up-bucket')));
    await tester.pump();
    await tester.pump();
    expect(api.calls, contains('upgrade:bucket'));
  });

  testWidgets('牛舍滿了不能買', (tester) async {
    final (m, _, _) = await loadedModel(api: FakeGameApi(state: sampleStateJson(penFull: true, coins: 9999)));
    await _openShop(tester, m);
    expect(_btn(tester, 'buy-grade-C').onPressed, isNull);
    expect(find.text('牛舍滿了，先擴建或出貨'), findsOneWidget);
  });
}
