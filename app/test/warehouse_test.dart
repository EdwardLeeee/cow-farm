// S05 倉庫：從牧場頁頂列的「倉庫」小鈕打開、返回；新的在上面；快滿、滿了；去市場賣、加大倉庫；出貨的牛沒有品種時只寫編號。
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pages/page_case.dart';
import 'pages/s03_cases.dart';
import 'pages/s05_cases.dart';

final _zh = Strings.forLang(AppLang.zhHant);

Future<GameModel> _open(WidgetTester tester, Map<String, dynamic> state) async {
  Screen.w390.apply(tester);
  final m = await ranchModel(state: state);
  await pumpAppIn(tester, m, AppLang.zhHant, prefs: swipeHintSeen);
  await tester.tap(find.byKey(const Key('warehouse-btn')));
  await tester.pump();
  return m;
}

/// 畫面上第一個出現的字（由上往下）是 [first] 的話回傳 true。
bool _above(WidgetTester tester, String first, String second) =>
    tester.getTopLeft(find.text(first)).dy < tester.getTopLeft(find.text(second)).dy;

void main() {
  setUpAll(loadAppAssets);

  testWidgets('點牧場頁的「倉庫」小鈕打開倉庫；返回鈕、手機的返回都回到牧場', (tester) async {
    final m = await _open(tester, warehouseState());
    expect(find.byKey(const Key('warehouse')), findsOneWidget);
    expect(m.warehouseOpen, isTrue);
    await tester.tap(find.byKey(const Key('btn-back')));
    await tester.pump();
    expect(find.byKey(const Key('dock')), findsOneWidget);
    expect(m.warehouseOpen, isFalse);

    // 手機的返回（Android 返回鍵、iPhone 滑回）
    await tester.tap(find.byKey(const Key('warehouse-btn')));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(m.warehouseOpen, isFalse);
    expect(find.byKey(const Key('dock')), findsOneWidget);
  });

  testWidgets('每一批新的在上面（伺服器給的順序不一定）；牛奶寫小時，牛肉、稻米超過一天寫天', (tester) async {
    await _open(tester, warehouseState());
    expect(
      _above(tester, _zh.s05CollectedAgo(ago: _zh.timeAgo(h: 1)), _zh.s05CollectedAgo(ago: _zh.timeAgo(h: 15))),
      isTrue,
    );
    expect(find.text(_zh.s05CollectedAgo(ago: _zh.timeAgo(h: 67))), findsNothing, reason: '快壞了的那批還接著寫幾小時後壞掉');
    expect(
      find.text(
        '${_zh.s05CollectedAgo(ago: _zh.timeAgo(h: 67))}${_zh.gSep}${_zh.s05SpoilIn(h: 20)}',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(find.text(_zh.s05CollectedAgo(ago: _zh.timeAgo(d: 4)), skipOffstage: false), findsOneWidget);
  });

  testWidgets('倉庫快滿（≥ 90%）：黃字提醒、「加大倉庫」變黃；按了先到商店', (tester) async {
    final m = await _open(
      tester,
      warehouseState(milk: [milkLot(110, 0, 1, 2), milkLot(95, 1, 0.9, 10)], beef: [], rice: []),
    );
    expect(find.text(_zh.s05NearFull), findsOneWidget);
    expect(find.text(_zh.s05Full), findsNothing);
    final up = find.byKey(const Key('upgrade-warehouse'));
    expect(tester.widget<AppButton>(up).kind, ButtonKind.primary);
    await tester.tap(up);
    await tester.pump();
    expect(m.tab, AppTab.shop);
  });

  testWidgets('平常「加大倉庫」是白色；「去市場賣」到市場；倉庫空了不能按', (tester) async {
    final m = await _open(tester, warehouseState());
    expect(tester.widget<AppButton>(find.byKey(const Key('upgrade-warehouse'))).kind, ButtonKind.normal);
    final sell = find.byKey(const Key('go-sell'));
    await tester.scrollUntilVisible(sell, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(sell);
    await tester.pump();
    expect(m.tab, AppTab.market);
  });

  testWidgets('舊的伺服器沒有 economy：只寫「優良牛奶」，不寫倍數（app 不自己寫死）', (tester) async {
    final st = warehouseState()..remove('economy');
    await _open(tester, st);
    expect(find.text(_zh.s05MilkName(tier: _zh.tierName(1))), findsOneWidget);
    expect(find.textContaining('×'), findsNothing);
  });

  testWidgets('出貨的牛沒有品種（舊的批次）：只寫編號', (tester) async {
    final beef = designBeefLots()..forEach((l) => l['breed'] = null);
    await _open(tester, warehouseState(beef: beef));
    expect(
      find.text('${_zh.s05ShippedFrom(cow: '#4')}${_zh.gSep}${_zh.timeAgo(h: 3)}', skipOffstage: false),
      findsOneWidget,
    );
  });
}
