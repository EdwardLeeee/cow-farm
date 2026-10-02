// S04 牛的詳細資料、S07 出貨確認、S20 出貨評級結果（設計稿 boards/S04、S07、S20）的畫面狀態。
// 假資料照設計稿 design/m2/src/js/fixtures.js 的牛：#3 荷斯坦、#11 和牛、#5 安格斯公牛、#2 黃牛（耕牛）、
// #15 小牛、#7 娟珊、#8 老公牛；牛肉現價 11.2。出貨確認的收入照 s07.js：體重 × 11.2 × 評級倍率。
import 'dart:async';

import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/l10n/format.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
import 'page_case.dart';
import 's03_cases.dart';

/// 設計稿的一頭牛加上詳細頁要的欄位：年齡（遊戲小時；時鐘倍率 1，就是現實時間）、來源、出貨評級機率。
Map<String, dynamic> _detail(Map<String, dynamic> c, {required double ageH, String? origin, List<double>? probs}) => {
  ...c,
  'age_h': ageH,
  'origin': origin,
  if (probs != null) 'grade_probs': {'A': probs[0], 'B': probs[1], 'C': probs[2]},
};

/// 設計稿 fixtures.js 的牛（S04、S07 用的那幾頭）。[field] 耕牛在第幾塊田、[listed] 公牛上架中、[bred] 配過種。
Map<String, dynamic> detailCow(int id, {int? field, bool listed = false, bool bred = false}) => switch (id) {
  3 => _detail(
    designCow(3, 'holstein', milk: 14, kg: 212, value: 2514),
    ageH: 2 * 24 + 5,
    origin: 'start',
    probs: [0.397, 0.441, 0.162],
  ),
  11 => _detail(
    designCow(11, 'wagyu', kg: 612, value: 10024),
    ageH: 24 + 18,
    origin: 'A',
    probs: [0.418, 0.436, 0.146],
  ),
  5 => _detail(
    designCow(5, 'angus', bull: true, kg: 790, value: 9420, fee: 870, listed: listed ? 7 : null),
    ageH: 2 * 24 + 14,
    origin: 'C',
    probs: [0.448, 0.414, 0.138],
  ),
  // 耕牛不管有沒有下田都給「下田的話」每小時的稻米（協定 2.3）
  2 => _detail(
    {...designCow(2, 'yellow', bull: true, kg: 431, value: 5108, field: field), 'rice_per_h': 11.0},
    ageH: 3 * 24 + 1,
    origin: 'start',
    probs: [0.416, 0.428, 0.156],
  ),
  15 => _detail(
    designCow(15, 'holstein', stage: 'calf'),
    ageH: 18 / 60,
    origin: 'breed',
  ),
  7 => _detail(
    designCow(7, 'jersey', milk: 14, kg: 196, value: 3102, bred: bred),
    ageH: 24 + 20,
    origin: 'B',
    probs: [0.402, 0.437, 0.161],
  ),
  8 => _detail(
    designCow(8, 'holstein', bull: true, stage: 'old', kg: 268, value: 2810, bred: true),
    ageH: 7 * 24 + 3,
    origin: 'C',
    probs: [0.262, 0.469, 0.269],
  ),
  _ => throw ArgumentError.value(id, 'id'),
};

/// 只有這一頭牛的牧場。[freeField] 有沒有空田（S04-13 沒有）；上架中的公牛在 stud.listings 有一筆（編號 7、870 幣）。
Map<String, dynamic> detailState(Map<String, dynamic> cow, {bool freeField = true}) => {
  ...ranchState(cows: [cow]),
  'fields': [
    {'index': 0, 'cow_id': cow['field'] == 0 ? cow['id'] : 9, 'rice': 20.0, 'capacity': 88.0, 'per_hour': 11.0},
    if (freeField)
      {'index': 1, 'cow_id': null, 'rice': 0.0, 'capacity': null, 'per_hour': 0.0}
    else
      {'index': 1, 'cow_id': 12, 'rice': 10.0, 'capacity': 88.0, 'per_hour': 14.3},
  ],
  'stud': {
    'listings': [
      if (cow['listed'] != null)
        {
          'id': cow['listed'],
          'breed': cow['breed'],
          'type': cow['type'],
          'tier': cow['tier'],
          'owner': ranchJson(id: 31, name: '晨光河畔牧場', level: 4),
          'is_mine': true,
          'cow_id': cow['id'],
          'listed_at': t0 - 600,
          'fee': cow['stud_fee'],
        },
    ],
    'income': 0,
  },
};

