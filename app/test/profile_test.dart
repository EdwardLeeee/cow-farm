// S21 牧場資料（D34）：暫定協定的讀法（state.profile、state.achievements、economy.rename_price、RanchRef.avatar）、
// 點頂列的頭像打開、返回關掉、徽章的詳細、不認得的徽章不放、舊的伺服器沒有徽章、頭像跟著 profile.avatar；
// 改名（第一次免費、之後要錢、錢不夠、名字跟現在一樣、伺服器不收）、換頭像（只能選發現過的、一樣的不送）。
// 畫面本身在 test/pages/s21_cases.dart（S21-01～13）。
import 'package:cowfarm/api/breeds.dart' show kHybrid;
import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/ui/kit/cow_art.dart';
import 'package:cowfarm/ui/profile/profile_page.dart';
import 'package:flutter/material.dart' show TextField;
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

  group('改名', () {
    setUpAll(loadAppAssets);

    AppButton confirm(WidgetTester tester) => tester.widget<AppButton>(find.byKey(const Key('rename-confirm')));

    testWidgets('一開始放現在的名字、按鈕不能按；改了才能按；第一次免費，改好回到牧場資料、提示下次的價錢', (tester) async {
      Screen.w430.apply(tester);
      final m = await showRename(tester, AppLang.zhHant, name: null);
      expect(tester.widget<TextField>(find.byKey(const Key('rename-field'))).controller!.text, '晨光河畔牧場');
      expect(confirm(tester).onPressed, isNull, reason: '跟現在的名字一樣');
      expect(find.text(_zh.s21RenameFree), findsOneWidget);
      await tester.enterText(find.byKey(const Key('rename-field')), '小花的快樂牧場');
      await tester.pump();
      expect(confirm(tester).onPressed, isNotNull);
      final coins = m.state!.coins;
      await tester.tap(find.byKey(const Key('rename-confirm')));
      await tester.pump();
      await tester.pump();
      expect((m.api as FakeGameApi).calls, contains('rename:小花的快樂牧場'));
      expect(m.renameOpen, isFalse);
      expect(m.profileOpen, isTrue);
      expect(m.ranchName, '小花的快樂牧場');
      expect(m.state!.coins, coins, reason: '第一次免費');
      expect(find.text(_zh.s21RenamedFirst(price: '1,000')), findsOneWidget);
    });

    testWidgets('第二次以後寫價錢；錢不夠：按鈕停用、寫還差多少', (tester) async {
      Screen.w430.apply(tester);
      await showRename(tester, AppLang.zhHant, renames: 2);
      expect(find.text(_zh.s21RenamePaid(price: '1,000')), findsOneWidget);
      expect(find.byKey(const Key('rename-short')), findsNothing);
      await showRename(tester, AppLang.zhHant, renames: 1, coins: 999);
      expect(find.text(_zh.notEnoughCoins(n: '1')), findsOneWidget);
      expect(confirm(tester).onPressed, isNull);
    });

    testWidgets('伺服器不收這個名字（invalid_name）：提示在輸入框下面，改了名字就清掉', (tester) async {
      Screen.w430.apply(tester);
      final m = await showRename(tester, AppLang.zhHant);
      (m.api as FakeGameApi).renameError = ApiException(400, 'invalid_name', 'x', {'reason': 'emoji'});
      await tester.tap(find.byKey(const Key('rename-confirm')));
      await tester.pump();
      await tester.pump();
      expect(m.renameOpen, isTrue);
      final err = _zh.errorText('invalid_name', detail: const {'reason': 'emoji'});
      expect(find.text(err), findsOneWidget);
      await tester.enterText(find.byKey(const Key('rename-field')), '小花的牧場');
      await tester.pump();
      expect(find.text(err), findsNothing);
    });

    testWidgets('改名頁按返回（返回鈕、手機的返回）回到牧場資料', (tester) async {
      Screen.w430.apply(tester);
      final m = await showRename(tester, AppLang.zhHant);
      await tester.tap(find.byKey(const Key('btn-back')));
      await tester.pump();
      expect((m.renameOpen, m.profileOpen), (false, true));
      await tester.tap(find.byKey(const Key('prof-name-btn')));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect((m.renameOpen, m.profileOpen), (false, true));
      expect((m.api as FakeGameApi).calls.where((c) => c.startsWith('rename')), isEmpty);
    });
  });

  group('換頭像', () {
    setUpAll(loadAppAssets);

    testWidgets('一開始選現在的頭像；點還沒發現的：寫提示、選的不變；選一樣的按「用這個頭像」只是關掉', (tester) async {
      Screen.w430.apply(tester);
      final m = await showAvatar(tester, AppLang.zhHant);
      expect(find.text(_zh.breedName('holstein')), findsOneWidget);
      await tester.tap(find.byKey(const Key('av-starry')));
      await tester.pump();
      expect(find.text(_zh.s21AvatarLocked(name: _zh.breedName('starry'))), findsOneWidget);
      expect(find.text(_zh.breedName('holstein')), findsOneWidget, reason: '鎖住的不能選');
      await tester.tap(find.byKey(const Key('av-use')));
      await tester.pump();
      expect(find.byKey(const Key('sheet')), findsNothing);
      expect((m.api as FakeGameApi).calls.where((c) => c.startsWith('avatar')), isEmpty);
    });

    testWidgets('選發現過的按「用這個頭像」：送給伺服器、關掉、提示，牧場資料和頂列都換成新的', (tester) async {
      Screen.w430.apply(tester);
      final m = await showAvatar(tester, AppLang.zhHant, pick: 'wagyu');
      await tester.tap(find.byKey(const Key('av-use')));
      await tester.pump();
      await tester.pump();
      expect((m.api as FakeGameApi).calls, contains('avatar:wagyu'));
      expect(find.byKey(const Key('sheet')), findsNothing);
      expect(find.text(_zh.s21AvatarDone), findsOneWidget);
      expect(
        tester
            .widget<CowFace>(find.descendant(of: find.byKey(const Key('prof-avatar')), matching: find.byType(CowFace)))
            .breed,
        'wagyu',
      );
      await tester.tap(find.byKey(const Key('btn-back')));
      await tester.pump();
      expect(
        tester
            .widget<CowFace>(find.descendant(of: find.byKey(const Key('hud-profile')), matching: find.byType(CowFace)))
            .breed,
        'wagyu',
      );
    });

    testWidgets('伺服器說還沒發現（avatar_locked）：面板留著，下面寫那種牛還沒發現', (tester) async {
      Screen.w430.apply(tester);
      final m = await showAvatar(tester, AppLang.zhHant, pick: 'jersey');
      (m.api as FakeGameApi).avatarError = ApiException(409, 'avatar_locked', 'x');
      await tester.tap(find.byKey(const Key('av-use')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('sheet')), findsOneWidget);
      expect(find.text(_zh.s21AvatarLocked(name: _zh.breedName('jersey'))), findsOneWidget);
    });

    testWidgets('「其他」一排放雜種牛：圖鑑還沒發現是剪影加鎖，點了寫「還沒發現「雜種牛」」；不算在 n / 24 種', (tester) async {
      Screen.w430.apply(tester);
      await showAvatar(tester, AppLang.zhHant);
      expect(find.text(_zh.s09Other), findsOneWidget);
      final hybrid = find.byKey(const Key('av-hybrid'));
      expect(hybrid, findsOneWidget);
      expect(
        tester.getRect(hybrid).top,
        greaterThan(tester.getRect(find.byKey(const Key('av-starry'))).bottom),
        reason: '在 24 種下面',
      );
      expect(find.text(_zh.s21AvatarCount(n: 10, total: 24)), findsOneWidget);
      await tester.tap(hybrid);
      await tester.pump();
      expect(find.text(_zh.s21AvatarLocked(name: _zh.byKey('breed.mix.name'))), findsOneWidget);
    });

    testWidgets('圖鑑發現了雜種牛（codex 的 hybrid）：可以選，送 breed: hybrid；頂列畫雜種牛的臉', (tester) async {
      Screen.w430.apply(tester);
      final state = profileState();
      state['codex'] = [
        ...(state['codex'] as List),
        {'breed': kHybrid, 'found_at': t0},
      ];
      final m = await showProfile(tester, AppLang.zhHant, state: state);
      await tester.tap(find.byKey(const Key('prof-av')));
      await tester.pump();
      expect(find.text(_zh.s21AvatarCount(n: 10, total: 24)), findsOneWidget, reason: '雜種牛不算在 24 種裡');
      await tester.tap(find.byKey(const Key('av-hybrid')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(_zh.byKey('breed.mix.name')), findsOneWidget, reason: '上面那一列寫雜種牛');
      await tester.tap(find.byKey(const Key('av-use')));
      await tester.pump();
      await tester.pump();
      expect((m.api as FakeGameApi).calls, contains('avatar:$kHybrid'));
      await tester.tap(find.byKey(const Key('btn-back')));
      await tester.pump();
      expect(_faceIn(tester, find.byKey(const Key('hud-profile'))), kHybrid);
    });

    testWidgets('窄於 340：沒有上面那一列、格子 5 欄', (tester) async {
      Screen.w320.apply(tester);
      await showAvatar(tester, AppLang.zhHant);
      expect(find.byKey(const Key('av-preview')), findsNothing);
      final first = tester.getRect(find.byKey(const Key('av-holstein')));
      final sixth = tester.getRect(find.byKey(const Key('av-velvetBlack')));
      expect(sixth.left, closeTo(first.left, 0.5));
    });
  });
}
