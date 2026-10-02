// S06 市場（設計稿 boards/S06-市場）的畫面狀態。假資料照 design/m2/src/js/fixtures.js 的 MARKET、NEWS 和 s06.js：
// 收購價 牛奶 13.4、牛肉 11.2、稻米 5.35（基本價 12、12、5）；新聞 4 則；
// 庫存 牛奶 146 瓶（3 批）、牛肉 934 公斤（2 批）、稻米 184 公斤（2 批）；試算結果照設計稿（伺服器算的，假資料直接給）。
import 'dart:async';

import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/market/market_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
import 'page_case.dart';
import 's03_cases.dart';
import 's05_cases.dart';

const _h = 3600.0;

/// 一則新聞：[ago] 秒以前發布；[upcoming] 是預告（還沒開始影響價格）。
Map<String, dynamic> newsJson(
  int id,
  String code,
  String? commodity,
  String dir, {
  required double ago,
  bool upcoming = false,
  bool big = false,
  double pct = 0.12,
}) => {
  'id': id,
  'code': code,
  'params': {},
  'pct': dir == 'up' ? pct : -pct,
  'commodity': commodity,
  'targets': commodity == null ? ['milk', 'beef', 'rice'] : [commodity],
  'direction': dir,
  'big': big,
  'time': t0 - ago,
  'announce_at': t0 - ago,
  'start_at': upcoming ? t0 + 1800 : t0 - ago,
  'end_at': t0 + 7200,
  'state': upcoming ? 'upcoming' : 'active',
};

/// 設計稿的 4 則新聞（新的在前面）。
List<Map<String, dynamic>> designNews() => [
  newsJson(101, 'milk_up.1', 'milk', 'up', ago: 12 * 60),
  newsJson(102, 'beef_up.3', 'beef', 'up', ago: _h, upcoming: true),
  newsJson(103, 'all_down.2', null, 'down', ago: 3 * _h),
  newsJson(104, 'rice_up.1', 'rice', 'up', ago: 5 * _h),
];

/// 設計稿的倉庫：牛奶 146 瓶（3 批）、牛肉 934 公斤（2 批）、稻米 184 公斤（2 批）。
Map<String, dynamic> marketState({List<Map<String, dynamic>>? milk, double coins = 12480}) => {
  ...warehouseState(milk: milk ?? [milkLot(22, 3, 0.64, 30), milkLot(64, 1, 0.82, 15), milkLot(60, 0, 1.0, 1)]),
  'coins': coins,
};

/// 試算、賣出由伺服器算：假資料照設計稿直接給答案。
class MarketApi extends FakeGameApi {
  MarketApi({Map<String, dynamic>? state, Map<String, dynamic>? market, this.answers = const {}})
    : super(
        state: state ?? marketState(),
        market: market ?? ranchMarket(news: designNews()),
      );

  /// (商品, 數量) → (均價, 總額, 一次賣太多)。
  final Map<(Commodity, double), (double, double, bool)> answers;

  /// 試算一直等不到回應（S06-09）。
  bool pending = false;

  /// 試算失敗（S06-12）。
  bool fail = false;

  /// 賣出之後伺服器的 state。
  Map<String, dynamic>? afterSell;

  double _price(Commodity c) => ((marketJson[c.wire] as Map)['price'] as num).toDouble();

  @override
  Future<SellQuote> sellQuote(Commodity commodity, double qty) async {
    calls.add('quote:${commodity.wire}:$qty');
    if (pending) return Completer<SellQuote>().future;
    if (fail) throw const ApiException(500, 'internal', 'boom');
    final a = answers[(commodity, qty)];
    final p = _price(commodity);
    return SellQuote(
      qty: qty,
      avgPrice: a?.$1 ?? p,
      total: a?.$2 ?? p * qty,
      marketPrice: p,
      serverWarn: a?.$3 ?? false,
    );
  }

  @override
  Future<SellResult> sell(Commodity commodity, double qty) async {
    calls.add('sell:${commodity.wire}:$qty');
    final a = answers[(commodity, qty)]!;
    if (afterSell != null) stateJson = afterSell!;
    return SellResult(qty: qty, avgPrice: a.$1, total: a.$2);
  }
}

/// 設計稿的試算結果（s06.js 的 MILK_SELL 等）。
final designAnswers = <(Commodity, double), (double, double, bool)>{
  (Commodity.milk, 130): (14.8, 1924, false),
  (Commodity.milk, 146): (14.6, 2132, false),
  (Commodity.milk, 16): (11.8, 189, false),
  (Commodity.beef, 236): (13.9, 3280, false),
  (Commodity.beef, 934): (10.4, 9714, true),
  (Commodity.rice, 184): (5.3, 975, false),
};

/// 打開市場分頁、選好 [commodity]，等第一次試算（全部）回來。回傳模型和推播（可以切斷線）。
Future<(GameModel, FakePush)> showMarket(
  WidgetTester tester,
  AppLang lang, {
  MarketApi? api,
  Commodity commodity = Commodity.milk,
  bool connected = true,
}) async {
  final a = api ?? MarketApi(answers: designAnswers);
  final (m, _, push) = await loadedModel(api: a, connected: connected);
  m.selectMarket(commodity);
  m.selectTab(AppTab.market);
  await pumpAppIn(tester, m, lang, prefs: swipeHintSeen);
  await tester.pump(); // 第一次試算（全部）
  await tester.pump();
  return (m, push);
}

