// A-10 出貨評級揭曉（設計稿 anims.js 的 A10，1.5 秒）：卡車開走、結果頁淡入以後，A、B、C 輪流越轉越慢，第 0.9 秒停在這次的
// 評級，光線放射、三箱牛肉掉進來，1.2–1.45 秒字和按鈕淡入；點一下跳過。減少動態（或沒開動畫）：直接是 S20。
// 逐格的畫面在 test/pages/anim_shots_test.dart。
import 'dart:math' as math;

import 'package:cowfarm/app.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/ui/kit/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'pages/page_case.dart';
import 'pages/s04_cases.dart';

/// 荷斯坦 #3 出貨、評級 [grade]，開著動畫：卡車播完（3.6 秒）、結果頁淡入（0.3 秒）以後停在 A-10 的第 0 秒。
/// [reduced] 是減少動態（不播卡車，直接是結果頁）。
Future<void> shipWithMotion(WidgetTester tester, String grade, {bool reduced = false}) async {
  final api = DetailApi(state: detailState(detailCow(3)))
    ..grade = grade
    ..after = detailState(detailCow(11));
  final (m, _, _) = await loadedModel(api: api);
  m.openCow('${detailCow(3)['id']}');
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
  await openShip(tester);
  await tester.tap(find.byKey(const Key('ship-confirm')));
  await tester.pump();
  await tester.pump();
  if (!reduced) await tester.pump(const Duration(milliseconds: 3700));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

String _letter(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('grade-letter'))).data!;

double _opacityOf(WidgetTester tester, Key key) {
  final o = find.ancestor(of: find.byKey(key), matching: find.byType(Opacity));
  return o.evaluate().isEmpty ? 1 : tester.widget<Opacity>(o.first).opacity;
}

void main() {
  setUpAll(loadAppAssets);
  final zh = Strings.forLang(AppLang.zhHant);

  for (final g in ['A', 'C']) {
    testWidgets('開著動畫（評級 $g）：A、B、C 輪流，第 0.9 秒停在 $g；字和按鈕最後才出來，播完拿掉「點一下跳過」', (tester) async {
      Screen.w390.apply(tester);
      await shipWithMotion(tester, g);
      expect(find.byKey(const Key('ship-result')), findsOneWidget);
      expect(find.text(zh.animSkip), findsOneWidget);
      expect(_opacityOf(tester, const Key('ship-result-ok')), 0, reason: '1.2 秒才淡入');
      expect(tester.widget<Opacity>(find.byKey(const Key('gift-0'))).opacity, 0, reason: '1.0 秒才掉進來');
      final seen = <String>[_letter(tester)];
      for (var i = 0; i < 18; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (seen.last != _letter(tester)) seen.add(_letter(tester));
      }
      expect(seen.toSet(), {'A', 'B', 'C'}, reason: '前 0.9 秒三個字輪流：$seen');
      expect(seen.last, g, reason: '停在這次的評級：$seen');
      await tester.pump(const Duration(milliseconds: 700));
      expect(_letter(tester), g);
      expect(_opacityOf(tester, const Key('ship-result-ok')), 1);
      expect(tester.widget<Opacity>(find.byKey(const Key('gift-2'))).opacity, 1);
      expect(find.text(zh.animSkip), findsNothing, reason: '播完就是 S20');
      await tester.tap(find.byKey(const Key('ship-result-ok')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('ship-result')), findsNothing);
    });
  }

  testWidgets('點一下跳過：直接到最後一格（評級、字和按鈕都出來）', (tester) async {
    Screen.w390.apply(tester);
    await shipWithMotion(tester, 'B');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('reveal')));
    await tester.pump();
    expect(_letter(tester), 'B');
    expect(_opacityOf(tester, const Key('ship-result-ok')), 1);
    expect(find.text(zh.animSkip), findsNothing);
    await tester.tap(find.byKey(const Key('ship-result-ok')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('ship-result')), findsNothing);
  });

  testWidgets('光線 1.5 秒轉 40°（#192）：一條 20°，播完轉了整數條，停下來跟 S20 的光線一樣', (tester) async {
    Screen.w390.apply(tester);
    await shipWithMotion(tester, 'A');
    double deg() {
      final m = tester.widget<Transform>(find.byKey(const Key('ship-burst'))).transform;
      return math.atan2(m.entry(1, 0), m.entry(0, 0)) * 180 / math.pi;
    }

    final a = deg();
    await tester.pump(const Duration(milliseconds: 300));
    expect(deg() - a, closeTo(8, 0.1), reason: '0.3 秒轉 8°（1.5 秒 40°）');
    await tester.pump(const Duration(milliseconds: 1500));
    expect(deg(), closeTo(40, 0.01), reason: '最後一格：40° 是 2 條，光線的位置跟沒轉（S20）一樣');
  });

  testWidgets('減少動態：不輪流、不放射，直接是 S20', (tester) async {
    Screen.w390.apply(tester);
    await shipWithMotion(tester, 'A', reduced: true);
    expect(find.byKey(const Key('ship-result')), findsOneWidget);
    expect(_letter(tester), 'A');
    expect(find.text(zh.animSkip), findsNothing);
    expect(find.byKey(const Key('reveal')), findsNothing);
    expect(_opacityOf(tester, const Key('ship-result-ok')), 1);
  });
}
