// S19 商店抽牛、S10 設施升級（設計稿 boards/S19-商店：抽牛、S10）的畫面狀態。假資料照 design/m2/src/js/fixtures.js 的
// SHOP、SHOP_TYPE、UPGRADES：A 3,200、B 1,700、C 900；擴建過 10 次（12 → 13 格）、奶桶第 1 級（42 → 63 瓶）、
// 倉庫第 1 級（225 → 337 瓶）、冷藏第 1 / 4 級（9 → 12 小時）。機率、價格都是伺服器給的。
import 'dart:async';

import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/shop/shop_page.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
import 'page_case.dart';
import 's03_cases.dart';

Map<String, dynamic> _grade(String g, int price, List<double> tier) => {
  'grade': g,
  'price': price,
  'tier_probs': tier,
  'type_probs': {'dairy': 0.45, 'dual': 0.275, 'beef': 0.275},
  'bull_prob': 0.5,
};

/// GET /v1/shop：設計稿的機率（A 42.2／42.2／14.1／1.6%，B 75.4／22.4／2.2／0.07%，C 97／2.9／0.03／<0.01%）。
Map<String, dynamic> designShopJson() => {
  'free_slots': 2,
  'grades': [
    _grade('A', 3200, [0.421875, 0.421875, 0.140625, 0.015625]),
    _grade('B', 1700, [0.754, 0.224, 0.022, 0.0007]),
    _grade('C', 900, [0.97, 0.029, 0.0003, 0.000001]),
  ],
};

/// 設計稿的設施（UPGRADES）。
Map<String, dynamic> designUpgrades({
  Map<String, dynamic>? pen,
  Map<String, dynamic>? bucket,
  Map<String, dynamic>? fresh,
}) => {
  'pen': pen ?? {'level': 10, 'cost': 12150, 'next_open_at': null, 'slots': 12, 'next_slots': 13},
  'bucket': bucket ?? {'level': 1, 'cost': 310, 'capacity': 42, 'next_capacity': 63},
  'warehouse': {'level': 1, 'cost': 480, 'capacity': 225, 'next_capacity': 337},
  // max：cow-back 要在協定加的冷藏最高等級（「第 1 / 4 級」）
  'fresh':
      fresh ?? {'level': 1, 'max': 4, 'cost': 4000, 'fresh_h': 9, 'half_h': 60, 'next_fresh_h': 12, 'next_half_h': 72},
  'field': {'count': 3, 'max': 12, 'cost': 2000},
};

/// 設計稿的牧場，商店價格和設施照設計稿。
Map<String, dynamic> shopState({double coins = 12480, Map<String, dynamic>? upgrades, int? penSlots, int? penUsed}) => {
  ...ranchState(coins: coins, penSlots: penSlots ?? 12, penUsed: penUsed),
  'shop': {
    'grades': [
      {'grade': 'A', 'price': 3200},
      {'grade': 'B', 'price': 1700},
      {'grade': 'C', 'price': 900},
    ],
  },
  'upgrades': upgrades ?? designUpgrades(),
};

/// 商店的假伺服器：機率可以一直等、可以失敗；抽牛、升級之後換成 [after] 的 state。
class ShopApi extends FakeGameApi {
  ShopApi({Map<String, dynamic>? state}) : super(state: state ?? shopState(), market: ranchMarket());

  bool pending = false;
  bool fail = false;
  Map<String, dynamic>? after;

  @override
  Future<ShopInfo> shop() async {
    calls.add('shop');
    if (pending) return Completer<ShopInfo>().future;
    if (fail) throw const ApiException(500, 'internal', 'boom');
    return ShopInfo.fromJson(designShopJson());
  }

  @override
  Future<ShopBuyResult> shopBuy(String grade) async {
    calls.add('shop-buy:$grade');
    if (after != null) stateJson = after!;
    // 設計稿抽到的：高地牛 #17（耕牛、母、優良、小牛，還要 2 小時長大）
    final calf = designCow(17, 'highland', stage: 'calf', growMin: 120);
    return ShopBuyResult(grade: grade, cow: Cow.fromJson(calf), cost: 3200);
  }