/// 牛肉 11.2 幣／公斤時，212 公斤的荷斯坦 #3 評到各級的收入（s07.js 的 income）。
const designIncome = {'A': 2968, 'B': 2374, 'C': 1781};

/// 詳細頁的假伺服器：出貨確認的機率可以一直等、可以失敗、可以說現在不能出貨；出貨評到 [grade]，之後換成 [after] 的 state。
class DetailApi extends FakeGameApi {
  DetailApi({required Map<String, dynamic> state}) : super(state: state, market: ranchMarket());

  bool pending = false;
  bool fail = false;
  List<Map<String, dynamic>> blockers = [];
  String grade = 'A';
  Map<String, dynamic>? after;

  @override
  Future<ShipPreview> shipPreview(Object cowId) async {
    calls.add('ship-preview:$cowId');
    if (pending) return Completer<ShipPreview>().future;
    if (fail) throw const ApiException(500, 'internal', 'boom');
    return ShipPreview.fromJson({
      'cow_id': cowId,
      'weight_kg': 212,
      'tier': 0,
      'grade_probs': {'A': 0.397, 'B': 0.441, 'C': 0.162},
      'grade_mult': {'A': 1.25, 'B': 1.0, 'C': 0.75},
      'value_by_grade': designIncome,
      'expected_value': 2514,
      'can_ship': blockers.isEmpty,
      'blockers': blockers,
    });
  }

  @override
  Future<ShipResult> ship(Object cowId) async {
    calls.add('ship:$cowId');
    if (after != null) stateJson = after!;
    return ShipResult.fromJson({
      'cow_id': cowId,
      'grade': grade,
      'grade_probs': {'A': 0.397, 'B': 0.441, 'C': 0.162},
      'beef': {'qty': 212, 'tier': 0, 'grade': grade, 'value_estimate': designIncome[grade]},
    });
  }
}

/// 打開那頭牛的詳細資料（S04）。回傳模型和推播（斷線用）。
Future<(GameModel, FakePush)> showCow(
  WidgetTester tester,
  AppLang lang,
  Map<String, dynamic> cow, {
  DetailApi? api,
  bool freeField = true,
  bool connected = true,
}) async {
  final a = api ?? DetailApi(state: detailState(cow, freeField: freeField));
  final (m, _, push) = await loadedModel(api: a, connected: connected);
  m.openCow('${cow['id']}');
  await pumpAppIn(tester, m, lang, prefs: swipeHintSeen);
  await tester.pump();
  return (m, push);
}

/// 按「出貨」打開出貨確認（S07），等機率回來。
Future<void> openShip(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('detail-ship')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// 出貨確認按「確定出貨」，等結果頁（S20）淡入。
Future<void> confirmShip(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('ship-confirm')));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

final _zh = Strings.forLang(AppLang.zhHant);

AppButton _btn(WidgetTester tester, String key) => tester.widget<AppButton>(find.byKey(Key(key)));

/// 那一格的值（.kv .v）：格子裡第二行的字。
String kvValue(WidgetTester tester, String label) {
  final cell = find.ancestor(of: find.text(label), matching: find.byType(Column)).first;
  final texts = tester.widgetList<RichText>(find.descendant(of: cell, matching: find.byType(RichText)));
  return texts.map((t) => t.text.toPlainText()).last;
}

