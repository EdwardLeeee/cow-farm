// 矮手機（高 600 以下，例 320×568；設計稿 kit.css、screens.css 的 @media (max-height: 600px)，#172）：
// 對話框在安全區裡置中、上內距 14、按鈕上面 12，不蓋到狀態列；出貨確認的牛圖 60（平常 76）。
// S21 換頭像在 320 寬一排 6 格在 profile_test。
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/ui/kit/cow_art.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pages/page_case.dart';
import 'pages/s04_cases.dart';

Rect _dialog(WidgetTester tester) => tester.getRect(find.byKey(const Key('dialog')));

Size _shipCow(WidgetTester tester) =>
    tester.getSize(find.descendant(of: find.byKey(const Key('ship-head')), matching: find.byType(CowPicture)));

void main() {
  setUpAll(loadAppAssets);

  for (final lang in AppLang.values) {
    testWidgets('320×568（${lang.name}）：出貨確認在安全區裡置中，上緣不蓋到狀態列，牛圖 60', (tester) async {
      Screen.w320.apply(tester);
      await showShip(tester, lang);
      final r = _dialog(tester);
      expect(r.top, greaterThanOrEqualTo(Screen.w320.safeTop), reason: '不蓋到狀態列');
      expect(r.bottom, lessThanOrEqualTo(568 - Screen.w320.safeBottom));
      expect(r.center.dy, closeTo((Screen.w320.safeTop + 568 - Screen.w320.safeBottom) / 2, 0.5), reason: '安全區的正中間');
      expect(_shipCow(tester), const Size(60, 60));
    });
  }

  testWidgets('390×844：一樣在整個畫面的正中間，牛圖 76', (tester) async {
    Screen.w390.apply(tester);
    await showShip(tester, AppLang.zhHant);
    expect(_dialog(tester).center.dy, closeTo(844 / 2, 0.5));
    expect(_shipCow(tester), const Size(76, 76));
  });
}
