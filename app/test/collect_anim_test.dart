// A-01 收奶（設計稿 anims.js 的 A01，1.4 秒）：奶瓶從奶桶飛進頂列左邊的「倉庫」小鈕（小鈕跳一下）、奶桶往下降，
// 第 1.0 秒提示淡入。減少動態（或沒開動畫）時不飛奶瓶、小鈕不跳、數字直接變、提示淡入。
// 逐格的畫面在 test/pages/anim_shots_test.dart。
import 'package:cowfarm/app.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/kit/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pages/page_case.dart';
import 'pages/s03_cases.dart';

/// 牧場頁，開著動畫（app 的 main.dart 也是包 AppMotion）。
Future<GameModel> pumpRanchWithMotion(WidgetTester tester, {bool reduced = false}) async {
  final m = await ranchModel(api: CollectApi(), state: ranchState());
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
  return m;
}

double _toastOpacity(WidgetTester tester) {
  final o = find.ancestor(of: find.byKey(const Key('toast')), matching: find.byType(Opacity));
  return o.evaluate().isEmpty ? 1 : tester.widget<Opacity>(o.first).opacity;
}

String _bucketCount(WidgetTester tester) {
  final texts = find.descendant(of: find.byKey(const Key('bucket-card')), matching: find.byType(RichText));
  return [
    for (final e in texts.evaluate())
      if ((e.widget as RichText).text.toPlainText() case final t when t.contains('/ 42')) t,
  ].single;
}

/// 飛的奶瓶（collect-bottle-0～4）。
Finder _bottles() => find.byWidgetPredicate(
  (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('collect-bottle'),
);

/// 頂列的「倉庫」小鈕上的字。
Finder _whText() => find.descendant(
  of: find.byKey(const Key('warehouse-btn')),
  matching: find.text(Strings.forLang(AppLang.zhHant).warehouseTitle),
);

/// 「倉庫」小鈕放大的倍數（A-01 跳一下）。
double _whScale(WidgetTester tester) => tester
    .widget<Transform>(find.ancestor(of: _whText(), matching: find.byType(Transform)).first)
    .transform
    .getMaxScaleOnAxis();

void main() {
  setUpAll(loadAppAssets);
  final zh = Strings.forLang(AppLang.zhHant);

  testWidgets('開著動畫：奶瓶飛進「倉庫」小鈕、奶桶往下降、提示還沒出來；小鈕跳一下；1.4 秒以後提示出來', (tester) async {
    Screen.w390.apply(tester);
    await pumpRanchWithMotion(tester);
    expect(_bucketCount(tester), contains('36.4 / 42'));
    await tester.tap(find.byKey(const Key('collect')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_bottles(), findsNWidgets(5), reason: '第 0.5 秒五個奶瓶都在飛');
    // 第一個奶瓶第 0.1–0.6 秒飛，第 0.5 秒快到了：在「倉庫」小鈕的中間附近
    final pill = tester.getCenter(find.ancestor(of: _whText(), matching: find.byType(Container)).first);
    expect((tester.getCenter(find.byKey(const Key('collect-bottle-0'))) - pill).distance, lessThan(6));
    expect(_whScale(tester), 1, reason: '第 0.55 秒才開始跳');
    final mid = _bucketCount(tester);
    expect(mid, isNot(contains('36.4 /')));
    expect(double.parse(mid.split('/').first.replaceAll(RegExp('[^0-9.]'), '')), inExclusiveRange(1, 36.4));
    expect(_toastOpacity(tester), 0, reason: '第 1.0 秒才淡入');
    await tester.pump(const Duration(milliseconds: 300));
    expect(_whScale(tester), closeTo(1.12, 0.001), reason: '第 0.8 秒跳到最大');
    await tester.pump(const Duration(milliseconds: 700));
    expect(_bottles(), findsNothing);
    expect(_whScale(tester), 1);
    expect(_bucketCount(tester), contains('0 / 42'));
    expect(find.text(zh.collected(v: '36.4')), findsOneWidget);
    expect(_toastOpacity(tester), 1);
  });

  testWidgets('減少動態：不飛奶瓶、「倉庫」小鈕不跳，數字直接變、提示淡入 0.2 秒', (tester) async {
    Screen.w390.apply(tester);
    await pumpRanchWithMotion(tester, reduced: true);
    await tester.tap(find.byKey(const Key('collect')));
    await tester.pump();
    await tester.pump();
    expect(_bottles(), findsNothing);
    expect(_whScale(tester), 1);
    expect(_bucketCount(tester), contains('0 / 42'));
    expect(find.text(zh.collected(v: '36.4')), findsOneWidget);
    expect(_toastOpacity(tester), lessThan(1), reason: '淡入中');
    await tester.pump(const Duration(milliseconds: 100));
    expect(_toastOpacity(tester), inExclusiveRange(0.3, 0.7), reason: '第 0.1 秒淡入一半（手機的減少動態不會再把 0.2 秒縮短）');
    await tester.pump(const Duration(milliseconds: 150));
    expect(_toastOpacity(tester), 1);
  });
}
