// 協定 v2 的代碼 → 給玩家看的字：錯誤碼（1.4 的表）、牧場名與 #編號（1.6）、新聞標題（3.11）；
// 以及品種表（1.6）跟設計稿 design/m2/src/cow/breeds.js 一致。
import 'dart:io';

import 'package:cowfarm/api/breeds.dart';
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final zh = Strings.forLang(AppLang.zhHant);

  group('錯誤碼 → 字串表的文案（協定 1.4）', () {
    test('有自己文案的碼', () {
      final expected = {
        'not_enough_stock': zh.errNotEnoughStock,
        'cow_not_found': zh.errCowNotFound,
        'field_not_found': zh.errFieldNotFound,
        'listing_not_found': zh.errListingGone,
        'listing_gone': zh.errListingGone,
        'pen_full': zh.penFull,
        'cow_not_adult': zh.errCowNotAdult,
        'already_bred': zh.errAlreadyBred,
        'cow_in_field': zh.errCowInField,
        'cow_listed': zh.errCowListed,
        'cow_not_in_field': zh.errCowNotInField,
        'no_free_field': zh.errNoFreeField,
        'field_occupied': zh.errFieldOccupied,
        'max_level': zh.errMaxLevel,
        'internal': zh.errInternal,
        'sign_in_failed': zh.s13ToastFailed,
        'price_changed': zh.s18FeeChangedTitle,
      };
      expected.forEach((code, text) => expect(zh.errorText(code), text, reason: code));
    });

    test('玩家碰不到、或不認得的碼：通用的「操作失敗，請再試一次」', () {
      for (final code in [
        'bad_request', 'invalid_pair', 'not_found', 'method_not_allowed', 'not_linked', 'not_an_ox', //
        'not_a_bull', 'own_listing', 'provider_already_linked', 'request_id_reused', 'rejected', 'a_new_code',
      ]) {
        expect(zh.errorText(code), zh.unknownError, reason: code);
      }
    });

    test('帶 detail 的碼：還差幾幣、幾分後開放、名字哪裡不行', () {
      expect(zh.errorText('not_enough_coins', detail: {'need': 1000, 'have': 414}), zh.notEnoughCoins(n: '586'));
      // open_at 在遊戲時間 600 秒後；試玩倍率 144 → 現實約 4.2 秒，無條件進位成 5 秒
      expect(
        zh.errorText('not_yet_available', detail: {'open_at': 1600}, gameNow: 1000, timeScale: 144),
        zh.errNotYetAvailable(time: zh.seconds(s: 5)),
      );
      expect(
        zh.errorText('not_yet_available', detail: {'open_at': 1180}, gameNow: 1000),
        zh.errNotYetAvailable(time: zh.minutes(m: 3)),
      );
      for (final (reason, text) in [
        ('too_short', zh.s02ErrShort),
        ('too_long', zh.s02ErrLong),
        ('emoji', zh.s02ErrEmoji),
        ('bad_char', zh.s02ErrChar),
      ]) {
        expect(zh.errorText('invalid_name', detail: {'reason': reason}), text, reason: reason);
      }
    });

    test('三種語言都查得到（不會掉回繁中或空字串）', () {
      for (final lang in AppLang.values) {
        final s = Strings.forLang(lang);
        expect(s.errorText('cow_not_found'), s.errCowNotFound);
        expect(s.errorText('not_enough_coins', detail: {'need': 5, 'have': 1}), s.notEnoughCoins(n: '4'));
      }
    });
  });

  group('牧場名（協定 1.6）', () {
    test('真人用自己取的名字，電腦用詞庫組並加「電腦」，對方刪除了顯示「已刪除的牧場」', () {
      final human = RanchRef.fromJson({'player_id': 31, 'name': '小花的快樂牧場', 'is_bot': false, 'level': 3});
      final bot = RanchRef.fromJson({
        'player_id': 4,
        'name_words': [8, 0, 5],
        'is_bot': true,
        'level': 6,
      });
      final station = RanchRef.fromJson({
        'player_id': null,
        'name_words': [3, 5, 0],
        'is_bot': true,
        'level': null,
      });
      expect(zh.ranchName(human), '小花的快樂牧場');
      expect(zh.ranchText(human), '小花的快樂牧場');
      expect(zh.ranchName(bot), zh.ranchNameFromWords([8, 0, 5]));
      expect(zh.ranchText(bot), '${zh.botPrefix} ${zh.ranchNameFromWords([8, 0, 5])}');
      expect(zh.ranchText(null), zh.s18DeletedRanch);
      expect(Strings.ranchTag(human), '#0031');
      expect(Strings.ranchTag(RanchRef.fromJson({'player_id': 12345, 'name': 'x'})), '#12345');
      expect(Strings.ranchTag(station), isNull, reason: '公營種牛站沒有 #編號');
      // 電腦牧場名照玩家目前的語言組
      final en = Strings.forLang(AppLang.en);
      expect(en.ranchName(bot), en.ranchNameFromWords([8, 0, 5]));
      expect(en.ranchName(bot), isNot(zh.ranchName(bot)));
    });
  });

  test('維護預計恢復時間（S16-01，ends_at_real 換成手機時區後）：月、日、星期、24 小時制的時:分', () {
    final fri = DateTime(2026, 10, 2, 3, 0); // 星期五
    expect(
      zh.maintenanceEta(fri),
      zh.s16Eta(
        date: zh.dateMdw(m: 10, d: 2, w: zh.weekdayName(5), time: '03:00'),
      ),
    );
    expect(zh.maintenanceEta(fri), contains('10 月 2 日（五）03:00'));
    // Dart 的星期日是 7，字串表是 weekday.0
    final th = Strings.forLang(AppLang.th);
    expect(th.maintenanceEta(DateTime(2026, 10, 4, 15, 5)), contains('${th.byKey('weekday.0')} 4/10 15:05'));
  });

  test('新聞標題用代碼查字串表；字串表還沒有的新代碼回空字串，不讓畫面壞掉', () {
    expect(zh.newsHeadline(const NewsItem(id: '1', code: 'milk_up.1')), isNotEmpty);
    expect(
      zh.newsHeadline(const NewsItem(id: '1', code: 'milk_up.1')),
      Strings.forLang(AppLang.zhHant).byKey('news.milk_up.1'),
    );
    expect(zh.newsHeadline(const NewsItem(id: '2', code: 'milk_up.999')), '');
  });

  test('品種表跟設計稿 breeds.js 一樣：用途 × 特徵組合 → 品種、圖鑑順序', () {
    final js = File('../design/m2/src/cow/breeds.js').readAsStringSync();
    final entry = RegExp(r"(\w+): \{(?:\s*//[^\n]*)?\s*name: '[^']*', use: '(\w+)', traits: \{([^}]*)\}");
    var count = 0;
    for (final m in entry.allMatches(js)) {
      final breed = m[1]!;
      final type = switch (m[2]) {
        'dairy' => CowType.dairy,
        'draft' => CowType.dual, // 設計稿叫 draft，協定沿用 dual
        _ => CowType.beef,
      };
      final traits = m[3]!;
      final bits =
          (traits.contains('A: true') ? 1 : 0) |
          (traits.contains('B: true') ? 2 : 0) |
          (traits.contains('C: true') ? 4 : 0);
      expect(kBreedsByType[type]![bits], breed, reason: breed);
      expect(breedInfo(breed)!.tier, bits.toRadixString(2).replaceAll('0', '').length);
      count++;
    }
    expect(count, 24);
    final order = RegExp(r'CODEX_ORDER = \[([^\]]*)\]').firstMatch(js)![1]!;
    expect(kCodexOrder, [for (final m in RegExp(r"'(\w+)'").allMatches(order)) m[1]]);
  });
}
