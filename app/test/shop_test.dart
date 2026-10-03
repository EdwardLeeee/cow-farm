// 商店：S19 抽牛（機率由伺服器給、錢不夠或牛舍滿了停用、抽到的結果、載入失敗重試）、
// S10 設施（效果、費用、滿級、還沒開放、升級成功）；擴建、加大倉庫的按鈕直接到設施。
import 'dart:async';

import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:cowfarm/ui/shop/shop_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'pages/page_case.dart';
import 'pages/s03_cases.dart';
import 'pages/s19_cases.dart';

final _zh = Strings.forLang(AppLang.zhHant);

AppButton _btn(WidgetTester tester, String key) => tester.widget<AppButton>(find.byKey(Key(key)));

void main() {
  setUpAll(loadAppAssets);

  testWidgets('抽牛（S19）：三個等級的價格；機率是伺服器給的（用途、公母、稀有度）', (tester) async {
    Screen.w390.apply(tester);
    final api = ShopApi();
    await showShop(tester, AppLang.zhHant, api: api);
    expect(api.calls, contains('shop'));
    for (final p in ['3,200', '1,700', '900']) {
      expect(find.text(_zh.costCoins(v: p)), findsOneWidget);
    }
    expect(find.byKey(const Key('prob-grid')), findsNWidgets(3));
    expect(find.textContaining('45%', findRichText: true), findsNWidgets(3));
    expect(find.textContaining('14.1%', findRichText: true), findsOneWidget);
  });

  test('機率的寫法：1% 以上一位小數，0.01% 以上兩位，更小寫 <0.01%', () {
    expect(probText(0.421875), '42.2%');
    expect(probText(0.45), '45%');
    expect(probText(0.0007), '0.07%');
    expect(probText(0.0003), '0.03%');
    expect(probText(0.000001), '<0.01%');
  });

  testWidgets('金幣不夠：那一級停用，寫還差多少（只是顯示，伺服器會再檢查）', (tester) async {
    Screen.w390.apply(tester);
    await showShop(tester, AppLang.zhHant, api: ShopApi(state: shopState(coins: 1250)));
    expect(_btn(tester, 'buy-A').onPressed, isNull);
    expect(_btn(tester, 'buy-B').onPressed, isNull);
    expect(_btn(tester, 'buy-C').onPressed, isNotNull);
    expect(find.text(_zh.notEnoughCoins(n: '1,950')), findsOneWidget);
    expect(find.text(_zh.notEnoughCoins(n: '450')), findsOneWidget);
  });

  testWidgets('牛舍滿了：三顆都停用，上面一行提醒', (tester) async {
    Screen.w390.apply(tester);
    await showShop(tester, AppLang.zhHant, api: ShopApi(state: shopState(penSlots: 10, penUsed: 10)));
    expect(find.byKey(const Key('pen-full')), findsOneWidget);
    for (final g in ['A', 'B', 'C']) {
      await tester.scrollUntilVisible(find.byKey(Key('buy-$g')), 150, scrollable: find.byType(Scrollable).first);
      expect(_btn(tester, 'buy-$g').onPressed, isNull, reason: g);
    }
  });

  testWidgets('機率載入失敗：按鈕停用；按重試再拿一次', (tester) async {
    Screen.w390.apply(tester);
    final api = ShopApi()..fail = true;
    await showShop(tester, AppLang.zhHant, api: api);
    expect(find.text(_zh.s19ProbFailed), findsNWidgets(3));
    expect(_btn(tester, 'buy-A').onPressed, isNull);
    api.fail = false;
    await tester.tap(find.byKey(const Key('odds-retry-A')));
    await tester.pump();
    await tester.pump();
    expect(find.text(_zh.s19ProbFailed), findsNothing);
    expect(_btn(tester, 'buy-A').onPressed, isNotNull);
  });

  testWidgets('抽到的結果：抽到的小牛、名字、標籤、多久長大；按「好」關掉', (tester) async {
    Screen.w390.apply(tester);
    final api = ShopApi()..after = shopState(coins: 12480 - 3200);
    await showShop(tester, AppLang.zhHant, api: api);
    await tester.tap(find.byKey(const Key('buy-A')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(api.calls, contains('shop-buy:A'));
    expect(find.byKey(const Key('drawn-cow')), findsOneWidget);
    expect(find.text(_zh.cowName('highland', 17)), findsOneWidget);
    expect(find.text(_zh.stageCalf), findsOneWidget);
    await tester.tap(find.byKey(const Key('drawn-ok')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('drawn-cow')), findsNothing);
  });

  testWidgets('設施（S10）：效果和費用；錢不夠停用；滿級；第一次擴建還沒開放的倒數', (tester) async {
    Screen.w390.apply(tester);
    await showShop(
      tester,
      AppLang.zhHant,
      facility: true,
      api: ShopApi(
        state: shopState(
          coins: 400,
          upgrades: designUpgrades(
            pen: {'level': 0, 'cost': 280, 'next_open_at': t0 + 180, 'slots': 2, 'next_slots': 3},
            fresh: {'level': 4, 'max': 4, 'cost': null, 'fresh_h': 18, 'half_h': 96, 'next_fresh_h': null},
          ),
        ),
      ),
    );
    expect(find.text(_zh.opensIn(v: _zh.countdown(180))), findsOneWidget);
    expect(_btn(tester, 'up-pen').onPressed, isNull);
    expect(_btn(tester, 'up-bucket').onPressed, isNotNull, reason: '310 幣，買得起');
    expect(_btn(tester, 'up-warehouse').onPressed, isNull, reason: '480 幣，不夠');
    expect(find.text(_zh.notEnoughCoins(n: '80')), findsOneWidget);
    expect(find.byKey(const Key('up-maxed-fresh')), findsOneWidget);
    expect(find.text(_zh.s10FreshMax(h: '18')), findsOneWidget);
  });

  testWidgets('伺服器沒給冷藏的最高等級：只寫「第 1 級」', (tester) async {
    Screen.w390.apply(tester);
    final ups = designUpgrades();
    (ups['fresh'] as Map<String, dynamic>).remove('max');
    await showShop(
      tester,
      AppLang.zhHant,
      facility: true,
      api: ShopApi(state: shopState(upgrades: ups)),
    );
    expect(find.text(_zh.s10LevelOf(n: 1, max: 4)), findsNothing);
    expect(find.text(_zh.gLevelN(n: 1)), findsNWidgets(3), reason: '奶桶、倉庫、冷藏');
  });

  testWidgets('升級成功：呼叫伺服器、提示「升級完成」、那一列淡綠底', (tester) async {
    Screen.w390.apply(tester);
    final api = ShopApi()
      ..after = shopState(
        coins: 12480 - 310,
        upgrades: designUpgrades(bucket: {'level': 2, 'cost': 481, 'capacity': 63, 'next_capacity': 94}),
      );
    await showShop(tester, AppLang.zhHant, api: api, facility: true);
    await tester.tap(find.byKey(const Key('up-bucket')));
    await tester.pump();
    await tester.pump();
    expect(api.calls, contains('upgrade:bucket'));
    expect(
      find.text(
        _zh.s10Upgraded(
          what: _zh.bucketTitle,
          effect: _zh.s10EffectBottles(a: '42', b: '63'),
        ),
      ),
      findsOneWidget,
    );
    final card = tester.widget<Container>(find.byKey(const Key('up-card-bucket')));
    expect((card.decoration! as BoxDecoration).color, const Color(0xFFF1FBEA));
  });

  testWidgets('切換抽牛、設施；牛舍清單的「擴建」直接到設施', (tester) async {
    Screen.w390.apply(tester);
    final m = await ranchModel(api: ShopApi());
    await pumpAppIn(tester, m, AppLang.zhHant, prefs: swipeHintSeen);
    await tester.tap(find.byKey(const Key('pen-pill')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('expand-pen')));
    await tester.pump();
    await tester.pump();
    expect(m.tab, AppTab.shop);
    expect(m.shopFacility, isTrue);
    expect(find.byKey(const Key('up-card-pen')), findsOneWidget);
    await tester.tap(find.byKey(const Key('seg-0')));
    await tester.pump();
    expect(m.shopFacility, isFalse);
    expect(find.byKey(const Key('grade-A')), findsOneWidget);
  });

  testWidgets('空牧場的「去商店」到抽牛', (tester) async {
    Screen.w390.apply(tester);
    final m = await ranchModel(api: ShopApi(state: shopState()..['cows'] = <Map<String, dynamic>>[]));
    m.selectShop(facility: true);
    await pumpAppIn(tester, m, AppLang.zhHant, prefs: swipeHintSeen);
    await tester.tap(find.text(_zh.s03GoShop));
    await tester.pump();
    expect(m.tab, AppTab.shop);
    expect(m.shopFacility, isFalse);
  });

  testWidgets('G-06 升級中：那一顆轉圈寫「處理中…」，其他設施停用；回覆以後恢復', (tester) async {
    Screen.w390.apply(tester);
    final api = ShopApi()..upgradeGate = Completer<void>();
    await showShop(tester, AppLang.zhHant, api: api, facility: true);
    await tester.tap(find.byKey(const Key('up-bucket')));
    await tester.pump();
    expect(_btn(tester, 'up-bucket').busy, isTrue);
    expect(_btn(tester, 'up-bucket').label, _zh.gBusy);
    expect(_btn(tester, 'up-warehouse').busy, isFalse);
    expect(_btn(tester, 'up-warehouse').onPressed, isNull, reason: '其他按鈕停用');
    api.upgradeGate!.complete();
    await tester.pump();
    await tester.pump();
    expect(_btn(tester, 'up-bucket').busy, isFalse);
  });
}
