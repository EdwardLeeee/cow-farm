// app 圖示（D32：娟珊的牛臉特寫）都用 tool/gen_icons.py 從 design/m4/icon/ 產生，不手改。這裡檢查沒有漂移：
// 直接複製的（iOS 1024、Android 432、網頁版）跟原圖逐位元相同；縮出來的每個尺寸都在、大小對，iOS 不透明。
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

const _src = '../design/m4/icon';
const _ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const _res = 'android/app/src/main/res';

/// PNG 的寬、高、色彩類型（IHDR）。色彩類型 2 是 RGB（不透明），6 是 RGBA。
(int, int, int) _png(String path) {
  final b = File(path).readAsBytesSync();
  expect(ascii.decode(b.sublist(1, 4)), 'PNG', reason: path);
  final d = ByteData.sublistView(b);
  return (d.getUint32(16), d.getUint32(20), b[25]);
}

void _same(String app, String design) =>
    expect(File(app).readAsBytesSync(), File('$_src/$design').readAsBytesSync(), reason: '$app 要跟 $design 一樣');

void main() {
  test('iOS：1024 跟 design/m4/icon/ios-1024.png 逐位元相同', () {
    _same('$_ios/Icon-App-1024x1024@1x.png', 'ios-1024.png');
  });

  test('iOS：Contents.json 列的每一張都在、大小對、不透明', () {
    final json = jsonDecode(File('$_ios/Contents.json').readAsStringSync()) as Map<String, dynamic>;
    final images = (json['images'] as List).cast<Map<String, dynamic>>();
    expect(images, isNotEmpty);
    for (final img in images) {
      final name = img['filename'] as String;
      final pt = double.parse((img['size'] as String).split('x').first);
      final scale = int.parse((img['scale'] as String).replaceAll('x', ''));
      final px = (pt * scale).round();
      final (w, h, type) = _png('$_ios/$name');
      expect((w, h), (px, px), reason: name);
      expect(type, 2, reason: '$name 要不透明（沒有 alpha）');
    }
  });

  test('Android：adaptive icon 的前景、背景各 5 種密度（xxxhdpi 就是原圖），舊版的 ic_launcher 也換了', () {
    const density = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};
    for (final e in density.entries) {
      final dir = '$_res/mipmap-${e.key}';
      final layer = (108 * e.value).round();
      expect(_png('$dir/ic_launcher_foreground.png'), (layer, layer, 6), reason: '${e.key} 前景（透明底）');
      expect(_png('$dir/ic_launcher_background.png'), (layer, layer, 2), reason: '${e.key} 背景');
      final legacy = (48 * e.value).round();
      expect(_png('$dir/ic_launcher.png'), (legacy, legacy, 2), reason: '${e.key} 舊版');
    }
    _same('$_res/mipmap-xxxhdpi/ic_launcher_foreground.png', 'android-前景-432.png');
    _same('$_res/mipmap-xxxhdpi/ic_launcher_background.png', 'android-背景-432.png');
    final xml = File('$_res/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync();
    expect(xml, contains('@mipmap/ic_launcher_background'));
    expect(xml, contains('@mipmap/ic_launcher_foreground'));
    expect(File('android/app/src/main/AndroidManifest.xml').readAsStringSync(), contains('@mipmap/ic_launcher'));
  });

  test('網頁版：分頁的小圖示和 manifest 的圖示跟原圖逐位元相同', () {
    _same('web/favicon.png', 'web-favicon-32.png');
    _same('web/icons/Icon-192.png', 'web-192.png');
    _same('web/icons/Icon-512.png', 'web-512.png');
    _same('web/icons/Icon-maskable-192.png', 'web-maskable-192.png');
    _same('web/icons/Icon-maskable-512.png', 'web-maskable-512.png');
    final manifest = jsonDecode(File('web/manifest.json').readAsStringSync()) as Map<String, dynamic>;
    final icons = (manifest['icons'] as List).cast<Map<String, dynamic>>();
    for (final i in icons) {
      expect(File('web/${i['src']}').existsSync(), isTrue, reason: '${i['src']}');
    }
    expect(icons.where((i) => i['purpose'] == 'maskable'), hasLength(2));
  });
}
