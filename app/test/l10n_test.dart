// 字串表（D25）：三種語言的 key 和佔位符一樣、產生的 Dart 跟 design/m2/i18n/ 同步、依資料組的 key 每一組都齊。
import 'dart:io';
import 'dart:math';

import 'package:cowfarm/l10n/gen/strings.g.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/gen_l10n.dart' as gen;

/// 本機開發可以指到別的字串表資料夾試：--dart-define=I18N_DIR=…（CI 用 design/m2/i18n）。
const i18nDir = String.fromEnvironment('I18N_DIR', defaultValue: gen.defaultI18nDir);

void main() {
  final tables = gen.loadTables(i18nDir);

  test('三種語言的 key 集合和佔位符都一樣', () {
    expect(gen.check(tables), isEmpty);
  });

  test('lib/l10n/gen/strings.g.dart 跟字串表同步（字串表改了要在 app/ 跑 dart run tool/gen_l10n.dart）', () {
    expect(File(gen.outPath).readAsStringSync(), gen.generate(tables));
  });

  test('前後刻意留的空白照字串表保留（ceo 2026-10-02）', () {
    const keys = ['s03.penFullSuffix', 's06.lots', 's12.pullHint', 's18.ownerLabel', 'commodityTag', 'bothTag'];
    for (final lang in AppLang.values) {
      for (final k in keys) {
        expect(kStringTables[lang.code]![k], tables[lang.code]![k], reason: '${lang.code} $k');
      }
    }
    expect(kStringTables['en']!['s06.lots']!.startsWith(' '), isTrue, reason: '英文、泰文接在數字後面，前面有空格');
    expect(kStringTables['en']!['s18.ownerLabel']!.endsWith(' '), isTrue, reason: '英文是不換行空格');
  });

  test('依資料組 key 的字，每一組在三種語言都齊', () {
    final breeds = [
      for (final k in kStringTables['zh-Hant']!.keys)
        if (RegExp(r'^breed\.(\w+)\.name$').firstMatch(k) case final m?) m[1]!,
    ];
    expect(breeds, hasLength(25), reason: '24 種牛（企劃書 4.5）加雜種牛 mix（D35，#157）');
    expect(breeds, contains('mix'));
    for (final lang in AppLang.values) {
      final s = Strings.forLang(lang);
      for (final b in breeds) {
        expect(s.breedName(b), isNotEmpty);
        expect(s.breedIntro(b), isNotEmpty);
      }
      for (final t in ['A', 'B', 'C']) {
        expect(s.traitName(t), isNotEmpty);
      }
      for (var i = 0; i < 4; i++) {
        expect(s.tierName(i), isNotEmpty);
      }
      for (var d = 0; d < 7; d++) {
        expect(s.weekdayName(d), isNotEmpty);
      }
      for (final g in ['first', 'second', 'third']) {
        for (var i = 0; i < Strings.nameWordsPerGroup; i++) {
          expect(s.byKey('namegen.$g.$i'), isNotEmpty);
        }
        expect(() => s.byKey('namegen.$g.${Strings.nameWordsPerGroup}'), throwsArgumentError, reason: '每組剛好 12 個');
      }
    }
  });

  test('牧場名照各語言的 namegen.pattern 接（電腦牧場、幫我想一個）', () {
    for (final lang in AppLang.values) {
      final t = kStringTables[lang.code]!;
      final expected = t['namegen.pattern']!
          .replaceAll('{first}', t['namegen.first.3']!)
          .replaceAll('{second}', t['namegen.second.7']!)
          .replaceAll('{third}', t['namegen.third.11']!);
      expect(Strings.forLang(lang).ranchNameFromWords([3, 7, 11]), expected, reason: lang.code);
    }
    // 同一個亂數種子，挑到的詞一樣
    final zh = Strings.forLang(AppLang.zhHant);
    expect(zh.suggestRanchName(Random(1)), zh.suggestRanchName(Random(1)));
  });

  test('佔位符：有給的換掉，沒給的留著（跟設計稿 i18n.js 的 t() 一樣）', () {
    expect(fillTemplate('a {x} b {y}', {'x': 1}), 'a 1 b {y}');
    final zh = Strings.forLang(AppLang.zhHant);
    expect(zh.level(lv: 12), 'Lv 12');
    expect(zh.cowName('holstein', 12), '${zh.breedName('holstein')} #12');
  });

  test('時刻依語言（glossary.md「格式」）：繁中 09:41、英文 9:41 AM、泰文 09:41 น.；中午 12 點、半夜 0 點', () {
    final zh = Strings.forLang(AppLang.zhHant), en = Strings.forLang(AppLang.en), th = Strings.forLang(AppLang.th);
    // 數字跟 AM／PM、น. 之間是不換行空格（U+00A0），不會被拆到兩行
    for (final (h, m, zhText, enText, thText) in [
      (9, 41, '09:41', '9:41\u00a0AM', '09:41\u00a0น.'),
      (0, 0, '00:00', '12:00\u00a0AM', '00:00\u00a0น.'),
      (12, 0, '12:00', '12:00\u00a0PM', '12:00\u00a0น.'),
      (12, 59, '12:59', '12:59\u00a0PM', '12:59\u00a0น.'),
      (13, 5, '13:05', '1:05\u00a0PM', '13:05\u00a0น.'),
      (23, 59, '23:59', '11:59\u00a0PM', '23:59\u00a0น.'),
    ]) {
      final t = DateTime(2026, 10, 2, h, m);
      expect(zh.clock(t), zhText);
      expect(en.clock(t), enText);
      expect(th.clock(t), thText);
    }
  });

  test('今天、昨天：差幾個日曆天（同一天 0、前一天 1；跨月、跨年，差不到 24 小時也是前一天）', () {
    expect(calendarDaysBetween(DateTime(2026, 10, 2, 23, 59), DateTime(2026, 10, 2, 0, 1)), 0);
    expect(calendarDaysBetween(DateTime(2026, 10, 2, 0, 5), DateTime(2026, 10, 1, 23, 50)), 1);
    expect(calendarDaysBetween(DateTime(2026, 3, 1, 9), DateTime(2026, 2, 28, 21)), 1);
    expect(calendarDaysBetween(DateTime(2027, 1, 1, 0, 1), DateTime(2026, 12, 31, 23, 59)), 1);
    expect(calendarDaysBetween(DateTime(2026, 10, 2, 9), DateTime(2026, 9, 30, 21)), 2);
  });

  // CI 在 UTC 跑、沒有夏令時間，這個測試要在有夏令時間的時區才抓得到「當地兩個午夜相減」的錯：
  // TZ=America/New_York flutter test test/l10n_test.dart（2026-03-09 那天舊算法會把昨天算成今天）。
  test('夏令時間切換那天（當地的一天只有 23 或 25 小時）也照日曆算', () {
    for (var d = DateTime(2024); d.year < 2028; d = DateTime(d.year, d.month, d.day + 1)) {
      expect(calendarDaysBetween(DateTime(d.year, d.month, d.day + 1, 12), d), 1, reason: '$d');
      expect(calendarDaysBetween(DateTime(d.year, d.month, d.day + 2, 0, 30), d), 2, reason: '$d');
    }
  });

  test('品種名和「公」之間：英文、泰文空一格，繁中不空（ceo 2026-10-02）', () {
    expect(Strings.forLang(AppLang.zhHant).breedSexGap, '');
    expect(Strings.forLang(AppLang.en).breedSexGap, ' ');
    expect(Strings.forLang(AppLang.th).breedSexGap, ' ');
  });

  test('第一次打開依手機語言：中文 → 繁中、泰文 → 泰文、其他 → 英文（D25）', () {
    expect(AppLang.forDevice(const [Locale('zh', 'TW')]), AppLang.zhHant);
    expect(AppLang.forDevice(const [Locale('zh', 'CN')]), AppLang.zhHant);
    expect(AppLang.forDevice(const [Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans')]), AppLang.zhHant);
    expect(AppLang.forDevice(const [Locale('th', 'TH')]), AppLang.th);
    expect(AppLang.forDevice(const [Locale('en', 'US')]), AppLang.en);
    expect(AppLang.forDevice(const [Locale('ja', 'JP'), Locale('zh', 'TW')]), AppLang.en, reason: '只看第一個偏好語言');
    expect(AppLang.forDevice(const []), AppLang.en);
  });

  test('漲跌顏色的預設：繁中漲紅，英文、泰文漲綠（D25）', () {
    expect(AppLang.zhHant.upIsRedByDefault, isTrue);
    expect(AppLang.en.upIsRedByDefault, isFalse);
    expect(AppLang.th.upIsRedByDefault, isFalse);
  });
}