/// 市場那一頁上下捲的那一個（ListView 還沒排到的子項找不到，要先捲過去）。
Finder get marketScroll =>
    find.descendant(of: find.byKey(const Key('market')), matching: find.byType(Scrollable)).first;

/// 把滑桿拉到 [qty]（庫存 [stock]），等 0.3 秒後的試算回來。
Future<void> slideTo(WidgetTester tester, double qty, double stock) async {
  final slider = find.byKey(const Key('sell-slider'));
  await tester.scrollUntilVisible(slider, 150, scrollable: marketScroll);
  await tester.pump();
  final r = tester.getRect(slider);
  await tester.tapAt(Offset(r.left + r.width * qty / stock, r.center.dy));
  await tester.pump(SellCard.debounce);
  await tester.pump();
}

/// 捲到賣出面板（設計稿：面板的上緣在內容區上面 6）。
Future<void> scrollToSell(WidgetTester tester) async {
  final card = find.byKey(const Key('sell-card'));
  await tester.scrollUntilVisible(card, 150, scrollable: marketScroll);
  await tester.pump();
  final pos = tester.state<ScrollableState>(marketScroll).position;
  final listTop = tester.getTopLeft(find.byKey(const Key('market'))).dy;
  final delta = tester.getTopLeft(card).dy - (listTop + 6);
  pos.jumpTo((pos.pixels + delta).clamp(0.0, pos.maxScrollExtent));
  await tester.pump();
}

final _zh = Strings.forLang(AppLang.zhHant);

