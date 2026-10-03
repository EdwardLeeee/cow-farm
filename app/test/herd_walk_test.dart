// A-11 牛在牧場走動、A-07 轉身。動作的數字照設計稿 anims.js：下面的參考值是用 node 跑 anims.js 的
// walkPose、A07.frame 原始函式算出來的（設計稿的 seg、inOut、outBack）。
// 牧場開著 AppMotion（main.dart）時牛會走；點一頭牛轉正面停下來，小名片對準停下的地方；再點一次轉回側面，從停下的
// 地方接著走。手機設定「減少動態」時牛站在原位，點到直接換成正面。
import 'dart:math' as math;

import 'package:cowfarm/app.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/kit/motion.dart';
import 'package:cowfarm/ui/ranch/herd.dart';
import 'package:cowfarm/ui/ranch/scene.dart';
import 'package:cowfarm/ui/ranch/walk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pages/page_case.dart';
import 'pages/s03_cases.dart';

RanchScene ranchScene(WidgetTester tester) => tester.widget<RanchScene>(find.byType(RanchScene));

/// 牧場（設計稿的 8 頭牛），開著 AppMotion。
Future<GameModel> _pumpWalkingRanch(WidgetTester tester) async {
  Screen.w430.apply(tester);
  final m = await ranchModel();
  final settings = settingsFor(AppLang.zhHant, swipeHintSeen);
  await settings.load();
  await tester.pumpWidget(
    AppMotion(
      enabled: true,
      child: CowFarmApp(model: m, settings: settings),
    ),
  );
  await tester.pump();
  await settleImages(tester);
  return m;
}