  @override
  Future<Map<String, dynamic>> upgrade(UpgradeKind kind) async {
    calls.add('upgrade:${kind.wire}');
    if (after != null) stateJson = after!;
    return {};
  }
}

/// 打開商店（[facility] 就是設施那一頁），等機率回來。
Future<GameModel> showShop(WidgetTester tester, AppLang lang, {ShopApi? api, bool facility = false}) async {
  final m = await ranchModel(api: api ?? ShopApi());
  m.selectShop(facility: facility);
  m.selectTab(AppTab.shop);
  await pumpAppIn(tester, m, lang, prefs: swipeHintSeen);
  await tester.pump();
  await tester.pump();
  return m;
}

final _zh = Strings.forLang(AppLang.zhHant);
final _odds = [for (final g in designShopJson()['grades'] as List) ShopGrade.fromJson(g as Map<String, dynamic>)];

GradeCard _card(String g, {double coins = 12480, bool loading = false, bool failed = false, bool penFull = false}) =>
    GradeCard(
      grade: g,
      price: _odds.firstWhere((o) => o.grade == g).price,
      odds: loading || failed ? null : _odds.firstWhere((o) => o.grade == g),
      loading: loading,
      failed: failed,
      coins: coins,
      penFull: penFull,
      canAct: true,
      onBuy: () {},
      onRetry: () {},
    );

