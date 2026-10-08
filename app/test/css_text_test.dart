// 字的基線（CssParagraph 的註解）：
// - Flutter 的行高多出來的部分上下平分（app 的 Material 3 主題預設）：基線 = 行高 / 2 + (1.16 − 0.288) / 2 × 字級。
// - CssParagraph 的補正是經驗值：公式當成照比例分，所以字跟 Chrome 的基線（CssLine.metrics）差一點（14／21 高 0.22）。
//   截圖的字落在整數的像素列，這樣 14／21 的對話框內文剛好跟設計稿同一列（2026-10-08 量過，ceo 決定不改）。
//   改這裡要重拍所有用到 CssParagraph 的畫面，看每張跟設計稿的差異。
import 'package:cowfarm/theme/app_theme.dart';
import 'package:cowfarm/theme/tokens.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pages/page_case.dart';

void main() {
  setUpAll(loadAppAssets);

  // 用到 CssParagraph 的字級／行高（.dialog .body 14／21、刪除牧場 14／22、.ach-name 12／16、.ach-cond 15／22…）
  // 和 CssParagraph 現在把字畫得比 Chrome 的基線高多少（經驗值；負的是低）
  const cases = [
    (12.0, 16.0, -0.414),
    (13.0, 19.0, 0.053),
    (14.0, 21.0, 0.219),
    (14.0, 22.0, 0.52),
    (15.0, 22.0, 0.084),
  ];

  Future<RenderParagraph> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Material(
          child: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    );
    return tester.renderObject<RenderParagraph>(find.byType(RichText).first);
  }

  for (final (size, line, high) in cases) {
    testWidgets('$size／$line：Flutter 上下平分；CssParagraph 畫得比 Chrome 的基線高 $high', (tester) async {
      final style = AppText.style(size, weight: FontWeight.w700, lineHeight: line);
      final plain = await pump(tester, Text('牧場ABC', style: style));
      expect(
        plain.computeDistanceToActualBaseline(TextBaseline.alphabetic),
        closeTo(line / 2 + (1.16 - 0.288) / 2 * size, 0.01),
        reason: '主題的預設是上下平分',
      );
      final p = await pump(tester, CssParagraph(const TextSpan(text: '牧場ABC'), style: style));
      final top = p.localToGlobal(Offset.zero).dy;
      final baseline = top + p.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      final (above, _) = CssLine.metrics(TextSpan(text: ' ', style: style));
      expect(above - baseline, closeTo(high, 0.01), reason: '經驗值：改了要重拍所有用到的畫面比對');
    });
  }
}