final s06Cases = <PageCase>[
  PageCase(
    'S06-01',
    '選牛奶（比平常高）：整頁（長頁）',
    (tester, lang) async {
      await showMarket(tester, lang);
      await slideTo(tester, 130, 146);
      await growToFit(tester, find.byKey(const Key('market')));
    },
    check: (tester) {
      expect(find.text(_zh.s06Title), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('price-milk')),
          matching: find.textContaining('13.4', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('headline')), findsOneWidget);
      expect(find.byKey(const Key('sell-qty')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('sell-qty'))).data, '130');
      expect(tester.widget<Text>(find.byKey(const Key('est-total'))).data, _zh.costCoins(v: '1,924'));
      expect(find.text(_zh.inventory(qty: '146', unit: _zh.unitMilk) + _zh.s06Lots(n: 3)), findsOneWidget);
      expect(find.byKey(const Key('news')), findsOneWidget);
    },
  ),
  PageCase(
    'S06-02',
    '選牛肉（比平常低）',
    (tester, lang) async {
      await showMarket(tester, lang, commodity: Commodity.beef);
      await slideTo(tester, 236, 934);
      // 拉滑桿時捲到了賣出面板；設計稿停在最上面（收購價、新聞、賣出面板的上半）
      tester.state<ScrollableState>(marketScroll).position.jumpTo(0);
      await tester.pump();
    },
    check: (tester) {
      expect(tester.widget<Text>(find.byKey(const Key('sell-qty'))).data, '236');
      expect(tester.widget<Text>(find.byKey(const Key('est-total'))).data, _zh.costCoins(v: '3,280'));
    },
  ),
  PageCase(
    'S06-03',
    '選稻米',
    (tester, lang) => showMarket(tester, lang, commodity: Commodity.rice),
    check: (tester) {
      expect(tester.widget<Text>(find.byKey(const Key('sell-qty'))).data, '184');
      expect(tester.widget<Text>(find.byKey(const Key('est-total'))).data, _zh.costCoins(v: '975'));
    },
  ),
  PageCase(
    'S06-06',
    '收購價載入中',
    (tester, lang) async {
      final m = await ranchModel(api: MarketApi(answers: designAnswers));
      m.market = null;
      m.selectTab(AppTab.market);
      await pumpAppIn(tester, m, lang, prefs: swipeHintSeen);
    },
    check: (tester) {
      expect(find.byKey(const Key('prices-loading')), findsOneWidget);
      expect(find.text(_zh.s06Loading), findsOneWidget);
      expect(find.byKey(const Key('sell-card')), findsNothing);
    },
  ),
  PageCase(
    'S06-08',
    '賣出：倉庫是空的',
    (tester, lang) async {
      await showMarket(
        tester,
        lang,
        api: MarketApi(
          state: marketState(milk: []),
          answers: designAnswers,
        ),
      );
      await scrollToSell(tester);
    },
    crop: find.byKey(const Key('sell-card')),
    check: (tester) {
      expect(find.text(_zh.nothingToSell(name: _zh.milk)), findsOneWidget);
    },
  ),
  PageCase(
    'S06-09',
    '賣出：試算中（按鈕停用）',
    (tester, lang) async {
      await showMarket(tester, lang, api: MarketApi(answers: designAnswers)..pending = true);
      await slideTo(tester, 130, 146);
      await scrollToSell(tester);
    },
    crop: find.byKey(const Key('sell-card')),
    check: (tester) {
      expect(find.text(_zh.quoting), findsOneWidget);
    },
  ),
  PageCase(
    'S06-10',
    '賣出：試算完成（往下捲到賣出）',
    (tester, lang) async {
      await showMarket(tester, lang);
      await slideTo(tester, 130, 146);
      await scrollToSell(tester);
    },
    check: (tester) {
      expect(
        tester.widget<Text>(find.byKey(const Key('est-avg'))).data,
        _zh.estAvgValue(avg: '14.8', unit: _zh.unitMilk),
      );
      expect(find.text(_zh.sellConfirm(qty: '130', unit: _zh.unitMilk)), findsOneWidget);
    },
  ),
  PageCase(
    'S06-11',
    '賣出：一次賣太多',
    (tester, lang) async {
      await showMarket(tester, lang, commodity: Commodity.beef);
      await scrollToSell(tester);
    },
    check: (tester) {
      expect(find.byKey(const Key('big-warn')), findsOneWidget);
      expect(find.text(_zh.tooMuch), findsOneWidget);
    },
  ),
  PageCase(
    'S06-12',
    '賣出：試算失敗（按鈕停用＋重試）',
    (tester, lang) async {
      await showMarket(tester, lang, api: MarketApi(answers: designAnswers)..fail = true);
      await slideTo(tester, 130, 146);
      await scrollToSell(tester);
    },
    crop: find.byKey(const Key('sell-card')),
    check: (tester) {
      expect(find.text(_zh.s06QuoteFailed), findsOneWidget);
      expect(find.byKey(const Key('quote-retry')), findsOneWidget);
    },
  ),
  PageCase(
    'S06-13',
    '賣出成功',
    (tester, lang) async {
      final api = MarketApi(answers: designAnswers)
        ..afterSell = marketState(milk: [milkLot(16, 0, 1.0, 1)], coins: 14404);
      await showMarket(tester, lang, api: api);
      await slideTo(tester, 130, 146);
      final confirm = find.byKey(const Key('sell-confirm'));
      await tester.scrollUntilVisible(confirm, 150, scrollable: marketScroll);
      await tester.tap(confirm);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await scrollToSell(tester);
    },
    check: (tester) {
      expect(find.text(_zh.sold(qty: '130', unit: _zh.unitMilk, avg: '14.8', total: '1,924')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('sell-qty'))).data, '16');
      expect(find.text('14,404'), findsOneWidget);
    },
  ),
  PageCase(
    'S06-14',
    '新聞：沒有、漲、跌、預告、大新聞、全部商品',
    (tester, lang) async {
      final m = await ranchModel(api: MarketApi(answers: designAnswers));
      final news = [
        NewsItem.fromJson(newsJson(201, 'beef_up.1', 'beef', 'up', ago: 0, big: true, pct: 0.35)),
        for (final n in designNews()) NewsItem.fromJson(n),
      ];
      await pumpSheet(tester, lang, [const NewsCard(items: []), NewsCard(items: news)], model: m);
    },
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.text(_zh.noNews), findsOneWidget);
      expect(find.text(_zh.s06BigNews), findsOneWidget);
      expect(find.text(_zh.s06Upcoming), findsOneWidget);
      expect(find.text(_zh.bothTag), findsOneWidget);
    },
  ),
  PageCase(
    'S06-15',
    '斷線：滑桿與按鈕停用',
    (tester, lang) async {
      // 試算完才斷線：數量、預估還在，滑桿和按鈕停用
      final (_, push) = await showMarket(tester, lang);
      await slideTo(tester, 130, 146);
      push.isConnected = false;
      await tester.pump();
      await scrollToSell(tester);
    },
    crop: find.byKey(const Key('sell-card')),
    check: (tester) {
      expect(find.byKey(const Key('sell-confirm')), findsOneWidget);
    },
  ),
  PageCase(
    'S06-16',
    '數字最長（量測用）',
    (tester, lang) async {
      final lots = [for (var i = 0; i < 14; i++) i == 0 ? 12480 - 13 * 900.0 : 900.0];
      final st = marketState(coins: 987654);
      final wh = st['warehouse'] as Map<String, dynamic>;
      wh['beef_lots'] = [
        for (final (i, q) in lots.indexed)
          {
            'qty': q,
            'tier': 0,
            'breed': 'angus',
            'cow_id': i + 1,
            'shipped_at': t0 - (i + 1) * _h,
            'grade': 'B',
            'quality': 1.0,
            'storage_factor': 1.0,
          },
      ];
      wh['beef_total'] = 12480.0;
      final api = MarketApi(
        state: st,
        market: ranchMarket(beef: 20.4, news: designNews()),
        answers: {(Commodity.beef, 12480): (18.35, 229008, false)},
      );
      await showMarket(tester, lang, api: api, commodity: Commodity.beef);
      await scrollToSell(tester);
    },
    check: (tester) {
      expect(tester.widget<Text>(find.byKey(const Key('est-total'))).data, _zh.costCoins(v: '229,008'));
      expect(find.text('987,654'), findsOneWidget);
    },
  ),
];