final s04Cases = <PageCase>[
  PageCase(
    'S04-01',
    '成年母乳牛',
    (tester, lang) => showCow(tester, lang, detailCow(3)),
    check: (tester) {
      expect(find.text(_zh.cowName('holstein', 3)), findsOneWidget);
      expect(find.text(_zh.origin(v: _zh.s04OriginStart)), findsOneWidget);
      expect(kvValue(tester, _zh.s04Age), _zh.duration(d: 2, h: 5));
      expect(kvValue(tester, _zh.gMilk), '14 ${_zh.gPerHourMilk}');
      expect(kvValue(tester, _zh.s04Weight), '212 ${_zh.gKg}');
      expect(kvValue(tester, _zh.s04Value), '${_zh.s04About(v: '2,514')} ${_zh.gCoin}');
      expect(find.text('39.7%'), findsOneWidget);
      expect(_btn(tester, 'detail-breed').onPressed, isNotNull);
      expect(_btn(tester, 'detail-ship').onPressed, isNotNull);
      expect(find.byKey(const Key('detail-list')), findsNothing);
    },
  ),
  PageCase(
    'S04-02',
    '肉牛（估值最高）',
    (tester, lang) => showCow(tester, lang, detailCow(11)),
    check: (tester) {
      expect(kvValue(tester, _zh.probType), _zh.s04UseBeef);
      expect(kvValue(tester, _zh.s04Value), '${_zh.s04About(v: '10,024')} ${_zh.gCoin}');
      expect(find.text(_zh.origin(v: _zh.s04OriginShop(g: 'A'))), findsOneWidget);
    },
  ),
  PageCase(
    'S04-03',
    '公牛：可以上架借種',
    (tester, lang) => showCow(tester, lang, detailCow(5)),
    check: (tester) {
      expect(_btn(tester, 'detail-list').onPressed, isNotNull);
      expect(_btn(tester, 'detail-breed').onPressed, isNotNull);
    },
  ),
  PageCase(
    'S04-04',
    '上架借種：借種費由系統算',
    (tester, lang) async {
      await showCow(tester, lang, detailCow(5));
      await tester.tap(find.byKey(const Key('detail-list')));
      await tester.pump();
    },
    check: (tester) {
      expect(find.text(_zh.s04ListTitle(cow: _zh.cowName('angus', 5))), findsOneWidget);
      expect(find.text('870'), findsOneWidget);
      expect(find.text(_zh.s04FeeHowGrow(tier: _zh.tierName(0), rate: '1.1', kg: '790')), findsOneWidget);
      expect(_btn(tester, 'list-confirm').label, _zh.s04ListConfirm(price: '870'));
    },
  ),
  PageCase(
    'S04-05',
    '公牛上架中',
    (tester, lang) => showCow(tester, lang, detailCow(5, listed: true)),
    check: (tester) {
      expect(find.text(_zh.unlistFirst(price: '870')), findsOneWidget);
      expect(find.text(_zh.badgeListed), findsOneWidget);
      expect(_btn(tester, 'detail-unlist').onPressed, isNotNull);
      expect(_btn(tester, 'detail-breed').onPressed, isNull);
      expect(_btn(tester, 'detail-ship').onPressed, isNull);
    },
  ),
  PageCase(
    'S04-06',
    '耕牛沒下田：派去田裡',
    (tester, lang) => showCow(tester, lang, detailCow(2)),
    check: (tester) {
      expect(kvValue(tester, _zh.gPlow), '11 ${_zh.gPerHourRice}');
      expect(_btn(tester, 'detail-assign').onPressed, isNotNull);
      expect(find.byKey(const Key('no-field')), findsNothing);
    },
  ),
  PageCase(
    'S04-07',
    '耕牛在田裡工作',
    (tester, lang) => showCow(tester, lang, detailCow(2, field: 0)),
    check: (tester) {
      expect(find.text(_zh.recallFirst(n: 1)), findsOneWidget);
      expect(find.text(_zh.badgeWorking), findsOneWidget);
      expect(_btn(tester, 'detail-recall').onPressed, isNotNull);
      expect(_btn(tester, 'detail-breed').onPressed, isNull);
      expect(_btn(tester, 'detail-ship').onPressed, isNull);
    },
  ),
  PageCase(
    'S04-08',
    '小牛：長大倒數',
    (tester, lang) => showCow(tester, lang, detailCow(15)),
    check: (tester) {
      expect(kvValue(tester, _zh.s04Age), _zh.duration(m: 18));
      expect(kvValue(tester, _zh.s04GrowIn), _zh.duration(m: 42));
      expect(find.text(_zh.s04CalfHint), findsOneWidget);
      expect(_btn(tester, 'detail-breed').label, _zh.s04CantBreedYet);
      expect(_btn(tester, 'detail-ship').label, _zh.shipNotAdult);
      expect(_btn(tester, 'detail-ship').onPressed, isNull);
      expect(find.byKey(const Key('detail-grade-probs')), findsNothing);
    },
  ),
  PageCase(
    'S04-09',
    '已配種（一輩子一次）',
    (tester, lang) => showCow(tester, lang, detailCow(7, bred: true)),
    check: (tester) {
      expect(find.text(_zh.s04NoteBred), findsOneWidget);
      expect(_btn(tester, 'detail-breed').label, _zh.s04AlreadyBred);
      expect(_btn(tester, 'detail-breed').onPressed, isNull);
      expect(_btn(tester, 'detail-ship').onPressed, isNotNull);
    },
  ),
  PageCase(
    'S04-10',
    '老牛：標籤與說明',
    (tester, lang) => showCow(tester, lang, detailCow(8)),
    crop: find.byKey(const Key('detail-stack')),
    check: (tester) {
      expect(find.text(_zh.stageOld), findsOneWidget);
      expect(find.text(_zh.s04OldNote), findsOneWidget);
      expect(find.text(_zh.s04NoteBred), findsNothing, reason: '老牛配過種不加橘字（設計稿 S04-10）');
      expect(kvValue(tester, _zh.probType), _zh.s04UseBreed);
    },
  ),
  PageCase(
    'S04-11',
    '這頭牛已經不在了',
    (tester, lang) async {
      final (m, _, _) = await loadedModel(api: DetailApi(state: detailState(detailCow(11))));
      m.openCow('3');
      await pumpAppIn(tester, m, lang, prefs: swipeHintSeen);
      await tester.pump();
    },
    check: (tester) {
      expect(find.text(_zh.cowTitle(id: 3)), findsOneWidget);
      expect(find.text(_zh.s04GoneTitle), findsOneWidget);
      expect(find.byKey(const Key('gone-back')), findsOneWidget);
    },
  ),
  PageCase(
    'S04-12',
    '斷線：按鈕全部停用',
    (tester, lang) => showCow(tester, lang, detailCow(3), connected: false),
    crop: find.byKey(const Key('detail-actions')),
    check: (tester) {
      expect(_btn(tester, 'detail-breed').onPressed, isNull);
      expect(_btn(tester, 'detail-ship').onPressed, isNull);
    },
  ),
  PageCase(
    'S04-13',
    '耕牛：沒有空田，派不出去',
    (tester, lang) => showCow(tester, lang, detailCow(2), freeField: false),
    crop: find.byKey(const Key('detail-actions')),
    check: (tester) {
      expect(_btn(tester, 'detail-assign').onPressed, isNull);
      expect(find.text(_zh.s04NoField), findsOneWidget);
      expect(_btn(tester, 'detail-ship').onPressed, isNotNull);
    },
  ),
];

