// A-05 升級（設計稿 anims.js 的 A05，1.3 秒）：暗幕變暗、卡片彈出來、等級數字從 4 翻成 5（頂列的等級同時換）、彩紙落下，
// 停在最後一格等「好」。減少動態：直接是最後一格、整個淡入 0.2 秒。沒開動畫是 S11-01（test/pages/s11_cases.dart）。
// 逐格的畫面在 test/pages/anim_shots_test.dart。
import 'package:cowfarm/app.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/kit/frame.dart';
import 'package:cowfarm/ui/kit/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'pages/page_case.dart';

final _zh = Strings.forLang(AppLang.zhHant);

/// 牧場頁、Lv4，開著動畫；回傳升到 Lv5 的函式（伺服器的 state 變了）。
Future<(GameModel, Future<void> Function())> _ranchWithMotion(WidgetTester tester, {bool reduced = false}) async {
  final (m, api, _) = await loadedModel();
  api.stateJson = {
    ...api.stateJson,
    'level': 4,
    'level_progress': {'earned': 7400, 'level_at': 3500, 'next_at': 7500},
  };
  await m.refreshState();
  m.dismissLevelUp(); // 準備的時候從 Lv3 調到 Lv4 也算升級：不要
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
  Future<void> levelUp() async {
    api.stateJson = {
      ...api.stateJson,
      'level': 5,
      'level_progress': {'earned': 7500, 'level_at': 7500, 'next_at': 15500},
    };
    await m.refreshState();
    await tester.pump();
  }

  return (m, levelUp);
}

/// 頂列的等級（「Lv 4」）。
Finder _hudLv(int lv) => find.descendant(
  of: find.byType(Hud),
  matching: find.text(_zh.level(lv: lv)),
);

/// 卡片現在的大小（A-05 從 0.4 倍彈到 1 倍）。
double _cardScale(WidgetTester tester) {
  final t = find.ancestor(of: find.byKey(const Key('level-card')), matching: find.byType(Transform));
  return tester.widget<Transform>(t.first).transform.getMaxScaleOnAxis();
}

