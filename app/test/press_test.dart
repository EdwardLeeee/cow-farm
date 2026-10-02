// 按下的樣子（G-11～G-13，使用者 2026-10-02 核准）：浮起的元件往下移、陰影變 1；平的元件蓋顏色；
// 減少動態只蓋顏色；停用的不變；放開 0.1 秒彈回。

import 'package:cowfarm/ui/kit/kit.dart';
import 'package:cowfarm/ui/kit/press.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

/// 按鈕本身（有框和陰影的那一層）。
Finder _face(String key) => find.descendant(of: find.byKey(Key(key)), matching: find.byType(Container)).first;

double _shadow(WidgetTester tester, String key) =>
    (tester.widget<Container>(_face(key)).decoration! as BoxDecoration).boxShadow!.first.offset.dy;

/// 有沒有蓋上按下的顏色。
bool _tinted(WidgetTester tester, String key) => tester
    .widgetList<DecoratedBox>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(DecoratedBox)))
    .any((d) => d.position == DecorationPosition.foreground && (d.decoration as BoxDecoration).color != null);

Future<TestGesture> _press(WidgetTester tester, String key) async {
  final g = await tester.startGesture(tester.getCenter(find.byKey(Key(key))));
  await tester.pump(const Duration(milliseconds: 150)); // 一碰就變（有捲動的地方要等點擊判定）
  return g;
}

void main() {
  testWidgets('大按鈕：按下往下 3、陰影變 1，底邊不動；放開 0.1 秒彈回', (tester) async {
    await _pump(tester, AppButton('好', key: const Key('b'), kind: ButtonKind.primary, onPressed: () {}));
    final top = tester.getRect(_face('b')).top;
    expect(_shadow(tester, 'b'), 4);
    final g = await _press(tester, 'b');
    expect(tester.getRect(_face('b')).top, top + 3);
    expect(_shadow(tester, 'b'), 1);
    expect(_tinted(tester, 'b'), isFalse, reason: '浮起的元件不蓋顏色');
    await g.up();
    await tester.pump(); // 彈回的動畫從下一格開始算
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.getRect(_face('b')).top, inExclusiveRange(top, top + 3), reason: '彈回中');
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getRect(_face('b')).top, top);
    expect(_shadow(tester, 'b'), 4);
  });

  testWidgets('小按鈕：往下 2、陰影變 1', (tester) async {
    await _pump(tester, AppButton('收奶', key: const Key('b'), small: true, onPressed: () {}));
    final top = tester.getRect(_face('b')).top;
    expect(_shadow(tester, 'b'), 3);
    final g = await _press(tester, 'b');
    expect(tester.getRect(_face('b')).top, top + 2);
    expect(_shadow(tester, 'b'), 1);
    await g.up();
  });

  testWidgets('減少動態：不移動、陰影不變，只蓋一層顏色；放開立刻回去', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pump(tester, AppButton('好', key: const Key('b'), onPressed: () {}));
    final top = tester.getRect(_face('b')).top;
    final g = await _press(tester, 'b');
    expect(tester.getRect(_face('b')).top, top);
    expect(_shadow(tester, 'b'), 4);
    expect(_tinted(tester, 'b'), isTrue);
    await g.up();
    await tester.pump();
    expect(_tinted(tester, 'b'), isFalse);
  });

  testWidgets('停用、處理中的按了不會變', (tester) async {
    for (final b in [
      const AppButton('好', key: Key('b')),
      AppButton('好', key: const Key('b'), busy: true, onPressed: () {}),
    ]) {
      await _pump(tester, b);
      final top = tester.getRect(_face('b')).top;
      final shadow = _shadow(tester, 'b');
      final g = await _press(tester, 'b');
      expect(tester.getRect(_face('b')).top, top);
      expect(_shadow(tester, 'b'), shadow);
      expect(_tinted(tester, 'b'), isFalse);
      await g.up();
      await tester.pump(const Duration(milliseconds: 200));
    }
  });

  testWidgets('平的元件（分頁、關閉鈕）：蓋一層顏色，不移動', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      Pressable(
        key: const Key('flat'),
        onTap: () => taps++,
        builder: (context, look) => PressTint(tint: look.tint, child: const SizedBox(width: 60, height: 44)),
      ),
    );
    final top = tester.getRect(find.byKey(const Key('flat'))).top;
    final g = await _press(tester, 'flat');
    expect(_tinted(tester, 'flat'), isTrue);
    expect(tester.getRect(find.byType(SizedBox).last).top, top);
    await g.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(_tinted(tester, 'flat'), isFalse);
    expect(taps, 1);
  });

  testWidgets('按著的時候元件被拿掉（例：提示時間到收起來）：不會出錯', (tester) async {
    await _pump(tester, AppButton('加大倉庫', key: const Key('b'), small: true, onPressed: () {}));
    final g = await _press(tester, 'b');
    await _pump(tester, const SizedBox());
    await g.cancel();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('按下的顏色是 12% 的可可色', () {
    expect(kPressTint, const Color.fromRGBO(75, 51, 38, 0.12));
  });
}
