// 動畫逐格截圖：A-11 牛在牧場走動（設計稿的 8 頭牛，一輪 4 秒）、A-07 轉身（點 #12 草莓牛轉正面，0.5 秒）、
// A-03 出貨卡車（照設計稿：載走荷斯坦，後面站著荷斯坦公牛、荷斯坦小牛、娟珊，3.6 秒）。
// 390 寬、每點 2 像素（跟設計稿的動畫一樣只出 390），寫到 SHOTS_DIR/anim/<動畫 ID>/<第幾格>.png。
// 只在本機拍，CI 不跑（沒給 SHOTS 就整個跳過）。在 app/ 底下：
//   flutter test --dart-define=SHOTS=1 --dart-define=SHOTS_DIR=build/shots/<PR 編號> test/pages/anim_shots_test.dart
// 拍完用 python3 tool/anim_gif.py build/shots/<PR 編號> 組成 GIF、拼成跟設計稿分鏡一樣時間點的對照。
import 'dart:io';

import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/app.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/ui/kit/motion.dart';
import 'package:cowfarm/ui/ship/truck_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'page_case.dart';
import 's03_cases.dart';

final _shots = const String.fromEnvironment('SHOTS').isNotEmpty;
const _dir = String.fromEnvironment('SHOTS_DIR', defaultValue: 'build/shots/local');

/// 一格 50 毫秒（20 fps）。
const _frame = Duration(milliseconds: 50);

Future<void> _save(WidgetTester tester, String anim, int i) async {
  final png = await capturePng(tester);
  final file = File('$_dir/anim/$anim/${i.toString().padLeft(3, '0')}.png');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(png);
}

Future<void> _ranch(WidgetTester tester) async {
  Screen.w390.apply(tester, dpr: 2);
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
}

void main() {
  if (!_shots) {
    test('動畫截圖只在本機拍（--dart-define=SHOTS=1）', () {}, skip: 'CI 不拍截圖');
    return;
  }
  setUpAll(loadAppAssets);

  testWidgets('A-11 牛在牧場走動：第 4–8 秒（每頭牛都起步了，跟設計稿的時間一樣）', (tester) async {
    await _ranch(tester);
    await tester.pump(const Duration(seconds: 4));
    for (var i = 0; i <= 80; i++) {
      if (i > 0) await tester.pump(_frame);
      await _save(tester, 'A-11', i);
    }
  });

  testWidgets('A-03 出貨卡車：設計稿的那一幕（3.6 秒）', (tester) async {
    Screen.w390.apply(tester, dpr: 2);
    final m = await ranchModel();
    final settings = settingsFor(AppLang.zhHant, swipeHintSeen);
    await settings.load();
    await tester.pumpWidget(CowFarmApp(model: m, settings: settings));
    await tester.pump();
    Cow cow(Map<String, dynamic> j) => Cow.fromJson(j);
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(
          PageRouteBuilder<void>(
            transitionDuration: Duration.zero,
            pageBuilder: (context, _, _) => TruckScene(
              cow: cow(designCow(3, 'holstein')),
              ranchName: '晨光河畔牧場',
              herd: [
                cow(designCow(8, 'holstein', bull: true)),
                cow(designCow(15, 'holstein', stage: 'calf')),
                cow(designCow(7, 'jersey')),
              ],
              onDone: () {},
            ),
          ),
        );
    await tester.pump();
    await settleImages(tester);
    for (var i = 0; i <= 72; i++) {
      if (i > 0) await tester.pump(_frame);
      await _save(tester, 'A-03', i);
    }
  });

  testWidgets('A-07 轉身：點 #12 草莓牛，側面 → 正面（0.5 秒）', (tester) async {
    await _ranch(tester);
    // #12 的節奏 3.3：第 0.7 秒才起步，0.5 秒前還在原位（跟設計稿 A-07 的位置一樣）
    await tapSceneCow(tester, 12);
    await tester.pump();
    for (var i = 0; i <= 10; i++) {
      if (i > 0) await tester.pump(_frame);
      await _save(tester, 'A-07', i);
    }
  });
}
