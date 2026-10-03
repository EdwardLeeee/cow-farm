// S18 借種市場（設計稿 boards/S18-借種市場）的畫面狀態。假資料照 design/m2/src/js/fixtures.js 的 STUD、STUD_LOG、STUD_INCOME：
// 市場 6 頭（電腦牧場的名字用詞庫編號組：麥浪溪谷牧園 = [9, 9, 2]、露珠坡地小屋 = [11, 6, 8]、白雲竹林農莊 = [2, 7, 1]），
// 我的公牛：娟珊 #14 可以上架（借種費 560）、安格斯 #5 上架中（870）；借種收入累計 1,160。
// 選巧克力牛（1,820）× 荷斯坦 #3：荷斯坦 37.5%、巧克力牛 25%、娟珊 18.75%、還沒發現的亮黑 12.5%、草莓牛 6.25%。
import 'dart:async';

import 'package:cowfarm/api/breeds.dart';
import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/l10n/format.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/breed/breed_page.dart';
import 'package:cowfarm/ui/breed/stud_log_page.dart';
import 'package:cowfarm/ui/breed/stud_tab.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:cowfarm/ui/kit/note_line.dart';
import 'package:cowfarm/ui/kit/page_head.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
import 'page_case.dart';
import 's03_cases.dart';
import 's08_cases.dart';

/// 設計稿的「現在」：2026-10-02 12:00（手機時區）。借種紀錄的日期照這個算（今天、昨天、9 月 29 日）。
final designNow = DateTime(2026, 10, 2, 12);
double get _realNow => designNow.millisecondsSinceEpoch / 1000;

Map<String, dynamic> _bot(List<int> words) => {
  'player_id': null,
  'name': null,
  'name_words': words,
  'is_bot': true,
  'level': null,
};

/// 市場的一頭公牛（協定 4.2）。借種費照 D26（體重 × 每公斤價格）。
Map<String, dynamic> _listing(
  int id,
  String breed,
  int price, {
  required Map<String, dynamic> owner,
  double kg = 275,
  bool atMax = true,
  int? cowId,
}) {
  final info = breedInfo(breed)!;
  return {
    'id': id,
    'breed': breed,
    'type': info.type.wire,
    'tier': info.tier,
    'owner': owner,
    'is_mine': false,
    'cow_id': cowId,
    'listed_at': t0 - 3600,
    'fee': {
      'price': price,
      'per_kg': const [1.1, 2.75, 6.6, 16.5][info.tier],
      'kg': kg,
      'at_max': atMax,
    },
  };
}

/// 設計稿的借種市場（fixtures.js 的 STUD），便宜的不一定在前（照設計稿的順序）。
List<Map<String, dynamic>> designStud() => [
  _listing(41, 'holstein', 300, owner: _bot([9, 9, 2])),
  _listing(42, 'yellow', 540, owner: _bot([11, 6, 8]), kg: 495),
  _listing(43, 'chocolate', 1820, owner: ranchJson(id: 5821, name: '楓葉花田乳坊', level: 6), cowId: 21),
  _listing(
    44,
    'highland',
    1050,
    owner: ranchJson(id: 3310, name: '星河松林牧舍', level: 5),
    kg: 380,
    atMax: false,
    cowId: 22,
  ),
  _listing(45, 'wagyu', 2420, owner: ranchJson(id: 907, name: '暖陽原野農場', level: 7), kg: 880, cowId: 23),
  _listing(46, 'angus', 970, owner: _bot([2, 7, 1]), kg: 880),
];

/// 自己上架的安格斯 #5（870 幣，還會漲）。
Map<String, dynamic> _mine() => {
  'id': 7,
  'breed': 'angus',
  'type': 'beef',
  'tier': 0,
  'owner': ranchJson(id: 31, name: '晨光河畔牧場', level: 4),
  'is_mine': true,
  'cow_id': 5,
  'listed_at': t0 - 600,
  'fee': {'price': 870, 'per_kg': 1.1, 'kg': 790, 'at_max': false},
};

