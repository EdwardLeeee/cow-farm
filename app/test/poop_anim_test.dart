// A-14 清大便：點一下、A-15 手指劃過去（設計稿 anims.js 的 A14、A15）。開著動畫時：
// - 點一下：那一坨在原位淡掉、冒波紋和小星星（0.47 秒），右上角的數字到第 0.3 秒才少 1、跳一下。
// - 劃過去：劃過的每一坨淡掉、冒小星星（沒有波紋，0.35 秒），數字 0.05 秒後少；手指放開時跳一下；劃過的地方留一道白色軌跡，
//   放開 0.3 秒內淡掉。
// 手機開了「減少動態」照舊直接消失、數字直接變少（poop_test）。
import 'dart:async';
import 'dart:ui';

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

  testWidgets('劃過去（A-15）：每一坨淡掉、冒星星（沒有波紋），數字 0.05 秒後少；手指放開時跳一下；軌跡跟著手指、放開 0.3 秒淡掉', (tester) async {
    final (_, api) = await _showPoop(tester, 9);
    // 第 3 個位置 → 第 8 個位置，中間經過第 4 個位置（poop_test 一樣的劃法）
    final from = tester.getCenter(_poop(3)), to = tester.getCenter(_poop(8));
    final g = await tester.startGesture(from);
    await g.moveBy(const Offset(20, 0));
    await tester.pump();
    expect(_fx(0), findsOneWidget, reason: '第 3 個位置先清掉');
    expect(tester.widget<PoopCleanFx>(find.byType(PoopCleanFx)).swipe, isTrue);
    expect(
      find.descendant(of: _fx(0), matching: find.byType(CustomPaint)),
      findsNothing,
      reason: '劃過去沒有波紋',
    );
    final trail = find.byKey(const Key('swipe-trail'));
    expect(trail, findsOneWidget);
    expect(dirtText(tester), '${zh.s03Poop} 9', reason: '還沒到 0.05 秒');
    await tester.pump(const Duration(milliseconds: 60));
    expect(dirtText(tester), '${zh.s03Poop} 8');
    await g.moveTo(to);
    await tester.pump();
    expect(find.byType(PoopCleanFx), findsNWidgets(3), reason: '第 3、4、8 個位置');
    await tester.pump(const Duration(milliseconds: 60));
    expect(dirtText(tester), '${zh.s03Poop} 6');
    expect(_pillScale(tester), 1, reason: '劃的時候不跳');
    await g.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(_pillScale(tester), greaterThan(1.05), reason: '放開時跳一下');
    expect(api.calls.where((c) => c.startsWith('clean')), hasLength(1), reason: '放開才一次送出');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PoopCleanFx), findsNothing, reason: '播完收掉');
    expect(_pillScale(tester), 1);
    expect(dirtText(tester), '${zh.s03Poop} 6');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('劃過去的軌跡：劃的時候是 0.75 的白色線，放開 0.05 秒後開始淡掉、0.3 秒淡完', (tester) async {
    await _showPoop(tester, 9);
    final from = tester.getCenter(_poop(3));
    final g = await tester.startGesture(from);
    await g.moveBy(const Offset(30, 0));
    await tester.pump();
    await g.moveBy(const Offset(30, 0));
    await tester.pump();
    final paint = tester.widget<CustomPaint>(find.byKey(const Key('swipe-trail')));
    final painter = paint.painter!;
    expect(painter.shouldRepaint(painter), isFalse);
    // 用畫出來的結果看：畫在一張空白的圖上，手指經過的地方是白的
    Future<double> whiteAt(Offset p) async {
      final rec = PictureRecorder();
      painter.paint(Canvas(rec), tester.getSize(find.byKey(const Key('swipe-trail'))));
      final img = await rec.endRecording().toImage(400, 900);
      final data = (await img.toByteData())!;
      final i = (p.dy.round() * 400 + p.dx.round()) * 4;
      return data.getUint8(i + 3) / 255;
    }

    final scene = tester.getTopLeft(find.byKey(const Key('swipe-trail')));
    final mid = from + const Offset(30, 0) - scene;
    expect(await tester.runAsync(() => whiteAt(mid)), closeTo(0.75, 0.02));
    await g.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(await tester.runAsync(() => whiteAt(mid)), closeTo(0.75, 0.02), reason: '0.05 秒以前還沒淡');
    await tester.pump(const Duration(milliseconds: 135));
    expect(await tester.runAsync(() => whiteAt(mid)), closeTo(0.375, 0.05), reason: '淡到一半');
    await tester.pump(const Duration(milliseconds: 200));
    expect(await tester.runAsync(() => whiteAt(mid)), 0, reason: '淡完');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('減少動態的劃過去：直接消失、數字直接變少，不畫軌跡', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _showPoop(tester, 9);
    final g = await tester.startGesture(tester.getCenter(_poop(3)));
    await g.moveTo(tester.getCenter(_poop(8)));
    await tester.pump();
    expect(find.byType(PoopCleanFx), findsNothing);
    expect(find.byKey(const Key('swipe-trail')), findsNothing);
    expect(dirtText(tester), '${zh.s03Poop} 6');
    await g.up();
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
