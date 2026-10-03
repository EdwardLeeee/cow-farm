// S21 牧場資料的頁面狀態（設計稿 s21.js）：S21-01 牧場資料（長頁）、S21-02／03 換頭像、S21-04～09 改名、S21-10 頭像換好了、
// S21-11～13 徽章的詳細。成就徽章照設計稿的 BADGES（發現 10 種、借出 2 次、稻米 184 公斤、總資產 58,920…）。
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:cowfarm/ui/profile/profile_page.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
import 'page_case.dart';
import 's03_cases.dart';

final _zh = Strings.forLang(AppLang.zhHant);

/// 設計稿的「現在」：2026-10-02 12:00（手機時區），跟 S18 一樣。解鎖的日期照這個算（昨天、9 月 28 日）。
final _designNow = DateTime(2026, 10, 2, 12);
double _at(DateTime at) => t0 - _designNow.difference(at).inSeconds;

/// 設計稿 s21.js 的 BADGES（暫定協定 `state.achievements`）：一般的有 unlocked_at，有計數的加 progress、goal；
/// 分階段的有 progress 和 tiers（每一階的 goal、unlocked_at）。
List<Map<String, dynamic>> designAchievements() => [
  {'key': 'firstMilk', 'unlocked_at': _at(DateTime(2026, 9, 27, 10, 5))},
  {'key': 'firstSale', 'unlocked_at': _at(DateTime(2026, 9, 27, 10, 21))},
  {'key': 'firstShip', 'unlocked_at': _at(DateTime(2026, 9, 28, 15, 40))},
  {'key': 'gradeA', 'progress': 1, 'goal': 10},
  {'key': 'newLife', 'unlocked_at': _at(DateTime(2026, 9, 29, 13, 42))},
  {'key': 'borrow', 'unlocked_at': _at(DateTime(2026, 9, 28, 20, 18))},
  {'key': 'popularBull', 'progress': 2, 'goal': 10},
  {'key': 'rice', 'progress': 184, 'goal': 1000},
  {
    'key': 'codex',
    'progress': 10,
    'tiers': [
      {'goal': 5, 'unlocked_at': _at(DateTime(2026, 9, 28, 9, 30))},
      {'goal': 12},
      {'goal': 24},
    ],
  },
  {'key': 'legend', 'unlocked_at': _at(DateTime(2026, 10, 1, 7, 30))},
  {
    'key': 'level',
    'progress': 4,
    'tiers': [
      {'goal': 10},
      {'goal': 20},
    ],
  },
  {
    'key': 'rich',
    'progress': 58920,
    'tiers': [
      {'goal': 100000},
      {'goal': 1000000},
    ],
  },
  for (final k in ['tailwind', 'weekChamp', 'pureBreed', 'healer', 'clean', 'trucks']) {'key': k},
];

/// 設計稿 fixtures.js 的 FOUND：圖鑑發現過的 10 種（換頭像只能選這些）。
const designFound = [
  'holstein',
  'fluffyHolstein',
  'jersey',
  'chocolate',
  'strawberry',
  'yellow',
  'highland',
  'buffalo',
  'angus',
  'wagyu', //
];

/// 設計稿的牧場（晨光河畔牧場 #1234、Lv 4、頭像荷斯坦、還沒改過名）加成就徽章。[renames] 是改過幾次名，[coins] 是金幣。
Map<String, dynamic> profileState({
  List<Map<String, dynamic>>? achievements,
  String? avatar,
  int renames = 0,
  double coins = 12480,
}) => {
  ...ranchState(coins: coins),
  'player_id': 1234,
  'real_time': _designNow.millisecondsSinceEpoch / 1000,
  'profile': {'avatar': ?avatar, 'renames': renames},
  'economy': {...?(ranchState()['economy'] as Map<String, dynamic>?), 'rename_price': 1000},
  'codex': [
    for (final b in designFound) {'breed': b, 'found_at': t0},
  ],
  'achievements': achievements ?? designAchievements(),
};

/// 系統鍵盤的高度（設計稿 s02.js 的 KB_H），跟 S02-03 一樣。
const _keyboardHeight = {430: 300.0, 390: 292.0, 360: 280.0, 320: 254.0};

/// 牧場資料 → 點頭像打開換頭像；[pick] 是再點哪一格。
Future<GameModel> showAvatar(WidgetTester tester, AppLang lang, {String? pick}) async {
  final m = await showProfile(tester, lang);
  await tester.tap(find.byKey(const Key('prof-av')));
  await tester.pump();
  if (pick != null) {
    await tester.tap(find.byKey(Key('av-$pick')));
    await tester.pump(const Duration(milliseconds: 200)); // 按下的顏色放開後 0.1 秒退掉
  }
  await settleImages(tester);
  return m;
}

