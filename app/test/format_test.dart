// 數字和時間的寫法跟設計稿一樣：test/fixtures/format_cases.json 是 tool/gen_format_cases.mjs 用設計稿自己的
// 函式（design/m2/src/js/fixtures.js、i18n.js）算出來的。設計稿改了寫法，重跑那個腳本再看這個測試。
import 'dart:convert';
import 'dart:io';

import 'package:cowfarm/l10n/format.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = jsonDecode(File('test/fixtures/format_cases.json').readAsStringSync()) as Map<String, dynamic>;

  for (final lang in AppLang.values) {
    final c = cases[lang.code] as Map<String, dynamic>;
    final s = Strings.forLang(lang);
    List<List<dynamic>> rows(String name) => (c[name] as List).cast<List<dynamic>>();

    group(lang.code, () {
      test('千分位、固定小數（fmt）', () {
        for (final r in rows('fmt')) {
          expect(fmt(r[0] as num), r[1], reason: '${r[0]}');
        }
        for (final r in rows('fmt1')) {
          expect(fmt(r[0] as num, 1), r[1], reason: '${r[0]}');
        }
        for (final r in rows('fmt2')) {
          expect(fmt(r[0] as num, 2), r[1], reason: '${r[0]}');
        }
      });

      test('縮寫（compact：預設一萬起、窄手機十萬起、頂列一百萬起）', () {
        for (final r in rows('compact')) {
          expect(compact(r[0] as num, lang), r[1], reason: '${r[0]}');
        }
        for (final r in rows('compact100k')) {
          expect(compact(r[0] as num, lang, from: 100000), r[1], reason: '${r[0]}');
        }
        for (final r in rows('compact1m')) {
          expect(compact(r[0] as num, lang, from: 1000000), r[1], reason: '${r[0]}');
        }
      });

      test('排行榜的大數字（compactBig）', () {
        for (final r in rows('compactBig')) {
          expect(compactBig(r[0] as num, lang), r[1], reason: '${r[0]}');
        }
      });

      test('百分比（pct）', () {
        for (final r in rows('pct')) {
          expect(pct(r[0] as num), r[1], reason: '${r[0]}');
        }
        for (final r in rows('pct0')) {
          expect(pct(r[0] as num, 0), r[1], reason: '${r[0]}');
        }
      });

      test('時間長度、多久以前、日期', () {
        for (final r in rows('dur')) {
          final d = (r[0] as Map).cast<String, int>();
          expect(
            s.duration(d: d['d'] ?? 0, h: d['h'] ?? 0, m: d['m'] ?? 0, s: d['s'] ?? 0),
            r[1],
            reason: '$d',
          );
        }
        for (final r in rows('ago')) {
          final a = (r[0] as Map).cast<String, int>();
          expect(
            s.timeAgo(min: a['min'], h: a['h'], d: a['d']),
            r[1],
            reason: '$a',
          );
        }
        for (final r in rows('date')) {
          final d = (r[0] as Map).cast<String, Object>();
          final text = s.dateTime(
            today: d['day'] == 'today',
            yesterday: d['day'] == 'yesterday',
            month: d['m'] as int?,
            day: d['d'] as int?,
            time: d['time'] as String,
          );
          expect(text, r[1], reason: '$d');
        }
      });
    });
  }
}