/// 設計稿的牧場加上借種：娟珊 #14 可以上架（借種費 560）、安格斯 #5 上架中；現實時間是 [designNow]。
Map<String, dynamic> studState({double coins = 12480, List<Map<String, dynamic>>? cows, int penSlots = 12}) {
  final herd =
      cows ??
      [
        for (final c in designCows())
          if (c['id'] == 14)
            {
              ...c,
              'stud_fee': {'price': 560, 'per_kg': 2.75, 'kg': 205, 'at_max': false},
            }
          else
            c,
      ];
  return {
    ...breedState(cows: herd, penSlots: penSlots),
    'coins': coins,
    'real_time': _realNow,
    'stud': {
      'listings': [if (herd.any((c) => c['id'] == 5 && c['listed'] != null)) _mine()],
      'income': 1160,
    },
  };
}

/// 巧克力牛 × 荷斯坦 #3 的機率（s08.js 的 STUD_OUTCOME）。[price] 是這一刻的借種費。
Map<String, dynamic> designStudPreviewJson({required int price, List<Map<String, dynamic>> blockers = const []}) {
  List<Map<String, dynamic>> odds(String breed, double p) {
    final info = breedInfo(breed)!;
    return [
      for (final bull in [true, false])
        {'breed': breed, 'type': info.type.wire, 'traits': info.traits, 'tier': info.tier, 'bull': bull, 'p': p / 2},
    ];
  }

  return {
    'fee': {'price': price, 'per_kg': 6.6, 'kg': 275, 'at_max': true},
    'tier_probs': [0.375, 0.3125, 0.25, 0.0625],
    'type_probs': {'dairy': 1.0},
    'bull_prob': 0.5,
    'can_borrow': blockers.isEmpty,
    'blockers': blockers,
    'distribution': [
      ...odds('holstein', 0.375),
      ...odds('chocolate', 0.25),
      ...odds('jersey', 0.1875),
      ...odds('glossBlack', 0.125),
      ...odds('strawberry', 0.0625),
    ],
  };
}

/// 借到的小牛：巧克力牛 #16（稀有、母），長大還要 3 小時 58 分（稀有 4 小時，剛出生 2 分鐘）。
Map<String, dynamic> studCalf() => {
  ...designCow(16, 'chocolate', stage: 'calf'),
  'born_at': t0 - 120,
  'age_h': 2 / 60,
  'adult_at': t0 + (3 * 60 + 58) * 60,
  'origin': 'stud',
};

/// 借到以後：付了 1,820 幣，荷斯坦 #3 配過種了，多了小牛 #16。[penSlots] 是牛舍格數。
Map<String, dynamic> borrowedState({int penSlots = 12}) {
  final base = studState();
  return {
    ...studState(
      coins: 12480 - 1820,
      penSlots: penSlots,
      cows: [
        for (final c in base['cows'] as List)
          if ((c as Map)['id'] == 3) {...c.cast<String, dynamic>(), 'bred': true, 'can_breed': false} else c,
        studCalf(),
      ].cast<Map<String, dynamic>>(),
    ),
  };
}

/// 借種紀錄的一筆（協定 4.6）。[at] 是手機時區的時間。
Map<String, dynamic> _log(
  bool out,
  DateTime at,
  int price,
  String bull, {
  int? bullId,
  Map<String, dynamic>? ranch,
  String? calf,
  int? calfId,
}) => {
  'kind': out ? 'out' : 'in',
  't': t0 - (designNow.difference(at).inSeconds),
  'price': price,
  'bull': {'id': bullId, 'breed': bull},
  'calf': calf == null ? null : {'id': calfId, 'breed': calf},
  'ranch': ranch,
};

/// 設計稿的借種紀錄（fixtures.js 的 STUD_LOG）。
Map<String, dynamic> designStudLog() => {
  'keep_days': 30,
  'income_total': 1160,
  'entries': [
    _log(true, DateTime(2026, 10, 2, 9, 12), 870, 'angus', bullId: 5, ranch: ranchJson(id: 3310, name: '星河松林牧舍')),
    _log(
      false,
      DateTime(2026, 10, 1, 21, 40),
      1820,
      'chocolate',
      ranch: ranchJson(id: 5821, name: '楓葉花田乳坊'),
      calf: 'chocolate',
      calfId: 14,
    ),
    _log(true, DateTime(2026, 9, 29, 13, 5), 290, 'holstein', bullId: 8, ranch: ranchJson(id: 907, name: '暖陽原野農場')),
    _log(
      false,
      DateTime(2026, 9, 28, 20, 18),
      300,
      'holstein',
      ranch: {
        ...ranchJson(words: [9, 9, 2]),
        'player_id': 77,
      },
      calf: 'holstein',
      calfId: 10,
    ),
  ],
};

