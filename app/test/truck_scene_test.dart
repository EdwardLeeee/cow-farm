// A-03 出貨卡車：動畫開著時，確定出貨後播卡車，播完（3.6 秒）或點一下換成評級結果（S20）；
// 減少動態時不播，直接到結果頁。卡車造型從 ui.json 的 anchors.truck 和零件的 viewBox 讀。
// 每個時間點畫面上的數字跟設計稿一樣：test/truck_motion_test.dart。
import 'package:cowfarm/app.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/ui/kit/motion.dart';
import 'package:cowfarm/ui/ship/truck.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'pages/page_case.dart';
import 'pages/s04_cases.dart';

/// 牛的詳細頁（S04），開著 AppMotion。
Future<void> _showCowMoving(WidgetTester tester, DetailApi api, Map<String, dynamic> cow) async {
  Screen.w390.apply(tester);
  final (m, _, _) = await loadedModel(api: api);
  m.openCow('${cow['id']}');
  final settings = settingsFor(AppLang.zhHant, swipeHintSeen);
  await settings.load();
  await tester.pumpWidget(
    AppMotion(
      enabled: true,
      child: CowFarmApp(model: m, settings: settings),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _ship(WidgetTester tester) async {
  await openShip(tester);
  await confirmShip(tester);
  await settleImages(tester); // 卡車的量測、圖讀進來
}

void main() {
  setUpAll(loadAppAssets);

  test('預設的卡車：量測照 ui.json 的 anchors.truck，零件的範圍讀 viewBox', () async {
    final skin = await TruckSkin.loadDefault();
    expect(skin.geometry.size, const Size(270, 152));
    expect(skin.geometry.wheelR, 18);
    expect(skin.geometry.floor, 98);
    expect(skin.geometry.bedCx, 82);
    expect(skin.wheels, const [Offset(62, 128), Offset(204, 128)]);
    expect(skin.hinge, const Offset(12, 100));
    expect(skin.gateOpenDeg, -145);
    expect(skin.backBox, const Rect.fromLTWH(0, 0, 270, 152));
    expect(skin.frontBox, const Rect.fromLTWH(0, 0, 270, 152));
    expect(skin.gateBox, const Rect.fromLTWH(4, 38, 12, 66));
    expect(skin.wheelBox, const Rect.fromLTWH(-20, -20, 40, 40), reason: '輪子的圖以 (0, 128) 為中心');
    expect(skin.namePlate.at, const Offset(83, 96));
    expect(skin.namePlate.size, 11.5);
    expect(skin.namePlate.weight, 900);
    expect(skin.light.rect, const Rect.fromLTWH(13.5, 88, 5.5, 8));
    expect(skin.light.on, const Color(0xFFFFE27A));
    expect(skin.light.off, const Color(0xFFFFF7D6));
  });

  testWidgets('動畫開著：確定出貨後播卡車（A-03），3.6 秒播完換成評級結果（S20）', (tester) async {
    final api = DetailApi(state: detailState(detailCow(3)))..after = detailState(detailCow(11));
    await _showCowMoving(tester, api, detailCow(3));
    await _ship(tester);
    expect(api.calls, contains('ship:3'));
    expect(find.byKey(const Key('truck-scene')), findsOneWidget);
    expect(find.byKey(const Key('ship-result')), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('truck-scene')), findsOneWidget, reason: '還在播');
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('truck-scene')), findsNothing);
    expect(find.byKey(const Key('ship-result')), findsOneWidget);
  });

  testWidgets('點一下跳過：馬上換成評級結果', (tester) async {
    final api = DetailApi(state: detailState(detailCow(3)))..after = detailState(detailCow(11));
    await _showCowMoving(tester, api, detailCow(3));
    await _ship(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('truck-scene')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('truck-scene')), findsNothing);
    expect(find.byKey(const Key('ship-result')), findsOneWidget);
    // 播完的時間到了也不會再換一次
    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(const Key('ship-result')), findsOneWidget);
  });

  testWidgets('減少動態：不播卡車，直接到評級結果（A-03 的減少動態版）', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final api = DetailApi(state: detailState(detailCow(3)))..after = detailState(detailCow(11));
    await _showCowMoving(tester, api, detailCow(3));
    await openShip(tester);
    await confirmShip(tester);
    expect(find.byKey(const Key('truck-scene')), findsNothing);
    expect(find.byKey(const Key('ship-result')), findsOneWidget);
  });
}
