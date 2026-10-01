// 牛怎麼畫的實測腳本 6：可變字型（一個檔包含所有粗細）在 Flutter 裡怎麼調粗細。
// 官方文件（FontVariation、字型 cookbook）沒寫 TextStyle.fontWeight 會不會帶動可變字型的 wght 軸，所以實測：
// 同一段字用可變字型（只設 fontWeight／只設 fontVariations）和固定粗細的字型各畫一次，比較墨水量（字有多黑）和像素差異。
// 手動跑：flutter test test/font_test.dart --dart-define=FONT_DIR=<放字型的資料夾> --dart-define=OUT_DIR=<輸出>
// 資料夾要有：NotoSansTC[wght].ttf、NotoSansTC-VF.otf、NotoSansTC-Regular.otf、NotoSansTC-Bold.otf、NotoSansTC-Black.otf、
// NotoSansThai[wdth,wght].ttf（fonts.py 會下載）
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const fontDir = String.fromEnvironment('FONT_DIR');
const outDir = String.fromEnvironment('OUT_DIR');

Future<void> _load(String family, String file) async {
  final bytes = File('$fontDir/$file').readAsBytesSync();
  await (FontLoader(
    family,
  )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
}

/// 把一行字畫成 PNG，回傳墨水量（每個像素的不透明度加總，0–1）和像素。
Future<(double, Uint8List)> _draw(
  String name,
  TextStyle style,
  String text,
) async {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: style.copyWith(fontSize: 48, color: const ui.Color(0xFF000000)),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  const w = 900, h = 80;
  final rec = ui.PictureRecorder();
  tp.paint(ui.Canvas(rec), const ui.Offset(8, 8));
  final img = await rec.endRecording().toImage(w, h);
  final raw = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer
      .asUint8List();
  final png = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer
      .asUint8List();
  File('$outDir/$name.png').writeAsBytesSync(png);
  var ink = 0.0;
  for (var i = 3; i < raw.length; i += 4) {
    ink += raw[i] / 255;
  }
  return (ink, raw);
}

double _diffPct(Uint8List a, Uint8List b) {
  var n = 0, d = 0;
  for (var i = 3; i < a.length; i += 4) {
    if (a[i] == 0 && b[i] == 0) continue;
    n++;
    if ((a[i] - b[i]).abs() > 64) d++;
  }
  return n == 0 ? 0 : 100 * d / n;
}

void main() {
  testWidgets('可變字型的粗細', (tester) async {
    expect(fontDir, isNotEmpty, reason: '要給 --dart-define=FONT_DIR');
    await tester.runAsync(() async {
      Directory(outDir).createSync(recursive: true);
      await _load('VF_TTF', 'NotoSansTC[wght].ttf');
      await _load('VF_OTF', 'NotoSansTC-VF.otf');
      await _load('ST_400', 'NotoSansTC-Regular.otf');
      await _load('ST_900', 'NotoSansTC-Black.otf');
      await _load('ST_700', 'NotoSansTC-Bold.otf');
      await _load('TH_VF', 'NotoSansThai[wdth,wght].ttf');
      const zh = '牛市牧場 12,345 金幣 已滿級';
      const th = 'ฟาร์มแสงเช้าริมน้ำ 12,345';
      final cases = <String, (TextStyle, String)>{
        'st400': (const TextStyle(fontFamily: 'ST_400'), zh),
        'st900': (const TextStyle(fontFamily: 'ST_900'), zh),
        'st700': (const TextStyle(fontFamily: 'ST_700'), zh),
        'vfttf_plain': (const TextStyle(fontFamily: 'VF_TTF'), zh),
        'vfttf_weight900_only': (
          const TextStyle(fontFamily: 'VF_TTF', fontWeight: ui.FontWeight.w900),
          zh,
        ),
        'vfttf_var400': (
          const TextStyle(
            fontFamily: 'VF_TTF',
            fontVariations: [ui.FontVariation.weight(400)],
          ),
          zh,
        ),
        'vfttf_var900': (
          const TextStyle(
            fontFamily: 'VF_TTF',
            fontVariations: [ui.FontVariation.weight(900)],
          ),
          zh,
        ),
        // 實作打算兩個都設（iPhone 上沒驗過 fontWeight 會不會帶動 wght）：確認不會粗上加粗
        'vfttf_both900': (
          const TextStyle(
            fontFamily: 'VF_TTF',
            fontWeight: ui.FontWeight.w900,
            fontVariations: [ui.FontVariation.weight(900)],
          ),
          zh,
        ),
        'vfttf_both700': (
          const TextStyle(
            fontFamily: 'VF_TTF',
            fontWeight: ui.FontWeight.w700,
            fontVariations: [ui.FontVariation.weight(700)],
          ),
          zh,
        ),
        'vfotf_var400': (
          const TextStyle(
            fontFamily: 'VF_OTF',
            fontVariations: [ui.FontVariation.weight(400)],
          ),
          zh,
        ),
        'vfotf_var900': (
          const TextStyle(
            fontFamily: 'VF_OTF',
            fontVariations: [ui.FontVariation.weight(900)],
          ),
          zh,
        ),
        'th_var400': (
          const TextStyle(
            fontFamily: 'TH_VF',
            fontVariations: [ui.FontVariation.weight(400)],
          ),
          th,
        ),
        'th_var900': (
          const TextStyle(
            fontFamily: 'TH_VF',
            fontVariations: [ui.FontVariation.weight(900)],
          ),
          th,
        ),
      };
      final ink = <String, double>{}, px = <String, Uint8List>{};
      for (final e in cases.entries) {
        final (i, raw) = await _draw(e.key, e.value.$1, e.value.$2);
        ink[e.key] = i;
        px[e.key] = raw;
      }
      final lines = <String>['case,ink,ink_vs_st400'];
      for (final k in ink.keys) {
        lines.add(
          '$k,${ink[k]!.round()},${(ink[k]! / ink['st400']!).toStringAsFixed(3)}',
        );
      }
      lines
        ..add('')
        ..add('pair,pct_pixels_alpha_diff_gt64')
        ..add(
          'vfttf_var400 vs st400,${_diffPct(px['vfttf_var400']!, px['st400']!).toStringAsFixed(3)}',
        )
        ..add(
          'vfttf_var900 vs st900,${_diffPct(px['vfttf_var900']!, px['st900']!).toStringAsFixed(3)}',
        )
        ..add(
          'vfttf_both700 vs st700,${_diffPct(px['vfttf_both700']!, px['st700']!).toStringAsFixed(3)}',
        )
        ..add(
          'vfttf_both900 vs vfttf_var900,${_diffPct(px['vfttf_both900']!, px['vfttf_var900']!).toStringAsFixed(3)}',
        )
        ..add(
          'vfotf_var900 vs st900,${_diffPct(px['vfotf_var900']!, px['st900']!).toStringAsFixed(3)}',
        )
        ..add(
          'vfttf_weight900_only vs st900,${_diffPct(px['vfttf_weight900_only']!, px['st900']!).toStringAsFixed(3)}',
        )
        ..add(
          'vfttf_weight900_only vs vfttf_plain,${_diffPct(px['vfttf_weight900_only']!, px['vfttf_plain']!).toStringAsFixed(3)}',
        );
      File('$outDir/fonts.csv').writeAsStringSync('${lines.join('\n')}\n');
    });
  });
}
