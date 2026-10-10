// 病牛（v0.3 第 5 節）：一律轉正面看玩家、不走動；牧場點牛的名片按「治療」一樣先問（S04-19），治好了提示（S04-21）；
// 田裡的病牛停止耕田，每小時產量不算那塊田。畫面在 test/pages（S03-28～30、S04-18～21、S07-06、S17-13）。
import 'package:cowfarm/app.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:cowfarm/ui/kit/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'pages/page_case.dart';
import 'pages/s03_cases.dart';
import 'pages/s04_cases.dart' show kvValue;
import 'pages/s17_cases.dart' show FieldsApi, fieldsHerd, fieldsState, showFields;

/// 設計稿 S03-28 的牧場（#3 荷斯坦生病了、9 坨大便）。[motion] 開著動畫（牛會走動）；[coins] 給了就換掉金幣。
Future<(GameModel, FakeGameApi)> _sickRanch(WidgetTester tester, {bool motion = false, double? coins}) async {
  Screen.w430.apply(tester);
  final api = FakeGameApi(
    state: {
      ...ranchState(cows: sickHerd()),
      'coins': ?coins,
    },
    market: ranchMarket(),
  );
  final m = await ranchModel(api: api);
  final settings = settingsFor(AppLang.zhHant, swipeHintSeen);
  await settings.load();
  final app = CowFarmApp(model: m, settings: settings);
  await tester.pumpWidget(motion ? AppMotion(enabled: true, child: app) : app);
  await tester.pump();
  return (m, api);
}

Future<void> _openTreat(WidgetTester tester) async {
  await tapSceneCow(tester, 3);
  await tester.pump();
  await tester.tap(find.byKey(const Key('pop-treat')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(loadAppAssets);
  final zh = Strings.forLang(AppLang.zhHant);

  testWidgets('牧場的名片按「治療」：先問，確定了才治療；治好了提示「荷斯坦 #3 好了！」，牛回到一般的樣子', (tester) async {
    final (_, api) = await _sickRanch(tester);
    await _openTreat(tester);
    expect(find.byKey(const Key('treat-dialog')), findsOneWidget);
    expect(find.text(zh.s04TreatTitle(cow: zh.cowName('holstein', 3))), findsOneWidget);
    expect(api.calls.where((c) => c.startsWith('cure')), isEmpty, reason: '還沒確定');
    await tester.tap(find.byKey(const Key('treat-ok')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(api.calls, contains('cure:3'));
    expect(find.text(zh.s04Treated(cow: zh.cowName('holstein', 3))), findsOneWidget);
    expect(find.byKey(const Key('cow-pop')), findsNothing, reason: '名片收起來');
    expect(ranchGame(tester).artOf(3), isNot(endsWith('_sick')), reason: '臉色回來了');
  });

  testWidgets('金幣不夠（剩 3,750）：名片上的「治療」照 S04-20 停用，下面寫還差 1,250 幣（ceo 2026-10-10）', (tester) async {
    final (_, api) = await _sickRanch(tester, coins: 3750);
    await tapSceneCow(tester, 3);
    await tester.pump();
    expect(tester.widget<AppButton>(find.byKey(const Key('pop-treat'))).onPressed, isNull);
    expect(find.text(zh.notEnoughCoins(n: '1,250')), findsOneWidget);
    await tester.tap(find.byKey(const Key('pop-treat')), warnIfMissed: false);
    await tester.pump();
    expect(find.byKey(const Key('treat-dialog')), findsNothing);
    expect(api.calls.where((c) => c.startsWith('cure')), isEmpty);
  });

  testWidgets('金幣夠：名片上沒有「還差」那一行', (tester) async {
    await _sickRanch(tester);
    await tapSceneCow(tester, 3);
    await tester.pump();
    expect(tester.widget<AppButton>(find.byKey(const Key('pop-treat'))).onPressed, isNotNull);
    expect(find.byKey(const Key('pop-treat-short')), findsNothing);
  });

  testWidgets('治療確認按「取消」：不治療，名片還在', (tester) async {
    final (_, api) = await _sickRanch(tester);
    await _openTreat(tester);
    await tester.tap(find.byKey(const Key('treat-cancel')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('treat-dialog')), findsNothing);
    expect(api.calls.where((c) => c.startsWith('cure')), isEmpty);
    expect(find.byKey(const Key('cow-pop')), findsOneWidget);
  });

  testWidgets('病牛不走動（A-11）：一直轉正面看玩家，其他的牛照樣走', (tester) async {
    await _sickRanch(tester, motion: true);
    await settleImages(tester);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    final game = ranchGame(tester);
    expect(game.dxOf(3), 0, reason: '病牛站在原位');
    expect(game.artOf(3), endsWith('_sick'));
    expect([7, 12, 14].any((id) => game.dxOf(id) != 0), isTrue, reason: '其他的牛 10 秒內會起步');
    // 停掉動畫的計時器（牛走動）
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('田裡的病牛停止耕田：每小時產量不算那塊田（S17-13）', (tester) async {
    Screen.w430.apply(tester);
    final cows = [for (final c in fieldsHerd()) c['id'] == 2 ? sickCow(c) : c];
    await showFields(
      tester,
      AppLang.zhHant,
      api: FieldsApi(state: fieldsState(cows: cows)),
    );
    // 平常第 1 塊田每小時 11 公斤（第 3 塊長滿了不算）；#2 生病了，兩塊都不算
    expect(kvValue(tester, zh.s17PerHour), '0.0 ${zh.gKg}');
  });
}