/// 對方的牧場刪除了（S18-14）：借出、借入各一列。
Map<String, dynamic> deletedRanchLog() => {
  'keep_days': 30,
  'income_total': 1160,
  'entries': [
    _log(true, DateTime(2026, 9, 27, 18, 30), 640, 'jersey', bullId: 9),
    _log(false, DateTime(2026, 9, 26, 7, 45), 1210, 'charolais', calf: 'charolais', calfId: 7),
  ],
};

/// 借種的假伺服器：市場、機率可以一直等或失敗；借種可以回錯誤（被借走、借種費變了）；借到以後換成 [after] 的 state。
class StudApi extends FakeGameApi {
  StudApi({Map<String, dynamic>? state}) : super(state: state ?? studState(), market: ranchMarket()) {
    studListings = designStud();
    studLogJson = designStudLog();
  }

  bool marketPending = false;
  bool marketFail = false;

  /// 設了就讓借種市場等到 complete 才回（測試下拉重新整理，G-09）。
  Completer<void>? studGate;
  bool previewPending = false;
  List<Map<String, dynamic>> blockers = [];

  /// 借種的錯誤（status、code、detail）。
  ApiException? borrowError;
  Map<String, dynamic>? after;

  @override
  Future<StudMarket> stud() async {
    calls.add('stud');
    if (marketPending) return Completer<StudMarket>().future;
    await studGate?.future;
    if (marketFail) throw const ApiException(500, 'internal', 'boom');
    return StudMarket.fromJson({
      'listings': [...studListings, _mine()],
      'mine': [_mine()],
    });
  }

  @override
  Future<BreedPreview> studPreview(Object listingId, Object dam) async {
    calls.add('stud-preview:$listingId:$dam');
    if (previewPending) return Completer<BreedPreview>().future;
    final price = studListings.firstWhere((l) => '${l['id']}' == '$listingId')['fee']['price'] as int;
    return BreedPreview.fromJson(designStudPreviewJson(price: price, blockers: blockers));
  }

  @override
  Future<BreedResult> studBorrow(Object listingId, Object dam, {required int price}) async {
    calls.add('stud-borrow:$listingId:$dam:$price');
    final err = borrowError;
    if (err != null) {
      borrowError = null; // 只錯一次（S18-12 按「用新價格借」重送就成功）
      throw err;
    }
    if (after != null) stateJson = after!;
    return BreedResult.fromJson({'calf': studCalf()});
  }
}

/// 借種分頁的捲動。
Finder get studScrollable =>
    find.descendant(of: find.byKey(const Key('stud')), matching: find.byType(Scrollable)).first;

/// 打開借種分頁，等市場載好；[listing] 是先選的那一頭，[dam] 是自己的母牛（選了就等機率回來）。
Future<GameModel> showStud(
  WidgetTester tester,
  AppLang lang, {
  StudApi? api,
  String? listing,
  String? dam,
  bool connected = true,
}) async {
  final m = await ranchModel(api: api ?? StudApi(), connected: connected);
  m
    ..selectTab(AppTab.breed)
    ..selectBreed(stud: true);
  await pumpAppIn(tester, m, lang, prefs: swipeHintSeen);
  await tester.pump();
  await tester.pump();
  if (listing != null) await tapStud(tester, find.byKey(Key('stud-listing-$listing')));
  if (dam != null) {
    await tapStud(tester, find.byKey(Key('stud-dam-$dam')), reveal: find.byKey(const Key('stud-dam-row')));
    await tester.pump();
  }
  return m;
}

/// 捲到 [target] 整個看得到（不被分頁列蓋住）再點。scrollUntilVisible、ensureVisible 會連外層、選牛列一起捲，
/// 截圖就跟設計稿不一樣：選牛卡要給 [reveal]（那一列），讓那一列整個看得到就好（列的外層只有直的那一個）。
Future<void> tapStud(WidgetTester tester, Finder target, {Finder? reveal}) async {
  final show = reveal ?? target;
  await tester.scrollUntilVisible(show, 200, scrollable: studScrollable);
  await tester.ensureVisible(show);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
}

/// 把借種分頁捲到 [target] 的上緣在內容區上緣往下 [gap]（設計稿的 scrollTo）。
Future<void> scrollStudTo(WidgetTester tester, Finder target, {double gap = 6}) async {
  await tester.scrollUntilVisible(target, 200, scrollable: studScrollable);
  final position = tester.state<ScrollableState>(studScrollable).position;
  final box = tester.renderObject<RenderBox>(target);
  final top = RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset - gap;
  position.jumpTo(top.clamp(position.minScrollExtent, position.maxScrollExtent));
  await tester.pump();
}

