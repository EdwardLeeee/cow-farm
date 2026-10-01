// 牛和介面素材不漂移（T3；ceo 2026-10-02）：app/assets/ 裡的檔由 cow-ui 的 design/m2/harness/assetexport.mjs 產生，不手改。
// - 檔案集合、每個檔的 SHA-256 跟描述檔（cows.json、ui.json）一樣：抓手改、多檔、少檔。
// - 描述檔記的產生器來源檔雜湊跟 repo 現在的一樣：改了產生器（或匯出腳本）卻沒重新匯出，這裡會紅。
// 改了產生器就在 design/m2 跑 assetexport.mjs，design/ 和 app/assets/ 一起 commit。
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

String _sha256(File f) => sha256.convert(f.readAsBytesSync()).toString();

Map<String, dynamic> _json(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// 描述檔記的產生器來源（repo 根目錄的相對路徑 → SHA-256）跟現在的檔一樣。
void _expectGeneratorUnchanged(Map<String, dynamic> manifest, String name) {
  final generator = (manifest['generator'] as Map).cast<String, String>();
  expect(generator, isNotEmpty);
  generator.forEach((path, hash) {
    final f = File('../$path');
    expect(f.existsSync(), isTrue, reason: '$name 記的產生器檔不見了：$path');
    expect(_sha256(f), hash, reason: '$path 改了，但 $name 沒有重新匯出（在 design/m2 跑 assetexport.mjs）');
  });
}

/// 資料夾裡的檔（相對路徑）跟描述檔列的一樣，雜湊也一樣。
void _expectFilesMatch(String dir, Map<String, String> expected, {Set<String> ignore = const {}}) {
  final actual = {
    for (final f in Directory(dir).listSync(recursive: true).whereType<File>())
      f.path.substring(dir.length + 1).replaceAll(r'\', '/'): f,
  }..removeWhere((k, _) => ignore.contains(k));
  expect(actual.keys.toSet().difference(expected.keys.toSet()), isEmpty, reason: '$dir 多了描述檔沒列的檔');
  expect(expected.keys.toSet().difference(actual.keys.toSet()), isEmpty, reason: '$dir 少了描述檔列的檔');
  expected.forEach((path, hash) => expect(_sha256(actual[path]!), hash, reason: '$dir/$path 被改過（不能手改）'));
}

void main() {
  final cows = _json('assets/cows/cows.json');
  final ui = _json('assets/ui/ui.json');

  test('牛：檔案和雜湊跟 cows.json 一樣', () {
    final images = (cows['images'] as Map).cast<String, dynamic>();
    _expectFilesMatch('assets/cows/svg', {
      for (final e in images.entries) '${e.key}.svg': (e.value as Map)['sha256'] as String,
    });
  });

  test('介面素材：檔案和雜湊跟 ui.json 一樣', () {
    final files = (ui['files'] as Map).cast<String, dynamic>();
    _expectFilesMatch(
      'assets/ui',
      {for (final e in files.entries) e.key: (e.value as Map)['sha256'] as String},
      ignore: {'ui.json'},
    );
  });

  test('產生器沒有改了卻沒重新匯出', () {
    _expectGeneratorUnchanged(cows, 'cows.json');
    _expectGeneratorUnchanged(ui, 'ui.json');
  });

  test('每個組合都有圖：24 種 × 公母 × 小牛／成牛 × 側面／正面 × 朝左（＋需要的朝右）× 變體', () {
    final breeds = (cows['breeds'] as Map).cast<String, dynamic>();
    expect(breeds, hasLength(24), reason: '24 種牛（企劃書 4.5）');
    final images = (cows['images'] as Map).cast<String, dynamic>();
    var expected = 0;
    for (final breed in breeds.keys) {
      final info = (breeds[breed] as Map).cast<String, dynamic>();
      final variants = (info['seeds'] as List).length;
      expect(variants, anyOf(1, 4), reason: breed);
      final facings = info['right'] == true ? ['left', 'right'] : ['left'];
      for (final sex in ['cow', 'bull']) {
        for (final age in ['calf', 'adult']) {
          for (final pose in ['side', 'front']) {
            for (final facing in facings) {
              for (var v = 0; v < variants; v++) {
                final name = '${breed}_${sex}_${age}_${pose}_${facing}_v$v';
                expect(images.containsKey(name), isTrue, reason: name);
                expected++;
              }
            }
          }
        }
      }
    }
    expect(images.length, expected, reason: '沒有多餘的組合');
    // 研究時量到的：會變花紋的 9 種、有高光要另外畫朝右的 12 種（docs/research/2026-10-cow-rendering.md）
    expect(breeds.values.where((b) => ((b as Map)['seeds'] as List).length == 4), hasLength(9));
    expect(breeds.values.where((b) => (b as Map)['right'] == true), hasLength(12));
  });

  testWidgets('打包進 app 的牛讀得出來，大小跟 cows.json 一樣（執行時讀 SVG，T3）', (tester) async {
    await tester.runAsync(() async {
      const name = 'holstein_cow_adult_side_left_v0';
      final meta = ((cows['images'] as Map)[name] as Map).cast<String, dynamic>();
      final svg = await rootBundle.loadString('assets/cows/svg/$name.svg');
      final info = await vg.loadPicture(SvgStringLoader(svg), null);
      expect(info.size.width, closeTo((meta['w'] as num).toDouble(), 0.01));
      expect(info.size.height, closeTo((meta['h'] as num).toDouble(), 0.01));
      info.picture.dispose();
      expect(await rootBundle.loadString('assets/ui/ui.json'), isNotEmpty);
    });
  });
}
