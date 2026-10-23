// S05 倉庫（設計稿 boards/S05-倉庫）的畫面狀態。假資料照 design/m2/src/js/fixtures.js 的 WAREHOUSE：
// 牛奶 4 批（1、15、30、67 小時前收，最舊那批 27% 快壞了）、牛肉 2 批、稻米 2 批，倉庫第 1 級、容量 225。
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/ui/kit/cow_bits.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
import 'page_case.dart';
import 's03_cases.dart';

const _h = 3600.0;

/// 設計稿的一批牛奶：[ago] 小時前收（遊戲時間，倍率 1）。
Map<String, dynamic> milkLot(double qty, int tier, double fresh, double ago, {double? spoilsIn}) => {
  'qty': qty,
  'tier': tier,
  'collected_at': t0 - ago * _h,
  'freshness': fresh,
  'fresh_until': t0 - ago * _h + 9 * _h,
  'spoils_at': t0 + (spoilsIn ?? 96 - ago) * _h,
};

/// 設計稿 WAREHOUSE 的牛奶（新的在前面；伺服器的順序不一定，app 自己排）。
List<Map<String, dynamic>> designMilkLots() => [
  milkLot(16, 0, 0.27, 67, spoilsIn: 20),
  milkLot(22, 3, 0.64, 30),
  milkLot(48, 1, 0.82, 15),
  milkLot(60, 0, 1.0, 1),
];

List<Map<String, dynamic>> designBeefLots() => [
  {
    'qty': 698.0,
    'tier': 0,
    'breed': 'angus',
    'cow_id': 6,
    'shipped_at': t0 - 48 * _h,
    'grade': 'B',
    'quality': 0.86,
    'storage_factor': 0.86,
  },
  {
    'qty': 236.0,
    'tier': 0,
    'breed': 'holstein',
    'cow_id': 4,
    'shipped_at': t0 - 3 * _h,
    'grade': 'A',
    'quality': 1.25,
    'storage_factor': 1.0,
  },
];

List<Map<String, dynamic>> designRiceLots() => [
  {'qty': 64.0, 'harvested_at': t0 - 96 * _h, 'quality': 0.93},
  {'qty': 120.0, 'harvested_at': t0 - 5 * _h, 'quality': 1.0},
];

/// 設計稿的牧場，倉庫換成 [milk]、[beef]、[rice] 這幾批（容量 [cap]、第 1 級）。
Map<String, dynamic> warehouseState({
  List<Map<String, dynamic>>? milk,
  List<Map<String, dynamic>>? beef,
  List<Map<String, dynamic>>? rice,
  double cap = 225,
}) {
  final st = ranchState();
  final m = milk ?? designMilkLots(), b = beef ?? designBeefLots(), r = rice ?? designRiceLots();
  double total(List<Map<String, dynamic>> lots) => lots.fold(0, (a, l) => a + (l['qty'] as num));
  return {
    ...st,
    'warehouse': {
      'capacity': cap,
      'used': total(m),
      'milk_total': total(m),
      'beef_total': total(b),
      'rice_total': total(r),
      'milk_lots': m,
      'beef_lots': b,
      'rice_lots': r,
    },
    'upgrades': {
      ...(st['upgrades'] as Map<String, dynamic>),
      'warehouse': {'level': 1, 'cost': 480, 'capacity': cap, 'next_capacity': 337},
    },
  };
}

/// 打開倉庫頁（牧場頁頂列的「倉庫」小鈕）。
Future<void> showWarehouse(WidgetTester tester, AppLang lang, Map<String, dynamic> state, {bool tall = false}) async {
  final m = await ranchModel(state: state);
  await pumpAppIn(tester, m, lang, prefs: swipeHintSeen);
  await tester.tap(find.byKey(const Key('warehouse-btn')));
  await tester.pump();
  if (tall) await growToFit(tester, find.byKey(const Key('warehouse')));
}

final _zh = Strings.forLang(AppLang.zhHant);

