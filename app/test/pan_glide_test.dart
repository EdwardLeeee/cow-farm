// A-12 左右滑動牧場（設計稿 anims.js 的 A12）：手指拖多少場景就移多少；放開以後照放開時的速度再滑一小段停下，
// 到兩邊就停、不回彈。減少動態：拖多少就移多少，放開不滑行。
import 'package:cowfarm/app.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/ui/kit/motion.dart';
import 'package:cowfarm/ui/ranch/scene.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pages/page_case.dart';
import 'pages/s03_cases.dart';

Future<void> _ranchWithMotion(WidgetTester tester, {bool reduced = false}) async {
  final m = await ranchModel();
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
}

double _pan(WidgetTester tester) => tester.widget<RanchScene>(find.byType(RanchScene)).pan;

/// 在場景的空地（上面天空那一帶）往左甩 [dx]。
Future<void> _fling(WidgetTester tester, double dx, double speed) async {
  final box = tester.getRect(find.byType(RanchScene));
  await tester.flingFrom(Offset(box.center.dx + 60, box.top + 150), Offset(dx, 0), speed);
  await tester.pump();
}

void main() {
  setUpAll(loadAppAssets);

  testWidgets('開著動畫：往左甩，放開以後場景再往右滑一小段才停', (tester) async {
    Screen.w390.apply(tester);
    await _ranchWithMotion(tester);
    expect(_pan(tester), 0);
    await _fling(tester, -80, 400);
    final released = _pan(tester);
    expect(released, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 100));
    final gliding = _pan(tester);
    expect(gliding, greaterThan(released), reason: '放開以後還在滑');
    await tester.pump(const Duration(seconds: 3));
    final stopped = _pan(tester);
    expect(stopped, greaterThan(gliding));
    expect(stopped, lessThan(kMaxPan), reason: '慢慢甩只滑一小段，不會到底');
    await tester.pump(const Duration(milliseconds: 500));
    expect(_pan(tester), stopped, reason: '停下來了');
  });

  testWidgets('開著動畫：用力甩，滑到右邊就停（不超過、不回彈）', (tester) async {
    Screen.w390.apply(tester);
    await _ranchWithMotion(tester);
    await _fling(tester, -150, 3000);
    await tester.pump(const Duration(seconds: 3));
    expect(_pan(tester), kMaxPan);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_pan(tester), kMaxPan);
  });

  testWidgets('減少動態：拖多少就移多少，放開不滑行', (tester) async {
    Screen.w390.apply(tester);
    await _ranchWithMotion(tester, reduced: true);
    await _fling(tester, -80, 400);
    final released = _pan(tester);
    expect(released, greaterThan(0));
    await tester.pump(const Duration(seconds: 1));
    expect(_pan(tester), released);
  });
}
