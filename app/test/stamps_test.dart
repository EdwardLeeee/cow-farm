// 小牛的飼料集點（v0.3 第 1 節；#174）：牧場的想吃泡泡（S03-31）跟著走動的小牛；快長大的提醒卡（S03-32）再 1 小時內
// 長大、還有沒吃的才跳，一頭一張（先長大的先），按 × 或「去餵食」都算看過、以後不再跳（記在手機上）。
// 畫面在 test/pages（S03-31～33、S04-08、S04-22）。
import 'package:cowfarm/app.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/state/settings.dart';
import 'package:cowfarm/ui/kit/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pages/page_case.dart';
import 'pages/s03_cases.dart';

final _alert15 = find.byKey(const Key('grow-alert-15'));

/// 牧場：[cows]（預設 #15 吃了一半、42 分後長大），[prefs] 是手機上記的設定。[motion] 開著動畫（牛會走動）。
Future<(GameModel, SettingsController)> _ranch(
  WidgetTester tester, {
  List<Map<String, dynamic>>? cows,
  Map<String, String> prefs = const {},
  bool motion = false,
}) async {
  Screen.w430.apply(tester);
  final m = await ranchModel(state: ranchState(cows: cows ?? stampHerd()));
  final settings = settingsFor(AppLang.zhHant, {...swipeHintSeen, ...prefs});
  await settings.load();
  final app = CowFarmApp(model: m, settings: settings);
  await tester.pumpWidget(motion ? AppMotion(enabled: true, child: app) : app);
  await tester.pump();
  return (m, settings);
}

void main() {
  setUpAll(loadAppAssets);

  testWidgets('提醒卡按 ×：收起來，以後不再跳（記在手機上，照牧場分開）', (tester) async {
    final (m, settings) = await _ranch(tester);
    expect(_alert15, findsOneWidget);
    await tester.tap(find.byKey(const Key('grow-alert-close-15')));
    await tester.pump();
    expect(_alert15, findsNothing);
    expect(settings.growAlertSeen(15, 31), isTrue);
    await m.refreshState();
    await tester.pump();
    expect(_alert15, findsNothing, reason: '一頭只跳一次');
  });

  testWidgets('提醒卡按「去餵食」：先打開這頭小牛的詳細（看得到集點卡），也算看過', (tester) async {
    final (m, settings) = await _ranch(tester);
    await tester.tap(find.byKey(const Key('grow-alert-go-15')));
    await tester.pump();
    expect(m.detailCowKey, '15');
    expect(find.byKey(const Key('stamp-card')), findsOneWidget);
    expect(settings.growAlertSeen(15, 31), isTrue);
  });

  testWidgets('兩頭都快長大了：一次一張，先長大的先；關掉才換下一張', (tester) async {
    // #15 42 分後長大、#22 30 分後長大（還沒吃玉米）
    final cows = [
      ...stampHerd(),
      {
        ...designCow(22, 'angus', stage: 'calf', growMin: 30),
        'need': ['corn', 'soy'],
        'ate': ['soy'],
      },
    ];
    await _ranch(tester, cows: cows);
    expect(find.byKey(const Key('grow-alert-22')), findsOneWidget);
    expect(_alert15, findsNothing);
    await tester.tap(find.byKey(const Key('grow-alert-close-22')));
    await tester.pump();
    expect(_alert15, findsOneWidget);
  });

  testWidgets('還要 1 小時以上才長大、或都吃過了：不跳提醒卡', (tester) async {
    final cows = [
      for (final c in designCows()) c,
      // #21 2 小時 10 分後長大、還沒吃燕麥
      {
        ...designCow(21, 'yellow', bull: true, stage: 'calf', growMin: 130),
        'need': ['oats'],
      },
    ];
    await _ranch(tester, cows: cows);
    expect(find.byKey(const Key('grow-alert-21')), findsNothing);
    expect(find.byKey(const Key('grow-alert-15')), findsNothing, reason: '設計稿的 #15 都吃過了');
    expect(find.byKey(const Key('want-15')), findsNothing, reason: '集滿了不冒泡泡');
    expect(find.byKey(const Key('want-21')), findsOneWidget, reason: '還沒吃的照樣冒泡泡');
  });

  testWidgets('想吃泡泡跟著走動的小牛（A-11）', (tester) async {
    await _ranch(tester, motion: true, prefs: {SettingsController.growAlertKey: '15@31'});
    await settleImages(tester);
    final want = find.byKey(const Key('want-15'));
    final bubble0 = tester.getCenter(want).dx;
    final cow0 = ranchGame(tester).cowRect(15)!.center.dx;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    final moved = ranchGame(tester).cowRect(15)!.center.dx - cow0;
    expect(moved.abs(), greaterThan(1), reason: '小牛 10 秒內會起步');
    expect(tester.getCenter(want).dx - bubble0, closeTo(moved, 1), reason: '泡泡跟著小牛走');
    // 停掉動畫的計時器（牛走動）
    await tester.pumpWidget(const SizedBox());
  });
}