final _confetti = find.byWidgetPredicate(
  (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('confetti-'),
);

const _old = Key('level-up-old'), _new = Key('level-up-lv');

/// 舊的、新的數字在捲動框裡的位置（框的上緣是 0）。
double _numberY(WidgetTester tester, Key n) {
  final text = find.byKey(n);
  final box = find.ancestor(of: text, matching: find.byType(ClipRect)).first;
  return tester.getTopLeft(text).dy - tester.getTopLeft(box).dy;
}

void main() {
  setUpAll(loadAppAssets);

  testWidgets('開著動畫：卡片彈出來、數字從 4 翻成 5、頂列跟著換、彩紙第 0.35 秒才出來；停在最後一格，按「好」關掉', (tester) async {
    Screen.w390.apply(tester);
    final (m, levelUp) = await _ranchWithMotion(tester);
    expect(_hudLv(4), findsOneWidget);
    await levelUp();
    expect(_hudLv(4), findsOneWidget, reason: '升級的那一格頂列也還是 Lv 4（不閃一下 Lv 5）');
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('level-up')), findsOneWidget);
    expect(_hudLv(4), findsOneWidget, reason: '數字翻過去以前頂列還是 Lv 4');
    expect(_confetti, findsNothing, reason: '第 0.35 秒才落下');

    await tester.pump(const Duration(milliseconds: 150)); // 0.2 秒
    expect(_cardScale(tester), inExclusiveRange(0.4, 1.2));
    expect(_numberY(tester, _old), 0, reason: '還沒開始翻');

    await tester.pump(const Duration(milliseconds: 300)); // 0.5 秒：翻到一小半
    expect(_numberY(tester, _old), lessThan(0));
    expect(_numberY(tester, _new), inExclusiveRange(0, 90));
    expect(_hudLv(4), findsOneWidget);
    expect(_confetti, findsNWidgets(26));

    await tester.pump(const Duration(milliseconds: 100)); // 0.6 秒：翻過一半
    expect(_hudLv(5), findsOneWidget, reason: '數字翻過一半，頂列換成 Lv 5');

    await tester.pump(const Duration(milliseconds: 800)); // 1.4 秒
    expect(_cardScale(tester), 1);
    expect(_numberY(tester, _new), 0);
    expect(find.byKey(_old), findsNothing, reason: '翻完舊的數字就藏起來');
    expect(tester.widget<Text>(find.byKey(_new)).data, '5');
    expect(find.text(_zh.s11Earned(v: '7,500')), findsOneWidget);
    expect(find.byKey(const Key('level-up')), findsOneWidget, reason: '停住等「好」');

    await tester.tap(find.byKey(const Key('level-up-ok')));
    await tester.pump();
    expect(find.byKey(const Key('level-up')), findsNothing);
    expect(m.levelUp, isNull);
    expect(_hudLv(5), findsOneWidget);
  });

  testWidgets('播完的最後一格跟 S11-01（沒開動畫的靜態樣子）一樣：卡片、「Lv」、數字、每一片彩紙（#178）', (tester) async {
    Screen.w390.apply(tester);
    Map<String, Object> look() => {
      'card': tester.getRect(find.byKey(const Key('level-card'))),
      'lv': tester.getRect(find.descendant(of: find.byKey(const Key('level-card')), matching: find.text(_zh.s11Lv))),
      'num': tester.getRect(find.byKey(_new)),
      for (var i = 0; i < 26; i++) ...{
        'c$i': tester.getRect(find.byKey(ValueKey('confetti-$i'))),
        'r$i': tester
            .widget<Transform>(
              find.descendant(of: find.byKey(ValueKey('confetti-$i')), matching: find.byType(Transform)),
            )
            .transform
            .storage
            .map((v) => (v * 1000).round())
            .toList(),
      },
    };
    final (m, levelUp) = await _ranchWithMotion(tester);
    await levelUp();
    await tester.pump(const Duration(milliseconds: 1400));
    final anim = look();
    final settings = settingsFor(AppLang.zhHant, swipeHintSeen);
    await settings.load();
    await tester.pumpWidget(CowFarmApp(model: m, settings: settings));
    await tester.pump();
    final still = look();
    for (final k in anim.keys) {
      expect(anim[k], still[k], reason: k);
    }
  });

  testWidgets('數字還沒翻過去就按「好」：頂列換回 Lv 5', (tester) async {
    Screen.w390.apply(tester);
    final (_, levelUp) = await _ranchWithMotion(tester);
    await levelUp();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_hudLv(4), findsOneWidget);
    await tester.tap(find.byKey(const Key('level-up-ok')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('level-up')), findsNothing);
    expect(_hudLv(5), findsOneWidget);
  });

  testWidgets('減少動態：不彈、不翻，直接是最後一格（頂列 Lv 5），淡入 0.2 秒', (tester) async {
    Screen.w390.apply(tester);
    final (_, levelUp) = await _ranchWithMotion(tester, reduced: true);
    await levelUp();
    await tester.pump(const Duration(milliseconds: 50));
    // 整個慶祝（暗幕、彩紙、卡片）一起淡入：最外面那一層 Opacity
    final fade = find.descendant(of: find.byKey(const Key('level-up')), matching: find.byType(Opacity)).first;
    expect(tester.widget<Opacity>(fade).opacity, closeTo(0.25, 0.01), reason: '0.2 秒淡入，第 0.05 秒四分之一');
    expect(_hudLv(5), findsOneWidget);
    expect(
      find.ancestor(of: find.byKey(const Key('level-card')), matching: find.byType(Transform)),
      findsNothing,
      reason: '不彈',
    );
    expect(find.byKey(_old), findsNothing, reason: '不翻：沒有 4');
    expect(find.descendant(of: find.byKey(const Key('level-card')), matching: find.text('4')), findsNothing);
    expect(find.bySemanticsLabel('5'), findsOneWidget, reason: '螢幕閱讀器只唸 5');
    expect(_confetti, findsNWidgets(26));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<Opacity>(fade).opacity, 1);
  });

  testWidgets('兩位數（Lv 9 → 10）：捲動框放寬，「10」整個看得到', (tester) async {
    Screen.w390.apply(tester);
    final (m, api, _) = await loadedModel();
    api.stateJson = {...api.stateJson, 'level': 9};
    await m.refreshState();
    m.dismissLevelUp();
    final settings = settingsFor(AppLang.zhHant, swipeHintSeen);
    await settings.load();
    await tester.pumpWidget(
      AppMotion(
        enabled: true,
        child: CowFarmApp(model: m, settings: settings),
      ),
    );
    await tester.pump();
    api.stateJson = {...api.stateJson, 'level': 10};
    await m.refreshState();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));
    // S11-07：框跟著新的數字變寬（框裡看不到的「10」撐出寬度），兩位數整個看得到
    final box = find.ancestor(of: find.byKey(_new), matching: find.byType(ClipRect)).first;
    final sizer = find.descendant(of: box, matching: find.byType(Visibility));
    expect(tester.getSize(box).width, tester.getSize(sizer).width);
    expect(tester.getSize(box).width, greaterThan(60), reason: '以前的框寬 60 會切掉');
    expect(tester.widget<Text>(find.byKey(_new)).data, '10');
  });
}
