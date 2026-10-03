// S12 排行榜的頁面狀態（設計稿 s09.js 的 rankPage；假資料是 fixtures.js 的 RANK）。
// 本週收入的「每週一 00:00 重新計算」換成手機的時區：設計稿的假資料當作繁中在台灣（+8）、泰文在泰國（+7）、
// 英文在美國西岸夏令時間（−7），這裡照樣設（debugRankUtcOffset），下次重算是 2026-10-04（日）16:00 UTC。
import 'dart:async';

import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/records/rank_page.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
import 'page_case.dart';
import 's03_cases.dart';

/// 設計稿的牧場名（fixtures.js 的 NAMES）。
const designRankNames = [
  "星河花田乳坊",
  "月牙湖邊莊園",
  "暖陽原野農場",
  "楓葉花田乳坊",
  "山嵐松林牧舍",
  "彩虹溪谷牧場",
  "麥浪溪谷牧園",
  "青草坡地家園",
  "白雲竹林農莊",
  "露珠石橋田園",
  "微風湖邊小屋",
  "晨光森林牛舍",
];

/// 設計稿的三種排行（rank 1–12）：#編號（player_id）、等級、分數、是不是電腦。
const _networth = [
  (id: 1021, level: 12, score: 412000, bot: false),
  (id: 1734, level: 12, score: 337840, bot: false),
  (id: 2447, level: 11, score: 277029, bot: false),
  (id: 3160, level: 11, score: 227164, bot: false),
  (id: 3873, level: 10, score: 186274, bot: false),
  (id: 4586, level: 10, score: 152745, bot: false),
  (id: 5299, level: 9, score: 125251, bot: true),
  (id: 6012, level: 9, score: 102706, bot: false),
  (id: 6725, level: 8, score: 84219, bot: true),
  (id: 7438, level: 8, score: 69059, bot: false),
  (id: 8151, level: 7, score: 56629, bot: false),
  (id: 8864, level: 7, score: 46435, bot: false),
];
const _collection = [
  (id: 2031, level: 11, score: 24, bot: false),
  (id: 2548, level: 11, score: 24, bot: false),
  (id: 3065, level: 11, score: 23, bot: false),
  (id: 3582, level: 10, score: 22, bot: false),
  (id: 4099, level: 10, score: 21, bot: false),
  (id: 4616, level: 10, score: 20, bot: false),
  (id: 5133, level: 9, score: 19, bot: false),
  (id: 5650, level: 9, score: 18, bot: false),
  (id: 6167, level: 9, score: 17, bot: false),
  (id: 6684, level: 8, score: 16, bot: true),
  (id: 7201, level: 8, score: 15, bot: false),
  (id: 7718, level: 8, score: 15, bot: false),
];
const _weekly = [
  (id: 3041, level: 10, score: 96000, bot: false),
  (id: 3352, level: 10, score: 76800, bot: false),
  (id: 3663, level: 10, score: 61440, bot: false),
  (id: 3974, level: 9, score: 49152, bot: true),
  (id: 4285, level: 9, score: 39322, bot: false),
  (id: 4596, level: 9, score: 31457, bot: false),
  (id: 4907, level: 8, score: 25166, bot: false),
  (id: 5218, level: 8, score: 20133, bot: false),
  (id: 5529, level: 8, score: 16106, bot: false),
  (id: 5840, level: 7, score: 12885, bot: false),
  (id: 6151, level: 7, score: 10308, bot: false),
  (id: 6462, level: 7, score: 8246, bot: false),
];

/// 自己（設計稿的 RANCH：晨光河畔牧場 #1234、Lv 4）。
RanchRef designMeRanch({int level = 4}) => RanchRef(playerId: 1234, name: '晨光河畔牧場', level: level);

/// 下次重算：2026-10-04（日）16:00 UTC ＝ 台灣週一 00:00。
const designWeeklyReset = 1791129600.0;

RankEntry _entry(int rank, String name, ({int id, int level, int score, bool bot}) r) => RankEntry(
  rank: rank,
  score: r.score.toDouble(),
  ranch: RanchRef(playerId: r.id, name: name, isBot: r.bot, level: r.level),
);