final s19Cases = <PageCase>[
  PageCase(
    'S19-01',
    'A、B、C 三個等級與公開機率',
    (tester, lang) => showShop(tester, lang),
    check: (tester) {
      expect(find.text(_zh.s19Rule), findsOneWidget);
      expect(find.byKey(const Key('prob-grid')), findsNWidgets(3));
      expect(find.textContaining('42.2%', findRichText: true), findsNWidgets(2));
      expect(find.textContaining('0.07%', findRichText: true), findsOneWidget);
      expect(find.textContaining('<0.01%', findRichText: true), findsOneWidget);
      expect(find.text(_zh.costCoins(v: '3,200')), findsOneWidget);
    },
  ),
  PageCase(
    'S19-02',
    '機率載入中、載入失敗',
    (tester, lang) async => pumpSheet(tester, lang, [_card('A', loading: true), _card('B', failed: true)]),
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.text(_zh.loadingShop), findsOneWidget);
      expect(find.text(_zh.s19ProbFailed), findsOneWidget);
    },
  ),
  PageCase(
    'S19-03',
    '金幣不夠：按鈕停用並說明',
    (tester, lang) async => pumpSheet(tester, lang, [_card('A', coins: 1250), _card('B', coins: 1250)]),
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.text(_zh.notEnoughCoins(n: '1,950')), findsOneWidget);
      expect(find.text(_zh.notEnoughCoins(n: '450')), findsOneWidget);
    },
  ),
  PageCase(
    'S19-04',
    '牛舍滿了：三顆都停用',
    (tester, lang) async => pumpSheet(tester, lang, [
      NoteLine(icon: 'warn', text: Strings.forLang(lang).s19PenFull(used: 12, slots: 12), kind: NoteKind.warn),
      _card('C', penFull: true),
    ]),
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.text(_zh.s19PenFull(used: 12, slots: 12)), findsOneWidget);
    },
  ),
  PageCase(
    'S19-05',
    '抽到的結果',
    (tester, lang) async {
      final api = ShopApi()..after = shopState(coins: 12480 - 3200);
      await showShop(tester, lang, api: api);
      await tester.tap(find.byKey(const Key('buy-A')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    },
    check: (tester) {
      expect(find.byKey(const Key('drawn-cow')), findsOneWidget);
      expect(find.text(_zh.drawnTitle(g: 'A')), findsOneWidget);
      expect(find.text(_zh.cowName('highland', 17)), findsOneWidget);
      expect(find.text(_zh.s19DrawnDraft(time: _zh.countdown(7200))), findsOneWidget);
      expect(find.text('9,280'), findsOneWidget);
    },
  ),
  PageCase(
    'S10-01',
    '升級列表',
    (tester, lang) => showShop(tester, lang, facility: true),
    check: (tester) {
      expect(find.text(_zh.s10PenTimes(n: 10)), findsOneWidget);
      expect(find.text(_zh.effectPen(a: '12', b: '13')), findsOneWidget);
      expect(find.text(_zh.s10EffectBottles(a: '42', b: '63')), findsOneWidget);
      expect(find.text(_zh.s10LevelOf(n: 1, max: 4)), findsOneWidget);
      expect(find.text(_zh.s10FieldsNote), findsOneWidget);
    },
  ),
  PageCase(
    'S10-02',
    '金幣不夠',
    (tester, lang) => showShop(tester, lang, api: ShopApi(state: shopState(coins: 10000)), facility: true),
    crop: find.byKey(const Key('up-card-pen')),
    check: (tester) {
      expect(find.text(_zh.notEnoughCoins(n: '2,150')), findsOneWidget);
    },
  ),
  PageCase(
    'S10-03',
    '已滿級',
    (tester, lang) async {
      await showShop(
        tester,
        lang,
        api: ShopApi(
          state: shopState(
            upgrades: designUpgrades(
              fresh: {'level': 4, 'max': 4, 'cost': null, 'fresh_h': 18, 'half_h': 96, 'next_fresh_h': null},
            ),
          ),
        ),
        facility: true,
      );
      // 窄手機上冷藏那一列在畫面外，ListView 還沒排到：先捲過去
      final card = find.byKey(const Key('up-card-fresh'));
      await tester.scrollUntilVisible(
        card,
        150,
        scrollable: find.descendant(of: find.byKey(const Key('shop')), matching: find.byType(Scrollable)).first,
      );
      await tester.pump();
    },
    crop: find.byKey(const Key('up-card-fresh')),
    check: (tester) {
      expect(find.byKey(const Key('up-maxed-fresh')), findsOneWidget);
      expect(find.text(_zh.s10FreshMax(h: '18')), findsOneWidget);
    },
  ),
  PageCase(
    'S10-04',
    '第一次擴建還沒開放（開局第 15 分鐘）',
    (tester, lang) => showShop(
      tester,
      lang,
      api: ShopApi(
        state: shopState(
          upgrades: designUpgrades(
            pen: {'level': 0, 'cost': 280, 'next_open_at': t0 + 180, 'slots': 2, 'next_slots': 3},
          ),
        ),
      ),
      facility: true,
    ),
    crop: find.byKey(const Key('up-card-pen')),
    check: (tester) {
      expect(find.text(_zh.opensIn(v: _zh.countdown(180))), findsOneWidget);
      expect(find.text(_zh.s10PenNever), findsOneWidget);
    },
  ),
  PageCase(
    'S10-05',
    '升級成功',
    (tester, lang) async {
      final api = ShopApi()
        ..after = shopState(
          coins: 12480 - 310,
          upgrades: designUpgrades(bucket: {'level': 2, 'cost': 481, 'capacity': 63, 'next_capacity': 94}),
        );
      await showShop(tester, lang, api: api, facility: true);
      await tester.tap(find.byKey(const Key('up-bucket')));
      await tester.pump();
      await tester.pump();
    },
    check: (tester) {
      expect(
        find.text(
          _zh.s10Upgraded(
            what: _zh.bucketTitle,
            effect: _zh.s10EffectBottles(a: '42', b: '63'),
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(_zh.s10EffectBottles(a: '63', b: '94')), findsOneWidget);
      expect(find.text('12,170'), findsOneWidget);
    },
  ),
];