void main() {
  setUpAll(loadAppAssets);

  test('走路的姿勢跟 anims.js 的 walkPose 一樣', () {
    // [t, 走多遠, 節奏, 小牛, x, 往回走, 彈, 搖]
    const ref = <List<Object>>[
      [0.1, 18.0, 0.9, false, 16.320699708, false, 1.041320974, 0.954544226],
      [0.5, 26.0, 0.0, true, 4.737609329, false, 3.740938811, -2.493959207],
      [1.37, 12.0, 1.1, false, 10.183854227, true, 2.113429276, -1.93731017],
      [2.05, 16.0, 2.6, false, 6.405247813, false, 1.041320974, -0.954544226],
      [3.3, 18.0, 2.0, false, 17.973760933, false, 1.876395558, -1.720029261],
      [5.0, 16.0, 3.3, false, 0.629737609, false, 1.041320974, 0.954544226],
      [6.21, 16.0, 0.2, false, 14.39251312, true, 1.230958266, -1.12837841],
      [7.77, 26.0, 0.0, true, 0.0, false, 0.0, 0.0],
      [9.4, 12.0, 1.6, false, 1.119533528, true, 1.041320974, 0.954544226],
    ];
    for (final r in ref) {
      final p = designWalkPose(r[0] as double, WalkPlan(r[1] as double, r[2] as double), calf: r[3] as bool);
      final why = 't=${r[0]}';
      expect(p.x, closeTo(r[4] as double, 1e-6), reason: why);
      expect(p.back, r[5], reason: why);
      expect(p.bob, closeTo(r[6] as double, 1e-6), reason: why);
      expect(p.tilt, closeTo(r[7] as double, 1e-6), reason: why);
    }
  });

  test('一打開大家在原位：每頭牛等自己的節奏輪到才起步，起步以後跟設計稿一樣', () {
    const plan = WalkPlan(18, 0.9); // 等 3.1 秒
    for (final t in [0.0, 1.0, 3.0]) {
      final p = walkPose(t, plan);
      expect((p.x, p.bob, p.tilt, p.back), (0.0, 0.0, 0.0, false), reason: 't=$t');
    }
    for (final t in [3.1, 3.5, 5.0, 9.9]) {
      expect(walkPose(t, plan).x, designWalkPose(t, plan).x, reason: 't=$t');
    }
    // 節奏 0 的一打開就走
    expect(walkPose(0.5, const WalkPlan(26, 0), calf: true).x, closeTo(4.737609329, 1e-6));
  });

  test('轉身跟 anims.js 的 A07.frame 一樣：先側面收窄，0.22 秒換正面展開、跳一下', () {
    // [t, 正面, 左右縮放, 跳多高]
    const ref = <List<Object>>[
      [0.0, false, 1.0, 0.0],
      [0.05, false, 0.953042825, 0.0],
      [0.11, false, 0.5, 0.0],
      [0.21, false, 0.001, 0.0],
      [0.22, true, 0.001, 0.0],
      [0.3, true, 0.992869782, 6.25465186],
      [0.36, true, 1.095099144, 8.0],
      [0.44, true, 1.0, 4.987918415],
      [0.5, true, 1.0, 0.0],
    ];
    for (final r in ref) {
      final p = turnPose(r[0] as double);
      expect(p.front, r[1], reason: 't=${r[0]}');
      expect(p.scaleX, closeTo(r[2] as double, 1e-6), reason: 't=${r[0]}');
      expect(p.hop, closeTo(r[3] as double, 1e-6), reason: 't=${r[0]}');
    }
  });

  test('前 8 個位置照設計稿的 WALK（依設計稿牛的編號）', () {
    expect(
      [for (final w in kDesignWalk) (w.dist, w.phase)],
      [
        (18.0, 0.9), // #3
        (12.0, 1.1), // #5
        (16.0, 2.6), // #7
        (12.0, 1.6), // #8
        (18.0, 2.0), // #11
        (16.0, 3.3), // #12
        (16.0, 0.2), // #14
        (26.0, 0.0), // #15（小牛）
      ],
    );
    expect(kHerdWalk.take(8).map((w) => (w.dist, w.phase)), kDesignWalk.map((w) => (w.dist, w.phase)));
  });

  test('其他 32 個位置照規則（ceo 2026-10-03）：最多 18、不到 8 就原地；不進障礙物；同一排前面留 12；節奏用黃金比例錯開', () {
    expect(kHerdWalk, hasLength(kHerdSlots.length));
    // 障礙物外面再留 12（跟 tool/herd_walk.py 一樣）
    bool blocked(double x, double y) =>
        math.pow((x - 560) / 162, 2) + math.pow((y - 474) / 74, 2) < 1 ||
        ((x - 640).abs() < 62 && y < 382) ||
        ((x - 366).abs() < 52 && y > 478) ||
        x < 20 ||
        x > 760;
    for (var i = 0; i < kHerdWalk.length; i++) {
      final w = kHerdWalk[i], slot = kHerdSlots[i], dir = slot.right ? 1 : -1;
      if (i >= 8) {
        expect(w.dist == 0 || (w.dist >= 8 && w.dist <= 18), isTrue, reason: '位置 $i 走 ${w.dist}');
        expect(w.phase, closeTo((i * 0.618034 * 4) % 4, 0.006), reason: '位置 $i 的節奏');
        // 原本站的地方可能就在障礙物外圍 12 裡（排位置時的位置），只看走出去的每一步
        for (var d = 1.0; d <= w.dist; d++) {
          expect(blocked(slot.x + dir * d, slot.y), isFalse, reason: '位置 $i 走到 $d 碰到障礙物');
        }
      }
      // 不管節奏怎麼錯開都不會撞：設計稿的 8 頭往前走也不會走到新位置的牛前面 12 以內
      if (w.dist == 0) continue;
      for (var j = 0; j < kHerdSlots.length; j++) {
        final other = kHerdSlots[j], ahead = (other.x - slot.x) * dir;
        if (j == i || (other.y - slot.y).abs() > 40 || ahead <= 0) continue;
        final toward = other.right != slot.right;
        expect(
          w.dist + (toward ? kHerdWalk[j].dist : 0),
          lessThanOrEqualTo(ahead - 12),
          reason: '位置 $i 跟前面的位置 $j 留不到 12',
        );
      }
    }
  });

  test('原地一搖一搖（距離 0）：只彈、搖，不轉身', () {
    const plan = WalkPlan(0, 0);
    for (var t = 0.0; t < 8; t += 0.05) {
      final p = walkPose(t, plan);
      expect(p.x, 0);
      expect(p.back, isFalse, reason: '第 $t 秒');
    }
    expect(walkPose(0.5, plan).bob, greaterThan(0), reason: '會一搖一搖');
  });

  testWidgets('牛會走；點到轉正面、停在走到的地方，名片對準它；再點一次轉回側面，從停下的地方接著走', (tester) async {
    await _pumpWalkingRanch(tester);
    final game = ranchGame(tester);
    // #15（小牛，第 8 個位置）：節奏 0，一打開就起步
    expect(game.dxOf(15), 0);
    await tester.pump(const Duration(milliseconds: 500));
    final walked = game.dxOf(15);
    expect(walked, closeTo(walkPose(0.5, kDesignWalk[7], calf: true).x, 1e-6), reason: '朝右走');
    expect(sceneCowAsset(tester, 15), isNot(contains('_front_')));

    await tapSceneCow(tester, 15);
    await tester.pump();
    expect(game.dxOf(15), walked, reason: '在走到的地方轉身，不跳回原位');
    await tester.pump(const Duration(milliseconds: 100));
    expect(sceneCowAsset(tester, 15), isNot(contains('_front_')), reason: '前 0.22 秒是側面收窄');
    await tester.pump(const Duration(milliseconds: 500));
    expect(sceneCowAsset(tester, 15), contains('_front_'));
    expect(game.dxOf(15), walked, reason: '正面的牛不走路');
    // 名片對準停下的牛：左邊 = 頭的 x − 43
    final scene = tester.getTopLeft(find.byType(RanchScene));
    final placement = CowPlacement.of(
      ranchScene(tester).cows.firstWhere((c) => c.cow.id == 15),
      SceneFit(tester.getSize(find.byType(RanchScene)), 0),
      dx: walked,
    )!;
    expect(tester.getRect(find.byKey(const Key('cow-pop'))).left, closeTo(scene.dx + placement.head.dx - 43, 0.01));

    await tapSceneCow(tester, 15);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(sceneCowAsset(tester, 15), isNot(contains('_front_')), reason: '轉回側面（倒著播 0.5 秒）');
    expect(game.dxOf(15), walked);
    await tester.pump(const Duration(milliseconds: 200));
    expect(game.dxOf(15), closeTo(walkPose(0.7, kDesignWalk[7], calf: true).x, 1e-6), reason: '從停下的地方接著走');
  });

  testWidgets('減少動態：牛站在原位，點到直接換成正面（不轉）', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pumpWalkingRanch(tester);
    final game = ranchGame(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(game.dxOf(15), 0);
    await tapSceneCow(tester, 15);
    await tester.pump();
    expect(sceneCowAsset(tester, 15), contains('_front_'));
  });

  testWidgets('去田裡的耕牛不在場景裡（S03-10），也不走', (tester) async {
    final m = await _pumpWalkingRanch(tester);
    final working = [
      for (final c in m.state!.cows)
        if (c.fieldIndex != null) c.id,
    ];
    expect(working, isNotEmpty);
    for (final id in working) {
      expect(ranchGame(tester).cowRect(id), isNull, reason: '#$id');
    }
  });
}
