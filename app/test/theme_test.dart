// 主題與字型（T3）：顏色跟設計稿 base.css 一樣、內建字型的粗細真的會變、泰文接得上、授權有放進 app。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cowfarm/theme/app_theme.dart';
import 'package:cowfarm/theme/tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 測試環境不會自己載入 pubspec 的字型，要從 asset 讀進來。
Future<void> _loadFont(String family, String asset) async {
  await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
}

/// 一行字畫出來有多黑（每個像素的不透明度加總）、多寬。
Future<(double, double)> _ink(String text, TextStyle style) async {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final rec = ui.PictureRecorder();
  tp.paint(ui.Canvas(rec), Offset.zero);
  final img = await rec.endRecording().toImage(tp.width.ceil() + 2, tp.height.ceil() + 2);
  final raw = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
  var ink = 0.0;
  for (var i = 3; i < raw.length; i += 4) {
    ink += raw[i] / 255;
  }
  return (ink, tp.width);
}

void main() {
  test('顏色跟設計稿 base.css 的 :root 一樣', () {
    final css = File('../design/m2/src/css/base.css').readAsStringSync();
    Color cssColor(String name) {
      final m = RegExp('--$name:\\s*#([0-9A-Fa-f]{6})').firstMatch(css);
      expect(m, isNotNull, reason: 'base.css 找不到 --$name');
      return Color(int.parse('FF${m![1]}', radix: 16));
    }

    final pairs = {
      'ink': AppColors.ink,
      'ink-2': AppColors.ink2,
      'ink-3': AppColors.ink3,
      'paper': AppColors.paper,
      'cream': AppColors.cream,
      'line-soft': AppColors.lineSoft,
      'yellow': AppColors.yellow,
      'blue': AppColors.blue,
      'blue-2': AppColors.blue2,
      'green': AppColors.green,
      'green-2': AppColors.green2,
      'pink': AppColors.pink,
      'coral': AppColors.coral,
      'orange': AppColors.orange,
      'red-soft': AppColors.redSoft,
      'up': AppColors.red,
      'down': AppColors.deepGreen,
      'disabled-bg': AppColors.disabledBg,
      'disabled-line': AppColors.disabledLine,
    };
    pairs.forEach((name, color) => expect(color, cssColor(name), reason: '--$name'));
    expect(css, contains('--backdrop: rgba(46, 29, 20, 0.46)'));
  });

  test('漲跌顏色跟著設定：漲紅跌綠或綠漲紅跌', () {
    expect(AppColors.up(upIsRed: true), AppColors.red);
    expect(AppColors.down(upIsRed: true), AppColors.deepGreen);
    expect(AppColors.up(upIsRed: false), AppColors.deepGreen);
    expect(AppColors.down(upIsRed: false), AppColors.red);
  });

  testWidgets('內建的可變字型：粗細真的會變，泰文由 Noto Sans Thai 接上', (tester) async {
    await tester.runAsync(() async {
      await _loadFont(AppText.family, 'assets/fonts/NotoSansTC-VF.ttf');
      await _loadFont(AppText.fallback.first, 'assets/fonts/NotoSansThai-VF.ttf');
      const zh = '牛市牧場 12,345 金幣';
      final (regular, _) = await _ink(zh, AppText.style(32));
      final (bold, _) = await _ink(zh, AppText.style(32, weight: FontWeight.w700));
      final (black, _) = await _ink(zh, AppText.number(32));
      // 研究時量到的墨水量：700 約 1.53 倍、900 約 1.81 倍（docs/research/2026-10-cow-rendering.md）
      expect(bold / regular, greaterThan(1.3));
      expect(black / bold, greaterThan(1.1));

      // 泰文：沒有字型時測試環境會畫成一個字一格的方塊（寬度 = 字數 × 字級）；接上 Noto Sans Thai 就不是
      const th = 'ฟาร์มแสงเช้า';
      final (thInk, thWidth) = await _ink(th, AppText.style(20));
      expect(thInk, greaterThan(0));
      expect(thWidth, isNot(closeTo(th.runes.length * 20.0, 0.5)));
    });
  });

  test('字型的授權有放進第三方授權頁（OFL 1.1）', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFontLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    for (final name in ['Noto Sans TC', 'Noto Sans Thai']) {
      final e = entries.where((e) => e.packages.contains(name)).toList();
      expect(e, isNotEmpty, reason: name);
      expect(e.first.paragraphs.map((p) => p.text).join('\n'), contains('SIL Open Font License'));
    }
  });
}
