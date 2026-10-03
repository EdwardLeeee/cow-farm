// S21 牧場資料（D34）：暫定協定的讀法（state.profile、state.achievements、economy.rename_price、RanchRef.avatar）、
// 點頂列的頭像打開、返回關掉、徽章的詳細、不認得的徽章不放、舊的伺服器沒有徽章、頭像跟著 profile.avatar。
// 畫面本身在 test/pages/s21_cases.dart（S21-01、S21-11～13）。
import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/ui/kit/cow_art.dart';
import 'package:cowfarm/ui/profile/profile_page.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'pages/page_case.dart';
import 'pages/s13_cases.dart';
import 'pages/s14_cases.dart';
import 'pages/s21_cases.dart';

final _zh = Strings.forLang(AppLang.zhHant);

String _faceIn(WidgetTester tester, Finder of) =>
    tester.widget<CowFace>(find.descendant(of: of, matching: find.byType(CowFace)).first).breed;

void main() {
  group('協定', () {
    test('profile：頭像、改過幾次名；舊的伺服器沒有 profile 是荷斯坦、次數不知道', () {
      final st = GameState.fromJson({
        ...sampleStateJson(),
        'profile': {'avatar': 'jersey', 'renames': 2},
      });
      expect(st.profile.avatar, 'jersey');
      expect(st.profile.avatarBreed, 'jersey');
      expect(st.profile.renames, 2);
      final old = GameState.fromJson(sampleStateJson());
      expect(old.profile.avatarBreed, 'holstein');
      expect(old.profile.renames, isNull);
      expect(old.achievements, isNull, reason: '舊的伺服器沒有 achievements：不放徽章卡');
    });

    test('economy.rename_price、RanchRef.avatar（電腦、公營種牛站沒有）', () {
      expect(Economy.fromJson({'rename_price': 1000})?.renamePrice, 1000);
      expect(RanchRef.fromJson({'player_id': 7, 'name': 'A', 'avatar': 'wagyu'})?.avatar, 'wagyu');
      expect(RanchRef.fromJson({'player_id': null, 'is_bot': true})?.avatar, isNull);
    });

    test('achievements：一般的、有計數的、分階段的；壞掉的項目跳過', () {
      final list = Achievement.listFrom([
        {'key': 'firstMilk', 'unlocked_at': t0},
        {'key': 'gradeA', 'progress': 1, 'goal': 10},
        {'key': 'rice', 'progress': 1000, 'goal': 1000, 'unlocked_at': t0},
        {
          'key': 'codex',
          'progress': 10,
          'tiers': [
            {'goal': 5, 'unlocked_at': t0},
            {'goal': 12},
            {'goal': 24},
          ],
        },
        {
          'key': 'level',
          'progress': 25,
          'tiers': [
            {'goal': 10, 'unlocked_at': t0},
            {'goal': 20, 'unlocked_at': t0},
          ],
        },
        {'progress': 3},
        'firstShip',
      ])!;
      expect(list.map((a) => a.key), ['firstMilk', 'gradeA', 'rice', 'codex', 'level']);
      final [milk, gradeA, rice, codex, level] = list;
      expect((milk.unlocked, milk.progressPair), (true, null));
      expect((gradeA.unlocked, gradeA.progressPair), (false, (1.0, 10.0)));
      expect((rice.unlocked, rice.progressPair), (true, null), reason: '解鎖了就不寫進度');
      expect((codex.staged, codex.tierAt, codex.unlocked, codex.progressPair), (true, 1, true, (10.0, 12.0)));
      expect((level.tierAt, level.progressPair), (2, null), reason: '全部解鎖了沒有下一階');
    });

    test('分階段的顏色：三階是銅、銀、金，兩階是銀、金', () {
      const bronze = Color(0xFFF2C29B), silver = Color(0xFFE3E7EE), gold = Color(0xFFFFD45E);
      expect([for (var i = 0; i < 3; i++) tierColor(i, 3)], [bronze, silver, gold]);
      expect([for (var i = 0; i < 2; i++) tierColor(i, 2)], [silver, gold]);
    });

    test('每個徽章、每一階在三種語言都有名稱和條件', () {
      for (final lang in AppLang.values) {
        final s = Strings.forLang(lang);
        for (final a in Achievement.listFrom(designAchievements())!) {
          expect(badgeLooks, contains(a.key));
          if (a.staged) {
            for (var i = 1; i <= a.tiers.length; i++) {
              expect(s.achName(a.key, tier: i), isNotEmpty, reason: '${lang.name} ${a.key} $i');
              expect(s.achCond(a.key, tier: i), isNotEmpty, reason: '${lang.name} ${a.key} $i');
            }
          } else {
            expect(s.achName(a.key), isNotEmpty, reason: '${lang.name} ${a.key}');
            expect(s.achCond(a.key), isNotEmpty, reason: '${lang.name} ${a.key}');
          }
        }
      }
    });
  });

  group('牧場資料頁', () {
    setUpAll(loadAppAssets);

    testWidgets('點頂列的頭像打開；返回鈕、系統的返回都回到牧場', (tester) async {
      Screen.w430.apply(tester);
      final m = await showProfile(tester, AppLang.zhHant);
      expect(m.profileOpen, isTrue);
      expect(find.byKey(const Key('prof-card')), findsOneWidget);
      expect(find.byKey(const Key('hud-profile')), findsNothing, reason: '整頁，沒有頂列');
      await tester.tap(find.byKey(const Key('btn-back')));
      await tester.pump();
      expect(m.profileOpen, isFalse);
      expect(find.byKey(const Key('hud-profile')), findsOneWidget);

      await tester.tap(find.byKey(const Key('hud-profile')));
      await tester.pump();
      expect(m.profileOpen, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(m.profileOpen, isFalse);
      expect(find.byKey(const Key('hud-profile')), findsOneWidget);
    });

    testWidgets('點徽章打開詳細；「關閉」、點暗幕都關掉', (tester) async {
      Screen.w430.apply(tester);
      await showProfile(tester, AppLang.zhHant, badge: 'gradeA');
      expect(find.byKey(const Key('ach-detail-gradeA')), findsOneWidget);
      expect(find.text(_zh.s21BadgeLocked), findsOneWidget);
      await tester.tap(find.byKey(const Key('ach-close')));
      await tester.pump();
      expect(find.byKey(const Key('sheet')), findsNothing);

      await tester.tap(find.byKey(const Key('ach-firstMilk')));
      await tester.pump();
      expect(find.byKey(const Key('ach-detail-firstMilk')), findsOneWidget);
      expect(find.text(_zh.s21BadgeDate(date: _zh.dateMd(m: 9, d: 27, time: '10:05'))), findsOneWidget);
      await tester.tapAt(const Offset(215, 120));
      await tester.pump();
      expect(find.byKey(const Key('sheet')), findsNothing);
    });

    testWidgets('伺服器送了 app 不認得的徽章：不放、也不算在總數裡', (tester) async {
      Screen.w430.apply(tester);
      await showProfile(
        tester,
        AppLang.zhHant,
        state: profileState(
          achievements: [
            ...designAchievements(),
            {'key': 'moonCow', 'unlocked_at': t0},
          ],
        ),
      );
      expect(find.byType(BadgeCell), findsNWidgets(18));
      expect(find.byKey(const Key('ach-moonCow')), findsNothing);
      expect(find.text(_zh.s21BadgeCount(n: 7, total: 18)), findsOneWidget);
    });

    testWidgets('舊的伺服器（沒有 achievements）：只有牧場卡，沒有徽章卡', (tester) async {
      Screen.w430.apply(tester);
      await showProfile(tester, AppLang.zhHant, state: {...profileState()}..remove('achievements'));
      expect(find.byKey(const Key('prof-card')), findsOneWidget);
      expect(find.byKey(const Key('ach-card')), findsNothing);
    });

    testWidgets('窄於 340 是 3 欄：第 4 個徽章在第二列的第一格', (tester) async {
      Screen.w320.apply(tester);
      await showProfile(tester, AppLang.zhHant);
      final first = tester.getRect(find.byKey(const Key('ach-firstMilk')));
      final fourth = tester.getRect(find.byKey(const Key('ach-gradeA')));
      expect(fourth.left, closeTo(first.left, 0.5));
      expect(fourth.top, greaterThan(first.bottom));
    });

    testWidgets('頭像跟著 profile.avatar：頂列、牧場資料、設定頁的牧場卡', (tester) async {
      Screen.w430.apply(tester);
      await showProfile(tester, AppLang.zhHant, state: profileState(avatar: 'jersey'));
      expect(_faceIn(tester, find.byKey(const Key('prof-avatar'))), 'jersey');
      await tester.tap(find.byKey(const Key('btn-back')));
      await tester.pump();
      expect(_faceIn(tester, find.byKey(const Key('hud-profile'))), 'jersey');
      await tester.tap(find.byKey(const Key('gear')));
      await tester.pump();
      expect(_faceIn(tester, find.byKey(const Key('me-card'))), 'jersey');
    });
  });

  group('其他畫自己牧場頭像的地方', () {
    setUpAll(loadAppAssets);

    testWidgets('S13-08：帳號已經備份的那個牧場讀它自己的頭像（RanchRef.avatar）', (tester) async {
      Screen.w430.apply(tester);
      final api = FakeGameApi()
        ..linkError = ApiException(409, 'account_in_use', '這個帳號已經綁了別的牧場', {
          'provider': 'apple',
          'ranch': {'player_id': 1234, 'name': '晨光河畔牧場', 'is_bot': false, 'level': 4, 'avatar': 'wagyu'},
          'switch_ticket': 'ticket-1',
          'ticket_expires_at_real': t0 + 600,
        });
      await showBackup(tester, AppLang.zhHant, api: api, newRanch: true);
      await tester.tap(find.byKey(const Key('sso-apple')));
      await tester.pump();
      await tester.pump();
      expect(_faceIn(tester, find.byKey(const Key('other-ranch'))), 'wagyu');
    });

    testWidgets('S14-04 歡迎回來：找回來的牧場的頭像', (tester) async {
      Screen.w430.apply(tester);
      final api = FakeGameApi()
        ..switchedStateJson = {
          ...recoveredState(),
          'profile': {'avatar': 'highland'},
        };
      await showRecover(tester, AppLang.zhHant, api: api);
      await tester.tap(find.byKey(const Key('sso-apple')));
      await tester.pump();
      await tester.pump();
      expect(_faceIn(tester, find.byKey(const Key('welcome-card'))), 'highland');
    });
  });
}
