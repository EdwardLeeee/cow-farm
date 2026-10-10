// A-14 清大便：點一下（設計稿 anims.js 的 A14）。開著動畫時點到的那一坨在原位淡掉、冒波紋和小星星（0.47 秒），
// 右上角的數字到第 0.3 秒才少 1、跳一下；手機開了「減少動態」照舊直接消失、數字直接變少（poop_test）。
import 'dart:async';

import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/app.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/kit/motion.dart';
import 'package:cowfarm/ui/ranch/poop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'pages/page_case.dart';
import 'pages/s03_cases.dart';

Finder _poop(int spot) => find.byKey(Key('poop-$spot'));
Finder _fx(int id) => find.byKey(ValueKey('poop-fx-$id'));

/// 設計稿的牧場，旁邊一共 [n] 坨大便；開著動畫（牛會走動）。
Future<(GameModel, FakeGameApi)> _showPoop(WidgetTester tester, int n) async {
  Screen.w390.apply(tester);
  final api = FakeGameApi(
    state: ranchState(cows: poopCows(n)),
    market: ranchMarket(),
  );
  final m = await ranchModel(api: api);
  final settings = settingsFor(AppLang.zhHant, swipeHintSeen);
  await settings.load();
  await tester.pumpWidget(
    AppMotion(
      enabled: true,
      child: CowFarmApp(model: m, settings: settings),
    ),
  );
  await tester.pump();
  return (m, api);
}

/// 右上角大便數的放大倍數（A-14 跳一下）。
double _pillScale(WidgetTester tester) => tester
    .widget<Transform>(find.ancestor(of: find.byKey(const Key('dirt-pill')), matching: find.byType(Transform)).first)
    .transform
    .getMaxScaleOnAxis();

void main() {
  setUpAll(loadAppAssets);
  final zh = Strings.forLang(AppLang.zhHant);

  testWidgets('點一下：原位淡掉、波紋、小星星；數字第 0.3 秒才少 1、跳一下；0.47 秒播完收掉', (tester) async {
    final (_, api) = await _showPoop(tester, 4);
    final rect = tester.getRect(_poop(2));
    await tester.tap(_poop(2));
    await tester.pump();
    expect(_poop(2), findsNothing, reason: '場景裡那一坨已經拿掉');
    expect(_fx(0), findsOneWidget);
    expect(api.calls.last, 'clean:5x1', reason: '照樣馬上送出');
    // 淡掉的那一坨畫在原來的位置
    final fading = find.descendant(of: _fx(0), matching: find.byType(Opacity)).first;
    expect(tester.getRect(fading), rect);
    expect(dirtText(tester), '${zh.s03Poop} 4', reason: '數字還沒變');
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.widget<Opacity>(fading).opacity, closeTo(1 - (0.15 - 0.05) / 0.15, 0.02), reason: '0.05–0.2 秒淡掉');
    await tester.pump(const Duration(milliseconds: 100));
    expect(dirtText(tester), '${zh.s03Poop} 4');
    await tester.pump(const Duration(milliseconds: 60));
    expect(dirtText(tester), '${zh.s03Poop} 3', reason: '第 0.3 秒少 1');
    await tester.pump(const Duration(milliseconds: 70));
    expect(_pillScale(tester), greaterThan(1.05), reason: '跳一下');
    await tester.pump(const Duration(milliseconds: 200));
    expect(_fx(0), findsNothing, reason: '播完收掉');
    expect(_pillScale(tester), 1);
    expect(dirtText(tester), '${zh.s03Poop} 3');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('連點兩坨：各播各的，數字各自到第 0.3 秒才少', (tester) async {
    await _showPoop(tester, 4);
    await tester.tap(_poop(0));
    // 先畫一格（動畫從這一格開始算），再過 0.1 秒點第二坨
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(_poop(3));
    await tester.pump();
    expect(_fx(0), findsOneWidget);
    expect(_fx(1), findsOneWidget);
    expect(dirtText(tester), '${zh.s03Poop} 4');
    await tester.pump(const Duration(milliseconds: 220));
    expect(dirtText(tester), '${zh.s03Poop} 3', reason: '第一坨到了 0.3 秒');
    await tester.pump(const Duration(milliseconds: 100));
    expect(dirtText(tester), '${zh.s03Poop} 2');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PoopCleanFx), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('送出失敗（連不上）：動畫收掉，大便放回去、數字是原本的', (tester) async {
    final (_, api) = await _showPoop(tester, 4);
    final gate = api.cleanGate = Completer<void>();
    api.cleanError = const NetworkException('offline');
    await tester.tap(_poop(1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_fx(0), findsOneWidget);
    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(_fx(0), findsNothing);
    expect(_poop(1), findsOneWidget, reason: '放回原來的位置');
    expect(dirtText(tester), '${zh.s03Poop} 4');
    await tester.pump(const Duration(milliseconds: 500));
    expect(dirtText(tester), '${zh.s03Poop} 4', reason: '不會晚一步再少 1');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('減少動態：點到的直接消失、數字直接變少（不播波紋和小星星）', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _showPoop(tester, 4);
    await tester.tap(_poop(2));
    await tester.pump();
    expect(_poop(2), findsNothing);
    expect(find.byType(PoopCleanFx), findsNothing);
    expect(dirtText(tester), '${zh.s03Poop} 3');
    await tester.pumpWidget(const SizedBox());
  });
}