/// 打開荷斯坦 #3 的出貨確認；[setup] 先設定假伺服器（一直等、失敗、不能出貨）。
Future<(GameModel, FakePush)> showShip(WidgetTester tester, AppLang lang, {void Function(DetailApi api)? setup}) async {
  final api = DetailApi(state: detailState(detailCow(3)));
  setup?.call(api);
  final r = await showCow(tester, lang, detailCow(3), api: api);
  await openShip(tester);
  return r;
}

final s07Cases = <PageCase>[
  PageCase(
    'S07-01',
    '取得評級機率中',
    (tester, lang) => showShip(tester, lang, setup: (api) => api.pending = true),
    check: (tester) {
      expect(find.text(_zh.loadingPreview), findsOneWidget);
      expect(_btn(tester, 'ship-confirm').onPressed, isNull);
    },
  ),
  PageCase(
    'S07-02',
    '確認：各等級機率與收入',
    (tester, lang) => showShip(tester, lang),
    check: (tester) {
      expect(find.text(_zh.s07KgBeef(kg: '212')), findsOneWidget);
      expect(find.text(_zh.s07BeefPrice(price: '11.2')), findsOneWidget);
      expect(find.textContaining('2,968', findRichText: true), findsOneWidget);
      expect(find.textContaining('1,781', findRichText: true), findsOneWidget);
      expect(find.text(_zh.expectedValue(v: '2,514'), findRichText: true), findsOneWidget);
      expect(find.text(_zh.s07Note), findsOneWidget);
      expect(_btn(tester, 'ship-confirm').onPressed, isNotNull);
    },
  ),
  PageCase(
    'S07-03',
    '伺服器說現在不能出貨',
    (tester, lang) => showShip(
      tester,
      lang,
      setup: (api) => api.blockers = [
        {'code': 'cow_in_field', 'message': 'cow is working in a field'},
      ],
    ),
    check: (tester) {
      expect(find.text(_zh.s07BlockWorking), findsOneWidget);
      expect(find.text(_zh.s07Note), findsNothing);
      expect(_btn(tester, 'ship-confirm').onPressed, isNull);
    },
  ),
  PageCase(
    'S07-04',
    '評級機率載入失敗',
    (tester, lang) => showShip(tester, lang, setup: (api) => api.fail = true),
    crop: find.byKey(const Key('dialog')),
    check: (tester) {
      expect(find.text(_zh.s07ProbFailed), findsOneWidget);
      expect(find.byKey(const Key('preview-retry')), findsOneWidget);
      expect(_btn(tester, 'ship-confirm').onPressed, isNull);
    },
  ),
  PageCase(
    'S07-05',
    '斷線：「確定出貨」停用',
    (tester, lang) async {
      final (_, push) = await showShip(tester, lang);
      push.isConnected = false;
      await tester.pump();
    },
    crop: find.byKey(const Key('dialog')),
    check: (tester) {
      expect(find.textContaining('2,968', findRichText: true), findsOneWidget);
      expect(_btn(tester, 'ship-confirm').onPressed, isNull);
    },
  ),
];

/// 荷斯坦 #3 出貨，評到 [grade]（S20）。出貨後牧場沒有這頭牛了。
Future<void> showResult(WidgetTester tester, AppLang lang, String grade) async {
  final api = DetailApi(state: detailState(detailCow(3)))
    ..grade = grade
    ..after = detailState(detailCow(11));
  await showCow(tester, lang, detailCow(3), api: api);
  await openShip(tester);
  await confirmShip(tester);
}

PageCase _s20(String id, String grade) => PageCase(
  id,
  '評級 $grade',
  (tester, lang) => showResult(tester, lang, grade),
  check: (tester) {
    expect(find.byKey(const Key('ship-result')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('grade-big')), matching: find.text(grade)), findsOneWidget);
    expect(find.text(_zh.s20KgIn(kg: '212'), findRichText: true), findsOneWidget);
    expect(find.text(_zh.s20SellAll(v: fmt(designIncome[grade]!)), findRichText: true), findsOneWidget);
  },
);

final s20Cases = <PageCase>[_s20('S20-01', 'A'), _s20('S20-02', 'B'), _s20('S20-03', 'C')];
