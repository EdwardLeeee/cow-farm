// A-08 收成稻米（設計稿 anims.js 的 A08，1.3 秒）：稻穗從田裡飛進「倉庫稻米」、田裡的稻子變矮、倉庫 184 → 361 公斤，
// 第 0.95 秒提示淡入。減少動態（或沒開動畫）時不飛、數字直接變、提示淡入 0.2 秒。逐格的畫面在 test/pages/anim_shots_test.dart。
import 'package:cowfarm/app.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/kit/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pages/page_case.dart';
import 'pages/s03_cases.dart';
import 'pages/s17_cases.dart';

final _zh = Strings.forLang(AppLang.zhHant);

/// 田地頁（設計稿 S17-01：倉庫 184 公斤、田裡 176.9），開著動畫；收成以後是 S17-09（倉庫 361、田裡 0）。
Future<GameModel> harvestWithMotion(WidgetTester tester, {bool reduced = false}) async {
  final api = FieldsApi()
    ..after = fieldsState(
      stock: 361,
      fields: [
        designField(0, cow: 2, rice: 0, cap: 88, rate: 11),
        designField(1),
        designField(2, cow: 9, rice: 0, cap: 114.4, rate: 14.3),
      ],
    );
  final m = await ranchModel(api: api);
  m.selectTab(AppTab.fields);
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

/// 「倉庫稻米」那一格的數字（三格裡唯一沒有小數點、單位是公斤的）。
int _stock(WidgetTester tester) {
  final texts = [
    for (final e in find.descendant(of: find.byKey(const Key('field-kv')), matching: find.byType(RichText)).evaluate())
      (e.widget as RichText).text.toPlainText(),
  ];
  final t = texts.singleWhere((t) => t.contains(_zh.gKg) && !t.contains('.'));
  return int.parse(t.split(' ').first.replaceAll(',', ''));
}

double _toastOpacity(WidgetTester tester) {
  final o = find.ancestor(of: find.byKey(const Key('toast')), matching: find.byType(Opacity));
  return o.evaluate().isEmpty ? 1 : tester.widget<Opacity>(o.first).opacity;
}

final _rice = find.byWidgetPredicate(
  (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('harvest-rice'),
);

/// 第一塊田的卡片上「x / 88」的 x。
double _field0(WidgetTester tester) {
  final texts = [
    for (final e in find.descendant(of: find.byKey(const Key('field-0')), matching: find.byType(RichText)).evaluate())
      (e.widget as RichText).text.toPlainText(),
  ];
  return double.parse(texts.firstWhere((t) => t.contains('/ 88')).split('/').first.trim());
}

void main() {
  setUpAll(loadAppAssets);

  testWidgets('開著動畫：稻穗在飛、田裡的稻子變矮、倉庫往上跳、提示第 0.95 秒才出來；1.3 秒以後 361 公斤', (tester) async {
    Screen.w390.apply(tester);
    await harvestWithMotion(tester);
    expect(_stock(tester), 184);
    final full = _field0(tester);
    await tester.tap(find.byKey(const Key('harvest')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(_rice.evaluate().length, greaterThanOrEqualTo(5), reason: '第 0.45 秒稻穗在飛');
    expect(_field0(tester), inExclusiveRange(0, full), reason: '田裡的稻子在變矮');
    expect(_stock(tester), 184, reason: '第 0.5 秒才開始跳');
    expect(_toastOpacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_stock(tester), inExclusiveRange(184, 361), reason: '第 0.75 秒跳到一半多');
    await tester.pump(const Duration(milliseconds: 700));
    expect(_rice, findsNothing);
    expect(_stock(tester), 361);
    expect(_field0(tester), lessThan(0.1));
    expect(find.text(_zh.harvested(kg: '177')), findsOneWidget);
    expect(_toastOpacity(tester), 1);
    expect(find.text(_zh.s17HarvestNone), findsOneWidget, reason: '跟 S17-09 一樣');
  });

  testWidgets('減少動態：不飛稻穗，倉庫直接 361、田裡直接 0，提示淡入 0.2 秒', (tester) async {
    Screen.w390.apply(tester);
    await harvestWithMotion(tester, reduced: true);
    await tester.tap(find.byKey(const Key('harvest')));
    await tester.pump();
    await tester.pump();
    expect(_rice, findsNothing);
    expect(_stock(tester), 361);
    expect(_field0(tester), lessThan(0.1));
    expect(find.text(_zh.harvested(kg: '177')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_toastOpacity(tester), inExclusiveRange(0.3, 0.7), reason: '第 0.1 秒淡入一半');
    await tester.pump(const Duration(milliseconds: 150));
    expect(_toastOpacity(tester), 1);
  });
}
