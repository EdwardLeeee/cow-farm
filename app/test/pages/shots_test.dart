// 截圖：每個頁面狀態在 430、390 各拍一張（每點 2 像素，跟設計稿 boards 一樣），寫到 SHOTS_DIR/<語言>/<頁面 ID>-<寬>.png。
// 只在本機拍，CI 不跑（沒給 SHOTS 就整個跳過）。在 app/ 底下：
//   flutter test --dart-define=SHOTS=1 --dart-define=SHOTS_DIR=build/shots/<PR 編號> test/pages/shots_test.dart
//   其他語言：--dart-define=SHOTS_LANGS=zh-Hant,en,th；只拍某些頁面：--dart-define=SHOTS_ONLY=S01,S02-03
// 拍完用 python3 tool/shots_compare.py build/shots/<PR 編號> 跟設計稿並排。
import 'dart:io';

import 'package:cowfarm/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

import 'page_case.dart';

/// 給了 SHOTS（任何值，例 1）才拍。bool.fromEnvironment 只認 true，所以讀字串。
final _shots = const String.fromEnvironment('SHOTS').isNotEmpty;
const _dir = String.fromEnvironment('SHOTS_DIR', defaultValue: 'build/shots/local');
const _langs = String.fromEnvironment('SHOTS_LANGS', defaultValue: 'zh-Hant');
const _only = String.fromEnvironment('SHOTS_ONLY');

void main() {
  if (!_shots) {
    test('截圖只在本機拍（--dart-define=SHOTS=1）', () {}, skip: 'CI 不拍截圖');
    return;
  }
  setUpAll(loadAppFonts);
  final langs = [for (final code in _langs.split(',')) AppLang.fromCode(code.trim())!];
  final only = _only.isEmpty ? null : _only.split(',').map((s) => s.trim()).toList();
  final cases = [
    for (final c in pageCases)
      if (only == null || only.any(c.id.startsWith)) c,
  ];

  test('要拍的頁面狀態', () => expect(cases, isNotEmpty, reason: 'pageCases 是空的，或 SHOTS_ONLY 沒對到'));
  for (final c in cases) {
    for (final lang in langs) {
      for (final screen in [Screen.w430, Screen.w390]) {
        testWidgets('${c.id} ${c.name}：${screen.label} ${lang.code}', (tester) async {
          screen.apply(tester, dpr: 2);
          await c.show(tester, lang);
          await settleImages(tester);
          final png = await capturePng(tester, crop: c.crop);
          final file = File('$_dir/${lang.code}/${c.id}-${screen.label}.png');
          file.parent.createSync(recursive: true);
          file.writeAsBytesSync(png);
        });
      }
    }
  }
}