/// 牧場資料 → 點牧場名打開改名頁，打 [name]（null 就留著現在的名字）；[keyboard] 是系統鍵盤開著（S21-05）。
Future<GameModel> showRename(
  WidgetTester tester,
  AppLang lang, {
  String? name = '小花的快樂牧場',
  int renames = 0,
  double coins = 12480,
  bool keyboard = false,
}) async {
  final m = await showProfile(
    tester,
    lang,
    state: profileState(renames: renames, coins: coins),
  );
  if (keyboard) {
    final dpr = tester.view.devicePixelRatio;
    final width = (tester.view.physicalSize.width / dpr).round();
    // 鍵盤蓋住 Home 指示條：下面的安全區變 0，鍵盤高度放在 viewInsets（跟 iPhone 回報的一樣）
    tester.view
      ..viewInsets = FakeViewPadding(bottom: _keyboardHeight[width]! * dpr)
      ..padding = FakeViewPadding(top: tester.view.padding.top);
  }
  await tester.tap(find.byKey(const Key('prof-name-btn')));
  await tester.pump();
  if (name != null) {
    await tester.enterText(find.byKey(const Key('rename-field')), name);
    await tester.pump();
  }
  if (!keyboard) FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.pump(); // 鍵盤開著時，捲到整顆按鈕看得到（畫完那一格之後才捲）
  return m;
}

AppButton _button(WidgetTester tester, String key) => tester.widget<AppButton>(find.byKey(Key(key)));

/// 在牧場點頂列的頭像，打開牧場資料；[badge] 是再點開哪一個徽章的詳細。
Future<GameModel> showProfile(
  WidgetTester tester,
  AppLang lang, {
  String? badge,
  Map<String, dynamic>? state,
  bool tall = false,
}) async {
  final m = await ranchModel(state: state ?? profileState());
  await pumpAppIn(tester, m, lang, prefs: swipeHintSeen);
  await tester.tap(find.byKey(const Key('hud-profile')));
  await tester.pump();
  await settleImages(tester);
  if (tall) await growToFit(tester, find.byKey(const Key('profile')));
  if (badge != null) {
    await tester.ensureVisible(find.byKey(Key('ach-$badge')));
    await tester.pump();
    await tester.tap(find.byKey(Key('ach-$badge')));
    await tester.pump();
    await settleImages(tester);
  }
  return m;
}