/// 設計稿的一種排行。[me] 在前 12 名裡就換掉那一列；[names] 換掉牧場名（S12-07 的最長名字）。
Leaderboard designBoard(RankKind kind, {RankEntry? me, bool noMe = false, List<String>? names, List<RankEntry>? rows}) {
  final data = switch (kind) {
    RankKind.networth => _networth,
    RankKind.collection => _collection,
    RankKind.weekly => _weekly,
  };
  final defaultMe = switch (kind) {
    RankKind.networth => (37, 58920),
    RankKind.collection => (21, 10),
    RankKind.weekly => (44, 8340),
  };
  final mine = noMe
      ? null
      : me ?? RankEntry(rank: defaultMe.$1, score: defaultMe.$2.toDouble(), ranch: designMeRanch(), isMe: true);
  final list = rows ?? [for (var i = 0; i < data.length; i++) _entry(i + 1, (names ?? designRankNames)[i], data[i])];
  return Leaderboard(
    entries: [for (final e in list) mine != null && e.rank == mine.rank ? mine : e],
    me: mine,
    nextResetAtReal: kind == RankKind.weekly ? designWeeklyReset : null,
  );
}

/// 排行榜的 API：照設計稿回；[pending] 一直讀不回來（S12-05），[fail] 讀取失敗（S12-06）。
class RankApi extends FakeGameApi {
  RankApi({this.boards = const {}, this.pending = false, this.fail = false})
    : super(state: ranchState(), market: ranchMarket());

  final Map<RankKind, Leaderboard> boards;
  final bool pending;
  bool fail;

  @override
  Future<Leaderboard> leaderboard(RankKind kind) async {
    calls.add('rank:${kind.wire}');
    if (pending) return Completer<Leaderboard>().future;
    if (fail) throw const ApiException(500, 'internal', 'boom');
    return boards[kind] ?? designBoard(kind);
  }
}

/// 設計稿每種語言當作的時區。
Duration designUtcOffset(AppLang lang) => switch (lang) {
  AppLang.zhHant => const Duration(hours: 8),
  AppLang.th => const Duration(hours: 7),
  AppLang.en => const Duration(hours: -7),
};

/// 紀錄分頁的排行榜（S12），看 [kind] 這一種。
Future<GameModel> showRank(WidgetTester tester, AppLang lang, {RankKind kind = RankKind.networth, RankApi? api}) async {
  debugRankUtcOffset = designUtcOffset(lang);
  addTearDown(() => debugRankUtcOffset = null);
  final m = await ranchModel(api: api ?? RankApi());
  m.selectTab(AppTab.records);
  m.selectRecords(rank: true);
  m.selectRankKind(kind);
  await pumpAppIn(tester, m, lang);
  await tester.pump(); // 畫完第一格才去讀
  await tester.pump();
  return m;
}

final _zh = Strings.forLang(AppLang.zhHant);

Finder _rankRow(int rank) => find.byKey(Key('rank-row-$rank'));

String _myRank(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('my-rank'))).data!;

