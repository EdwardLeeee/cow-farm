// 牛怎麼畫的實測腳本 2：用 flutter_svg 把產生器匯出的 SVG 畫成點陣圖，存 PNG，量解析與轉圖的時間。
// 不是 CI 的測試；手動跑：
//   flutter test test/render_test.dart --dart-define=SVG_DIR=<export.mjs 的 svg 資料夾> --dart-define=OUT_DIR=<輸出> [--dart-define=SCALE=3]
// 輸出：<OUT_DIR>/<名稱>.png（尺寸 = ceil(SVG 寬高 × SCALE)），<OUT_DIR>/timing.csv。
// 資料夾裡是 vector_graphics_compiler 預先編譯的 .vec 時，改讀 .vec（量預先編譯這條路）。
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// 從記憶體讀 .vec 的 BytesLoader。
class _VecLoader extends BytesLoader {
  const _VecLoader(this.bytes);
  final ByteData bytes;

  @override
  Future<ByteData> loadBytes(BuildContext? context) async => bytes;
}

const svgDir = String.fromEnvironment('SVG_DIR');
const outDir = String.fromEnvironment('OUT_DIR');
const scaleArg = String.fromEnvironment('SCALE', defaultValue: '3');

void main() {
  testWidgets('flutter_svg 畫牛', (tester) async {
    expect(svgDir, isNotEmpty, reason: '要給 --dart-define=SVG_DIR');
    final scale = double.parse(scaleArg);
    await tester.runAsync(() async {
      var files = Directory(svgDir)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.svg'))
          .toList();
      final vec = files.isEmpty;
      if (vec) {
        files = Directory(svgDir)
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.vec'))
            .toList();
      }
      files.sort((a, b) => a.path.compareTo(b.path));
      Directory(outDir).createSync(recursive: true);
      final rows = <String>[
        'name,width_px,height_px,parse_us,raster_us,rgba_bytes',
      ];
      for (final f in files) {
        // export.mjs 的 SVG 是 <名稱>.svg；vector_graphics_compiler 的輸出是 <名稱>.svg.vec。
        final name = f.uri.pathSegments.last
            .replaceAll('.vec', '')
            .replaceAll('.svg', '');
        final sw = Stopwatch()..start();
        final info = vec
            ? await vg.loadPicture(
                _VecLoader(ByteData.sublistView(f.readAsBytesSync())),
                null,
              )
            : await vg.loadPicture(SvgStringLoader(f.readAsStringSync()), null);
        final parseUs = sw.elapsedMicroseconds;
        final w = (info.size.width * scale).ceil(),
            h = (info.size.height * scale).ceil();
        sw
          ..reset()
          ..start();
        final rec = ui.PictureRecorder();
        ui.Canvas(rec)
          ..scale(scale)
          ..drawPicture(info.picture);
        final pic = rec.endRecording();
        final img = await pic.toImage(w, h);
        final rasterUs = sw.elapsedMicroseconds;
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$outDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
        rows.add('$name,$w,$h,$parseUs,$rasterUs,${w * h * 4}');
        info.picture.dispose();
        pic.dispose();
        img.dispose();
      }
      File('$outDir/timing.csv').writeAsStringSync('${rows.join('\n')}\n');
    });
  });
}