final s05Cases = <PageCase>[
  PageCase(
    'S05-01',
    '牧場頁的倉庫小鈕（奶桶面板左上角；第 23 輪 03-B）',
    (tester, lang) async => pumpAppIn(tester, await ranchModel(), lang, prefs: swipeHintSeen),
    crop: find.byKey(const Key('dock-head')),
    check: (tester) {
      expect(
        find.descendant(of: find.byKey(const Key('warehouse-btn')), matching: find.text(_zh.warehouseTitle)),
        findsOneWidget,
      );
    },
  ),
  PageCase(
    'S05-02',
    '倉庫詳細：每一批（長頁）',
    (tester, lang) => showWarehouse(tester, lang, warehouseState(), tall: true),
    check: (tester) {
      expect(find.text(_zh.warehouseTitle), findsWidgets);
      expect(find.text(_zh.gLevelN(n: 1)), findsOneWidget);
      expect(find.text(_zh.s05LotsOldestFirst(n: 4)), findsOneWidget);
      expect(find.text(_zh.s05LotsOldestFirst(n: 2)), findsNWidgets(2));
      expect(find.textContaining('146 / 225', findRichText: true), findsOneWidget);
      expect(find.text(_zh.s05CollectedAgo(ago: _zh.timeAgo(h: 1))), findsOneWidget);
      expect(find.text(_zh.s05CollectedAgo(ago: _zh.timeAgo(h: 30))), findsOneWidget, reason: '牛奶一律寫小時');
      expect(find.byKey(const Key('lot-bad')), findsOneWidget);
      expect(find.text(_zh.s05Spoiling), findsOneWidget);
      expect(
        find.text('${_zh.s05CollectedAgo(ago: _zh.timeAgo(h: 67))}${_zh.gSep}${_zh.s05SpoilIn(h: 20)}'),
        findsOneWidget,
      );
      expect(
        find.text('${_zh.s05ShippedFrom(cow: _zh.cowName('holstein', 4))}${_zh.gSep}${_zh.timeAgo(h: 3)}'),
        findsOneWidget,
      );
      expect(
        find.text('${_zh.s05ShippedFrom(cow: _zh.cowName('angus', 6))}${_zh.gSep}${_zh.timeAgo(d: 2)}'),
        findsOneWidget,
      );
      expect(find.text(_zh.s05CollectedAgo(ago: _zh.timeAgo(d: 4))), findsOneWidget, reason: '稻米超過一天寫天');
      expect(find.text(_zh.s05Stored(pct: 86)), findsOneWidget);
      // 稀有度的賣價倍數（伺服器的 economy.tier_mult）
      expect(find.text('${_zh.s05MilkName(tier: _zh.tierName(1))} ×1.3'), findsOneWidget);
      expect(find.text('${_zh.s05MilkName(tier: _zh.tierName(3))} ×2.5'), findsOneWidget);
      expect(find.text(_zh.s05Stored(pct: 93)), findsOneWidget);
      expect(tester.widget<AppButton>(find.byKey(const Key('go-sell'))).onPressed, isNotNull);
    },
  ),
  PageCase(
    'S05-03',
    '空倉庫',
    (tester, lang) => showWarehouse(tester, lang, warehouseState(milk: [], beef: [], rice: [])),
    check: (tester) {
      expect(find.text(_zh.s05EmptyMilk), findsOneWidget);
      expect(find.text(_zh.s05EmptyBeef), findsOneWidget);
      expect(find.text(_zh.s05EmptyRice), findsOneWidget);
      expect(tester.widget<AppButton>(find.byKey(const Key('go-sell'))).onPressed, isNull);
    },
  ),
  PageCase(
    'S05-04',
    '倉庫滿了（牛奶）',
    (tester, lang) => showWarehouse(
      tester,
      lang,
      warehouseState(
        milk: [milkLot(28, 3, 0.7, 26), milkLot(77, 1, 0.86, 12), milkLot(120, 0, 1, 1)],
        beef: [],
        rice: [designRiceLots().last],
      ),
    ),
    check: (tester) {
      expect(find.text(_zh.s05Full), findsOneWidget);
      expect(find.textContaining('225 / 225', findRichText: true), findsOneWidget);
      expect(tester.widget<AppButton>(find.byKey(const Key('upgrade-warehouse'))).kind, ButtonKind.primary);
    },
  ),
  PageCase(
    'S05-05',
    '有一批牛奶快壞了（新鮮度低於 30%）',
    (tester, lang) => showWarehouse(tester, lang, warehouseState(), tall: true),
    crop: find.byKey(const Key('lot-bad')),
    check: (tester) {
      expect(find.byKey(const Key('lot-bad')), findsOneWidget);
      expect(find.text('27%'), findsOneWidget);
    },
  ),
  PageCase(
    'S05-06',
    '有雜種牛的牛奶、牛肉',
    // 設計稿：牛奶 3 批（中間一批雜種牛奶 18 瓶、6 小時前收），牛肉 2 批（雜種牛 #21 的 412 公斤 B 級、1 小時前），稻米 1 批
    (tester, lang) => showWarehouse(
      tester,
      lang,
      warehouseState(
        milk: [
          milkLot(60, 0, 1.0, 1),
          {...milkLot(18, 0, 0.95, 6), 'hybrid': true},
          milkLot(48, 1, 0.82, 15),
        ],
        beef: [
          {
            'qty': 412.0,
            'tier': 0,
            'hybrid': true,
            'breed': 'hybrid',
            'cow_id': 21,
            'shipped_at': t0 - 1 * _h,
            'grade': 'B',
            'quality': 0.6,
            'storage_factor': 1.0,
          },
          designBeefLots()[1],
        ],
        rice: designRiceLots().sublist(1),
      ),
      tall: true,
    ),
    check: (tester) {
      // 雜種的批次：灰星、「雜種牛奶 ×0.6」、「雜種牛 #21 出貨」
      expect(find.byType(MixStarChip), findsNWidgets(2));
      expect(find.text('${_zh.s05MixMilk} ×0.6'), findsOneWidget);
      expect(find.textContaining(_zh.s05ShippedFrom(cow: _zh.cowName('hybrid', 21))), findsOneWidget);
    },
  ),
];