final s12Cases = [
  PageCase(
    'S12-01',
    '總資產（自己在榜內）',
    (tester, lang) => showRank(
      tester,
      lang,
      api: RankApi(
        boards: {
          RankKind.networth: designBoard(
            RankKind.networth,
            me: RankEntry(rank: 8, score: 58920, ranch: designMeRanch(), isMe: true),
          ),
        },
      ),
    ).then((_) {}),
    check: (tester) {
      for (var r = 1; r <= 12; r++) {
        expect(_rankRow(r), findsOneWidget, reason: '第 $r 名');
      }
      expect(find.text(_zh.s12Me), findsOneWidget, reason: '自己那一列（第 8 名）');
      expect(find.descendant(of: _rankRow(8), matching: find.text('晨光河畔牧場')), findsOneWidget);
      expect(_myRank(tester), _zh.s12RankN(n: 8));
      expect(find.text(_zh.botPrefix), findsNWidgets(2), reason: '第 7、9 名是電腦');
      expect(find.text('#1021'), findsOneWidget);
    },
  ),
  PageCase(
    'S12-02',
    '圖鑑榜',
    (tester, lang) => showRank(tester, lang, kind: RankKind.collection).then((_) {}),
    check: (tester) {
      expect(find.byKey(const Key('done-badge')), findsNWidgets(2), reason: '第 1、2 名發現 24 種');
      expect(_myRank(tester), _zh.s12RankN(n: 21));
      expect(find.text(_zh.s12CollectionHint(n: 24) + _zh.s12PullHint), findsOneWidget);
    },
  ),
  PageCase(
    'S12-03',
    '本週收入',
    (tester, lang) => showRank(tester, lang, kind: RankKind.weekly).then((_) {}),
    check: (tester) {
      expect(find.text(_zh.s12WeeklyHint(w: _zh.weekdayFullName(1), time: '00:00') + _zh.s12PullHint), findsOneWidget);
      expect(_myRank(tester), _zh.s12RankN(n: 44));
    },
  ),
  PageCase(
    'S12-04',
    '自己沒上榜',
    (tester, lang) => showRank(
      tester,
      lang,
      kind: RankKind.weekly,
      api: RankApi(boards: {RankKind.weekly: designBoard(RankKind.weekly, noMe: true)}),
    ).then((_) {}),
    crop: find.byKey(const Key('my-rank-bar')),
    check: (tester) {
      expect(_myRank(tester), _zh.notRanked);
    },
  ),
  PageCase(
    'S12-05',
    '載入中',
    (tester, lang) => showRank(tester, lang, api: RankApi(pending: true)).then((_) {}),
    crop: find.byKey(const Key('rank-card')),
    check: (tester) {
      expect(find.byKey(const Key('rank-loading')), findsOneWidget);
      expect(_myRank(tester), '—');
    },
  ),
  PageCase(
    'S12-06',
    '載入失敗',
    (tester, lang) => showRank(tester, lang, api: RankApi(fail: true)).then((_) {}),
    crop: find.byKey(const Key('rank-card')),
    check: (tester) {
      expect(find.byKey(const Key('rank-failed')), findsOneWidget);
      expect(find.byKey(const Key('rank-retry')), findsOneWidget);
      expect(_myRank(tester), '—');
    },
  ),
  PageCase(
    'S12-07',
    '電腦玩家、名字最長（8 個中文字、16 個英文字母）、數字最大（量測用）',
    (tester, lang) {
      const cjk = '晨光河畔牧場小屋', latin = 'MorningRiverFarm';
      const longNames = [
        cjk,
        latin,
        '麥浪森林牧舍',
        '月牙石橋莊園',
        cjk,
        '楓葉湖邊家園',
        latin,
        '暖陽坡地牧野',
        '白雲谷地小屋',
        '青草松林牧園',
        '微風河畔牛舍',
        '晨光小丘農場',
      ];
      final me = RankEntry(rank: 12, score: 98765432, ranch: designMeRanch(level: 14), isMe: true);
      final rows = [
        for (var i = 0; i < 12; i++)
          RankEntry(
            rank: i + 1,
            score: (999999999 - i * 12345678).toDouble(),
            ranch: RanchRef(playerId: 1021 + i * 713, name: longNames[i], isBot: i % 3 == 1, level: 15 - i ~/ 4),
          ),
      ];
      return showRank(
        tester,
        lang,
        api: RankApi(
          boards: {RankKind.networth: designBoard(RankKind.networth, me: me, rows: rows)},
        ),
      ).then((_) {});
    },
    check: (tester) {
      expect(find.text(_zh.botPrefix), findsNWidgets(4), reason: '第 2、5、8、11 名是電腦');
      expect(find.textContaining('10.0億', findRichText: true), findsOneWidget, reason: '999,999,999 → 10.0億');
      expect(_myRank(tester), _zh.s12RankN(n: 12));
    },
  ),
  PageCase(
    'S12-08',
    '圖鑑榜：發現 24 種的加「完成」',
    (tester, lang) => showRank(
      tester,
      lang,
      kind: RankKind.collection,
      api: RankApi(
        boards: {
          RankKind.collection: designBoard(
            RankKind.collection,
            me: RankEntry(rank: 2, score: 24, ranch: designMeRanch(), isMe: true),
          ),
        },
      ),
    ).then((_) {}),
    check: (tester) {
      expect(
        find.descendant(of: find.byKey(const Key('my-rank-bar')), matching: find.byKey(const Key('done-badge'))),
        findsOneWidget,
      );
      expect(find.descendant(of: _rankRow(2), matching: find.byKey(const Key('done-badge'))), findsOneWidget);
      expect(_myRank(tester), _zh.s12RankN(n: 2));
    },
  ),
];
