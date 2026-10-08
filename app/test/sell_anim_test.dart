// A-02 成交（設計稿 anims.js 的 A02，1.4 秒）：金幣從「確認賣出」飛向頂列、頂列的金幣往上跳（膠囊放大一下）、第 1.0 秒提示淡入。
// 減少動態時金幣不飛、數字直接變、提示淡入 0.2 秒。逐格的畫面在 test/pages/anim_shots_test.dart。
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/app.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/kit/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'pages/page_case.dart';
import 'pages/s05_cases.dart' show milkLot;
import 'pages/s06_cases.dart';

/// 市場、選好牛奶、拉到 130 瓶、捲到「確認賣出」（設計稿：賣出後 14,404 幣、剩 16 瓶）。開著動畫。
Future<GameModel> showSellWithMotion(WidgetTester tester, {bool reduced = false}) async {
  final api = MarketApi(answers: designAnswers)..afterSell = marketState(milk: [milkLot(16, 0, 1.0, 1)], coins: 14404);
  final (m, _, _) = await loadedModel(api: api);
  m.selectMarket(Commodity.milk);
  m.selectTab(AppTab.market);
  final settings = settingsFor(AppLang.zhHant, swipeHintSeen);
  await settings.load();
  if (reduced) {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  await tester.pumpWidget(
    AppMotion(
      enabled: true,
      child: CowFarmApp(model: m, settings: settings),
    ),
  );
  await tester.pump();
  await tester.pump();
  await slideTo(tester, 130, 146);
  await tester.scrollUntilVisible(find.byKey(const Key('sell-confirm')), 150, scrollable: marketScroll);
  await tester.pump();
  return m;
}

String _hudCoins(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('hud-coins'))).data!;

double _toastOpacity(WidgetTester tester) {
  final o = find.ancestor(of: find.byKey(const Key('toast')), matching: find.byType(Opacity));
  return o.evaluate().isEmpty ? 1 : tester.widget<Opacity>(o.first).opacity;
}

final _coins = find.byWidgetPredicate(
  (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('sell-coin'),
);

void main() {
  setUpAll(loadAppAssets);
  final zh = Strings.forLang(AppLang.zhHant);
  final sold = zh.sold(qty: '130', unit: zh.unitMilk, avg: '14.8', total: '1,924');

  testWidgets('開著動畫：金幣在飛、頂列的金幣往上跳、提示第 1.0 秒才出來；1.4 秒以後 14,404', (tester) async {
    Screen.w390.apply(tester);
    await showSellWithMotion(tester);
    expect(_hudCoins(tester), '12,480');
    await tester.tap(find.byKey(const Key('sell-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_coins, findsNWidgets(6), reason: '第 0.5 秒六個金幣都在飛');
    expect(_hudCoins(tester), '12,480', reason: '第 0.5 秒才開始跳');
    expect(_toastOpacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 300));
    final mid = int.parse(_hudCoins(tester).replaceAll(',', ''));
    expect(mid, inExclusiveRange(12480, 14404), reason: '第 0.8 秒往上跳到一半多');
    expect(tester.widget<Text>(find.byKey(const Key('sell-qty'))).data, '130', reason: '第 1.0 秒前賣出面板還是賣出前的樣子');
    await tester.pump(const Duration(milliseconds: 700));
    expect(_coins, findsNothing);
    expect(_hudCoins(tester), '14,404');
    expect(find.text(sold), findsOneWidget);
    expect(_toastOpacity(tester), 1);
    expect(tester.widget<Text>(find.byKey(const Key('sell-qty'))).data, '16', reason: '跟 S06-13 一樣：剩 16 瓶、全部');
  });

  testWidgets('減少動態：金幣不飛，頂列直接是 14,404，提示淡入 0.2 秒', (tester) async {
    Screen.w390.apply(tester);
    await showSellWithMotion(tester, reduced: true);
    await tester.tap(find.byKey(const Key('sell-confirm')));
    await tester.pump();
    await tester.pump();
    expect(_coins, findsNothing);
    expect(_hudCoins(tester), '14,404');
    expect(find.text(sold), findsOneWidget);
    expect(_toastOpacity(tester), lessThan(1));
    await tester.pump(const Duration(milliseconds: 250));
    expect(_toastOpacity(tester), 1);
  });
}