/// 按借種鈕，等結果（對話框或成功）。
Future<void> tapBorrow(WidgetTester tester) async {
  await tapStud(tester, find.byKey(const Key('stud-borrow')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

final _zh = Strings.forLang(AppLang.zhHant);

AppButton _go(WidgetTester tester) => tester.widget<AppButton>(find.byKey(const Key('stud-borrow')));

/// 局部狀態（S18-13）：三頭名字最長的公牛。
List<Map<String, dynamic>> _longNames() => [
  {...designStud()[2], 'owner': ranchJson(id: 5821, name: '晨光河畔牧場小屋')},
  {...designStud()[4], 'owner': ranchJson(id: 907, name: 'MorningRiverFarm')},
  {
    ...designStud()[0],
    'owner': {'player_id': null, 'name': '晨光河畔牧場小屋', 'name_words': null, 'is_bot': true, 'level': null},
  },
];

final s18Cases = <PageCase>[
  PageCase(
    'S18-01',
    '我的公牛：可以上架（價位選項、「上架」）；上方借種收入累計',
    (tester, lang) => showStud(tester, lang),
    check: (tester) {
      expect(find.text(_zh.studIncome(v: '1,160'), findRichText: true), findsOneWidget);
      expect(find.byKey(const Key('list-14')), findsOneWidget);
      expect(find.byKey(const Key('unlist-5')), findsOneWidget);
      expect(find.text(_zh.s18FeeLabel(price: '560'), findRichText: true), findsOneWidget);
      expect(find.text(_zh.costCoins(v: '870'), findRichText: true), findsOneWidget);
      expect(find.text(_zh.s18FeeNote), findsOneWidget);
      // 市場不放自己上架的（缺口清單 3-4）
      expect(find.byKey(const Key('stud-listing-7')), findsNothing);
      expect(find.text(_zh.ranchNameFromWords([9, 9, 2])), findsOneWidget);
    },
  ),
  PageCase(
    'S18-02',
    '我的公牛：沒有能上架的',
    (tester, lang) => showStud(
      tester,
      lang,
      api: StudApi(
        state: studState(
          cows: [
            for (final c in designCows())
              if (c['id'] != 14 && c['id'] != 5) c,
          ],
        ),
      ),
    ),
    crop: find.byKey(const Key('my-bulls')),
    check: (tester) {
      expect(find.text(_zh.s18NoBullTitle), findsOneWidget);
      expect(find.text(_zh.s18NoBullHint), findsOneWidget);
      expect(find.text(_zh.s18LogTitle), findsOneWidget);
    },
  ),
  PageCase(
    'S18-03',
    '我的公牛：上架中＋「下架」',
    (tester, lang) => showStud(
      tester,
      lang,
      api: StudApi(
        state: studState(
          cows: [
            for (final c in designCows())
              if (c['id'] != 14) c,
          ],
        ),
      ),
    ),
    crop: find.byKey(const Key('my-bulls')),
    check: (tester) {
      expect(find.byKey(const Key('list-14')), findsNothing);
      expect(tester.widget<AppButton>(find.byKey(const Key('unlist-5'))).onPressed, isNotNull);
    },
  ),
  PageCase(
    'S18-04',
    '市場列表：每頭公牛的正面小圖、用途、稀有度、價格、主人',
    (tester, lang) async {
      await showStud(tester, lang);
      await scrollStudTo(tester, find.byKey(const Key('market-head')));
    },
    check: (tester) {
      expect(find.byType(StudRow), findsNWidgets(6));
      expect(find.text(_zh.s18Growing), findsOneWidget, reason: '高地牛還在長（at_max false）');
      expect(find.text('#5821'), findsOneWidget);
    },
  ),
  PageCase(
    'S18-05',
    '市場：載入中／載入失敗／沒有別人上架',
    (tester, lang) => pumpSheet(tester, lang, [
      MarketEmpty(kind: MarketEmptyKind.loading, onReload: () {}),
      MarketEmpty(kind: MarketEmptyKind.failed, onReload: () {}),
      MarketEmpty(kind: MarketEmptyKind.empty, onReload: () {}),
    ]),
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.text(_zh.gLoading), findsOneWidget);
      expect(find.byKey(const Key('market-reload')), findsOneWidget);
      expect(find.text(_zh.studEmpty), findsOneWidget);
    },
  ),
  PageCase(
    'S18-06',
    '選了公牛和母牛：機率卡、費用、「借種（300 幣）」',
    (tester, lang) async {
      await showStud(tester, lang, listing: '43', dam: '3');
      await scrollStudTo(tester, find.byKey(const Key('outcome')));
    },
    check: (tester) {
      expect(find.text(_zh.s18FeeLine(price: '1,820')), findsOneWidget);
      expect(find.text('37.5%'), findsOneWidget);
      expect(find.text('18.75%'), findsNothing, reason: '10% 以上寫一位小數');
      expect(find.text('18.8%'), findsOneWidget);
      // 有傳說（8 小時）：照規則寫 1–8 小時（缺口清單 3-3；ceo 2026-10-02）
      expect(find.text(_zh.s08GrowRange(v: _zh.s08HoursRange(a: 1, b: 8)), findRichText: true), findsOneWidget);
      expect(_go(tester).label, _zh.borrow(price: '1,820'));
      expect(_go(tester).onPressed, isNotNull);
    },
  ),
  PageCase(
    'S18-07',
    '還沒選公牛／還沒選母牛',
    (tester, lang) async {
      final s = Strings.forLang(lang);
      await pumpSheet(tester, lang, model: await ranchModel(api: StudApi()), [
        OutcomeCard(
          state: OutcomeState.none,
          fee: s.s18FeeLine(price: fmt(1820)),
          noneText: s.pickListing,
        ),
        AppButton(
          s.borrow(price: fmt(1820)),
          kind: ButtonKind.pink,
          block: true,
          icon: 'heart',
        ),
      ]);
    },
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.text(_zh.pickListing), findsOneWidget);
    },
  ),
  PageCase(
    'S18-08',
    '金幣不夠／牛舍滿了',
    (tester, lang) async {
      final m = await ranchModel(api: StudApi(state: studState(coins: 300, penSlots: 10)));
      final s = Strings.forLang(lang);
      await pumpSheet(tester, lang, model: m, [
        for (final n in studNotes(s, m, preview: null, dam: null, price: 1820))
          NoteLine(icon: 'warn', text: n, kind: NoteKind.warn),
        AppButton(
          s.borrow(price: fmt(1820)),
          kind: ButtonKind.pink,
          block: true,
          icon: 'heart',
        ),
      ]);
    },
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.text(_zh.notEnoughCoins(n: '1,520')), findsOneWidget);
      expect(find.text(_zh.s08PenFull), findsOneWidget);
    },
  ),
  PageCase(
    'S18-09',
    '借種成功（小牛出生動畫的最後一格＋倒數卡）',
    (tester, lang) async {
      await showStud(tester, lang, api: StudApi()..after = borrowedState(), listing: '43', dam: '3');
      await tapBorrow(tester);
    },
    check: (tester) {
      expect(find.text(_zh.borrowed(price: '1,820')), findsOneWidget);
      expect(find.text(_zh.gNewCalf(cow: _zh.cowName('chocolate', 16))), findsOneWidget);
      expect(find.text(_zh.growUp(v: _zh.duration(h: 3, m: 58)), findRichText: true), findsOneWidget);
      expect(_go(tester).label, _zh.s18BorrowedBtn);
      expect(_go(tester).onPressed, isNull);
      expect(find.text('10,660'), findsOneWidget, reason: '頂列的金幣扣掉借種費');
    },
  ),
  PageCase(
    'S18-10',
    '借種失敗：公牛已經被別人借走',
    (tester, lang) async {
      final api = StudApi()..borrowError = const ApiException(404, 'listing_not_found', 'gone');
      await showStud(tester, lang, api: api, listing: '43', dam: '3');
      await tapBorrow(tester);
    },
    crop: find.byKey(const Key('dialog')),
    check: (tester) {
      expect(find.text(_zh.s18GoneTitle), findsOneWidget);
      expect(find.byKey(const Key('gone-reload')), findsOneWidget);
    },
  ),
  PageCase(
    'S18-11',
    '借種紀錄：借出與借入的清單',
    (tester, lang) async {
      final m = await ranchModel(api: StudApi());
      m
        ..selectTab(AppTab.breed)
        ..selectBreed(stud: true)
        ..openStudLog();
      await pumpAppIn(tester, m, lang, prefs: swipeHintSeen);
      await tester.pump();
      await tester.pump();
    },
    check: (tester) {
      expect(find.text(_zh.s18LogIncome(v: '1,160')), findsOneWidget);
      expect(find.byType(StudLogRow), findsNWidgets(4));
      // 牛名不加「公牛」（ceo 2026-10-02）
      expect(find.text(_zh.s18LentTo(cow: _zh.cowName('angus', 5), ranch: '星河松林牧舍 #3310')), findsOneWidget);
      expect(
        find.text(
          _zh.s18BorrowedFrom(cow: _zh.breedName('holstein'), ranch: _zh.ranchText(RanchRef.fromJson(_bot([9, 9, 2])))),
        ),
        findsOneWidget,
      );
      expect(find.text(_zh.s18LogKeep(n: 30)), findsOneWidget);
    },
  ),
  PageCase(
    'S18-12',
    '借種費變了：公牛長大了，價格跟剛剛看的不一樣；「用新價格借」',
    (tester, lang) async {
      final api = StudApi()
        ..borrowError = const ApiException(409, 'price_changed', 'changed', {'price': 1090, 'expected': 1050});
      await showStud(tester, lang, api: api, listing: '44', dam: '3');
      await tapBorrow(tester);
    },
    crop: find.byKey(const Key('dialog')),
    check: (tester) {
      expect(find.text(_zh.s18FeeChangedTitle), findsOneWidget);
      expect(
        tester.widget<AppButton>(find.byKey(const Key('fee-changed-borrow'))).label,
        _zh.s18BorrowNew(price: '1,090'),
      );
    },
  ),
  PageCase(
    'S18-13',
    '名字最長：8 個中文字、16 個英文字母（量測用）',
    (tester, lang) async {
      await pumpSheet(tester, lang, model: await ranchModel(api: StudApi()), [
        Column(
          key: const Key('long-names'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, l) in _longNames().indexed) ...[
              if (i > 0) const SizedBox(height: 10),
              StudRow(listing: StudListing.fromJson(l), on: false, onTap: () {}),
            ],
          ],
        ),
      ]);
    },
    crop: find.byKey(const Key('long-names')),
    check: (tester) {
      expect(find.text('晨光河畔牧場小屋'), findsNWidgets(2));
      expect(find.text('MorningRiverFarm'), findsOneWidget);
      expect(find.text('#0907'), findsOneWidget);
    },
  ),
  PageCase(
    'S18-14',
    '借種紀錄：對方的牧場刪除了，名字顯示「已刪除的牧場」',
    (tester, lang) async {
      final m = await ranchModel(api: StudApi()..studLogJson = deletedRanchLog());
      final log = StudLog.fromJson(deletedRanchLog());
      await pumpSheet(tester, lang, model: m, [
        Column(
          key: const Key('deleted-log'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, e) in log.entries.indexed) ...[if (i > 0) const SizedBox(height: 10), StudLogRow(entry: e)],
          ],
        ),
      ]);
    },
    crop: find.byKey(const Key('deleted-log')),
    check: (tester) {
      expect(find.text(_zh.s18LentTo(cow: _zh.cowName('jersey', 9), ranch: _zh.s18DeletedRanch)), findsOneWidget);
      expect(find.textContaining(_zh.s18CalfBorn(cow: _zh.cowName('charolais', 7))), findsOneWidget);
    },
  ),
  PageCase(
    'S18-15',
    '借種紀錄是空的：全部、借出、借入',
    (tester, lang) async {
      final s = Strings.forLang(lang);
      await pumpSheet(tester, lang, [
        PageHead(
          title: s.s18LogTitle,
          sub: s.s18LogIncome(v: '0'),
          onBack: () {},
        ),
        for (final f in [0, 1, 2]) ...[
          FilterChips(labels: [s.gAll, s.s18Out, s.s18In], selected: f, onSelect: (_) {}),
          LogEmptyCard(key: Key('log-empty-$f'), filter: f),
        ],
        Text(s.s18LogKeep(n: 30), textAlign: TextAlign.center, style: KitText.hint()),
      ]);
    },
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.text(_zh.s18LogEmpty), findsOneWidget);
      expect(find.text(_zh.s18LogEmptyOut), findsOneWidget);
      expect(find.text(_zh.s18LogEmptyIn), findsOneWidget);
    },
  ),
];