final s21Cases = [
  PageCase(
    'S21-02',
    '換頭像：只能選圖鑑裡發現過的（選了娟珊）',
    (tester, lang) => showAvatar(tester, lang, pick: 'jersey'),
    check: (tester) {
      expect(find.text(_zh.s21AvatarTitle), findsOneWidget);
      expect(find.byKey(const Key('av-preview')), findsOneWidget);
      expect(find.text(_zh.breedName('jersey')), findsOneWidget);
      expect(find.text(_zh.s21AvatarCount(n: 10, total: 24)), findsOneWidget);
      // 6 欄：第 7 格在第二列的第一格
      final first = tester.getRect(find.byKey(const Key('av-holstein')));
      final seventh = tester.getRect(find.byKey(const Key('av-chocolate')));
      expect(seventh.left, closeTo(first.left, 0.5));
      expect(seventh.top, closeTo(first.bottom + 8, 0.5));
      expect(_button(tester, 'av-use').onPressed, isNotNull);
    },
  ),
  PageCase(
    'S21-03',
    '換頭像：點了還沒發現的牛',
    (tester, lang) async {
      await showAvatar(tester, lang, pick: 'jersey');
      await tester.tap(find.byKey(const Key('av-starry')));
      await tester.pump(const Duration(milliseconds: 200));
    },
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.text(_zh.s21AvatarLocked(name: _zh.breedName('starry'))), findsOneWidget);
      expect(find.text(_zh.breedName('jersey')), findsOneWidget, reason: '選的還是娟珊');
    },
  ),
  PageCase(
    'S21-04',
    '改名：第一次（改名（免費））',
    (tester, lang) => showRename(tester, lang),
    check: (tester) {
      expect(find.text(_zh.s21RenameTitle), findsOneWidget);
      expect(find.text(_zh.s21RenameFree), findsOneWidget);
      expect(find.text('14 / 16'), findsOneWidget);
      expect(_button(tester, 'rename-confirm').onPressed, isNotNull);
    },
  ),
  PageCase(
    'S21-05',
    '改名：打字中（鍵盤開著）',
    (tester, lang) => showRename(tester, lang, name: '小花的快樂', keyboard: true),
    check: (tester) {
      expect(find.text('10 / 16'), findsOneWidget);
      final button = tester.getRect(find.byKey(const Key('rename-confirm')));
      expect(button.bottom, lessThanOrEqualTo(932 - 300 + 0.5), reason: '按鈕在鍵盤上面');
    },
  ),
  PageCase(
    'S21-06',
    '改名：第二次以後（改名（1,000 幣））',
    (tester, lang) => showRename(tester, lang, renames: 1),
    crop: find.byKey(const Key('namer')),
    check: (tester) {
      expect(find.text(_zh.s21RenamePaid(price: '1,000')), findsOneWidget);
      expect(_button(tester, 'rename-confirm').onPressed, isNotNull);
    },
  ),
  PageCase(
    'S21-07',
    '改名：金幣不夠',
    (tester, lang) => showRename(tester, lang, renames: 1, coins: 320),
    crop: find.byKey(const Key('namer')),
    check: (tester) {
      expect(find.text(_zh.notEnoughCoins(n: '680')), findsOneWidget);
      expect(_button(tester, 'rename-confirm').onPressed, isNull);
    },
  ),
  PageCase(
    'S21-08',
    '改名：名字不能用（規則同 S02-05）',
    (tester, lang) => showRename(tester, lang, name: '小花牧場🐮'),
    crop: find.byKey(const Key('namer')),
    check: (tester) {
      expect(find.text(_zh.s02ErrEmoji), findsOneWidget);
      expect(_button(tester, 'rename-confirm').onPressed, isNull);
    },
  ),
  PageCase(
    'S21-09',
    '改名好了：回到牧場資料，提示下次改名的價錢',
    (tester, lang) async {
      await showRename(tester, lang);
      await tester.tap(find.byKey(const Key('rename-confirm')));
      await tester.pump();
      await tester.pump();
      await settleImages(tester);
    },
    check: (tester) {
      expect(find.byKey(const Key('prof-card')), findsOneWidget);
      expect(find.text('小花的快樂牧場'), findsOneWidget);
      expect(find.text(_zh.s21RenamedFirst(price: '1,000')), findsOneWidget);
    },
  ),
  PageCase(
    'S21-10',
    '頭像換好了',
    (tester, lang) async {
      await showAvatar(tester, lang, pick: 'jersey');
      await tester.tap(find.byKey(const Key('av-use')));
      await tester.pump();
      await tester.pump();
      await settleImages(tester);
    },
    check: (tester) {
      expect(find.byKey(const Key('sheet')), findsNothing);
      expect(find.text(_zh.s21AvatarDone), findsOneWidget);
    },
  ),
  PageCase(
    'S21-01',
    '牧場資料：頭像、牧場名、成就徽章（長頁）',
    (tester, lang) => showProfile(tester, lang, tall: true),
    check: (tester) {
      expect(find.text(_zh.s21Title), findsOneWidget);
      expect(find.text('晨光河畔牧場'), findsOneWidget);
      expect(find.text('#1234${_zh.gSep}${_zh.level(lv: 4)}'), findsOneWidget);
      expect(find.text(_zh.s21BadgeCount(n: 7, total: 18)), findsOneWidget);
      expect(find.byType(BadgeCell), findsNWidgets(18));
      // 格子裡的進度：還沒解鎖、有計數的；分階段的寫下一階（一萬以上縮寫）
      for (final t in ['1 / 10', '2 / 10', '184 / 1,000', '10 / 12', '4 / 10', '5.8萬 / 10萬']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      // 名稱：分階段的照現在的階段，還沒解鎖的寫第一階
      expect(find.text(_zh.achName('codex', tier: 1)), findsOneWidget);
      expect(find.text(_zh.achName('level', tier: 1)), findsOneWidget);
      // 4 欄：第 5 個在第二列的第一格
      final first = tester.getRect(find.byKey(const Key('ach-firstMilk')));
      final fifth = tester.getRect(find.byKey(const Key('ach-newLife')));
      expect(fifth.left, closeTo(first.left, 0.5));
      expect(fifth.top, greaterThan(first.bottom));
    },
  ),
  PageCase(
    'S21-11',
    '徽章：已解鎖（名稱、條件、解鎖日期）',
    (tester, lang) => showProfile(tester, lang, badge: 'legend'),
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.byKey(const Key('ach-detail-legend')), findsOneWidget);
      expect(find.text(_zh.achCond('legend')), findsOneWidget);
      expect(find.text(_zh.s21BadgeDate(date: _zh.dateYesterday(time: '07:30'))), findsOneWidget);
    },
  ),
  PageCase(
    'S21-12',
    '徽章：還沒解鎖（條件、進度）',
    (tester, lang) => showProfile(tester, lang, badge: 'popularBull'),
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.byKey(const Key('ach-locked')), findsOneWidget);
      expect(find.byKey(const Key('ach-bar')), findsOneWidget);
      expect(find.text(_zh.achCond('popularBull')), findsOneWidget);
    },
  ),
  PageCase(
    'S21-13',
    '徽章：分階段（圖鑑新手、達人、大師）',
    (tester, lang) => showProfile(tester, lang, badge: 'codex'),
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      for (var i = 1; i <= 3; i++) {
        expect(find.byKey(Key('ach-tier-$i')), findsOneWidget);
        expect(find.text(_zh.achCond('codex', tier: i)), findsOneWidget);
      }
      expect(find.text(_zh.dateMd(m: 9, d: 28, time: '09:30')), findsOneWidget);
      expect(find.text('10 / 12'), findsWidgets);
      expect(find.text('10 / 24'), findsOneWidget);
    },
  ),
];
