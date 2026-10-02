// S06 市場：收購價（比平常高低、漲跌顏色）、點一列換商品、賣出面板（防抖動試算、¼½全部、一次賣太多、試算失敗重試、
// 賣出、斷線停用）、推播的新價格和新聞；牧場的大新聞「去市場看看」選好那種商品。
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/l10n/gen/strings.g.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/theme/tokens.dart';
import 'package:cowfarm/ui/kit/app_icon.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:cowfarm/ui/market/market_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pages/page_case.dart';
import 'pages/s03_cases.dart';
import 'pages/s05_cases.dart';
import 'pages/s06_cases.dart';

final _zh = Strings.forLang(AppLang.zhHant);

/// 那一列「比平常…」的顏色（漲跌的三角形和字同色）。
Color? _vsColor(WidgetTester tester, String commodity) => tester
    .widget<AppIcon>(find.descendant(of: find.byKey(Key('price-$commodity')), matching: find.byType(AppIcon)).last)
    .color;

Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 150, scrollable: marketScroll);
  await tester.pump();
}

AppButton _confirm(WidgetTester tester) => tester.widget<AppButton>(find.byKey(const Key('sell-confirm')));

void main() {
  setUpAll(loadAppAssets);

  testWidgets('收購價：比平常高（繁中漲紅）、比平常低（跌綠）；下面寫平常的價', (tester) async {
    Screen.w390.apply(tester);
    await showMarket(tester, AppLang.zhHant);
    expect(_vsColor(tester, 'milk'), AppColors.up(upIsRed: true));
    expect(_vsColor(tester, 'beef'), AppColors.down(upIsRed: true));
    expect(find.textContaining('12%', findRichText: true), findsWidgets);
    expect(find.text(_zh.s06BaseLine(milk: '12', beef: '12', rice: '5')), findsOneWidget);
  });

  testWidgets('漲跌顏色照設定（英文預設綠漲紅跌）', (tester) async {
    Screen.w390.apply(tester);
    final m = await ranchModel(api: MarketApi(answers: designAnswers));
    m.selectTab(AppTab.market);
    await pumpAppIn(tester, m, AppLang.en, prefs: swipeHintSeen);
    await tester.pump();
    expect(_vsColor(tester, 'milk'), AppColors.up(upIsRed: false));
    expect(_vsColor(tester, 'beef'), AppColors.down(upIsRed: false));
  });

  testWidgets('點一列換商品：賣出面板換成那一種，重新試算全部的量', (tester) async {
    Screen.w390.apply(tester);
    final api = MarketApi(answers: designAnswers);
    final (m, _) = await showMarket(tester, AppLang.zhHant, api: api);
    expect(api.calls, contains('quote:milk:146.0'));
    await tester.tap(find.byKey(const Key('price-beef')));
    await tester.pump();
    await tester.pump();
    expect(m.marketCommodity, Commodity.beef);
    expect(find.text(_zh.s06SellTitle(name: _zh.beef)), findsOneWidget);
    expect(api.calls, contains('quote:beef:934.0'));
  });

  testWidgets('拉滑桿：停 0.3 秒才試算，中間拉的不算；¼、½、全部', (tester) async {
    Screen.w390.apply(tester);
    final api = MarketApi(answers: designAnswers);
    await showMarket(tester, AppLang.zhHant, api: api);
    final slider = find.byKey(const Key('sell-slider'));
    await _scrollTo(tester, slider);
    await tester.pump();
    api.calls.clear();
    // 每次都重新量滑桿的位置（保險：版面變了也點得準）
    Offset at(double f) {
      final r = tester.getRect(slider);
      return Offset(r.left + r.width * f, r.center.dy);
    }

    await tester.tapAt(at(0.5));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(at(130 / 146));
    await tester.pump(const Duration(milliseconds: 200));
    expect(api.calls, isEmpty, reason: '還沒停 0.3 秒');
    expect(find.text(_zh.quoting), findsOneWidget);
    expect(_confirm(tester).onPressed, isNull, reason: '試算中不能賣');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(api.calls, ['quote:milk:130.0']);
    expect(tester.widget<Text>(find.byKey(const Key('est-total'))).data, _zh.costCoins(v: '1,924'));

    // ½：146 的一半是 73；全部：送原值
    await tester.tap(find.byKey(const Key('sell-chip-1')));
    await tester.pump(SellCard.debounce);
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('sell-qty'))).data, '73');
    await tester.tap(find.byKey(const Key('sell-chip-2')));
    await tester.pump(SellCard.debounce);
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('sell-qty'))).data, '146');
    expect(api.calls.last, 'quote:milk:146.0');
  });

  testWidgets('試算中、失敗時預估框維持上一次的高度，捲到最底時畫面不會跳', (tester) async {
    Screen.w390.apply(tester);
    final api = MarketApi(answers: designAnswers);
    await showMarket(tester, AppLang.zhHant, api: api);
    final box = find.byKey(const Key('estimate'));
    await _scrollTo(tester, box);
    final okHeight = tester.getSize(box).height;
    final slider = find.byKey(const Key('sell-slider'));
    final sliderTop = tester.getTopLeft(slider).dy;

    api.pending = true;
    final r = tester.getRect(slider);
    await tester.tapAt(Offset(r.left + r.width * 130 / 146, r.center.dy));
    await tester.pump(SellCard.debounce);
    await tester.pump();
    expect(find.text(_zh.quoting), findsOneWidget);
    expect(tester.getSize(box).height, okHeight);
    expect(tester.getTopLeft(slider).dy, sliderTop, reason: '內容沒有往下跳');

    api
      ..pending = false
      ..fail = true;
    await tester.tapAt(Offset(r.left + r.width * 0.5, r.center.dy));
    await tester.pump(SellCard.debounce);
    await tester.pump();
    expect(find.text(_zh.s06QuoteFailed), findsOneWidget);
    expect(tester.getSize(box).height, okHeight);
  });

  testWidgets('伺服器說一次賣太多（warn_big_order）就提醒分批；沒說就不提醒', (tester) async {
    Screen.w390.apply(tester);
    await showMarket(tester, AppLang.zhHant, commodity: Commodity.beef);
    await _scrollTo(tester, find.byKey(const Key('big-warn')));
    expect(find.text(_zh.tooMuch), findsOneWidget);
    await slideTo(tester, 236, 934);
    expect(find.byKey(const Key('big-warn')), findsNothing);
  });

  testWidgets('試算失敗：按鈕停用；按重試再問一次', (tester) async {
    Screen.w390.apply(tester);
    final api = MarketApi(answers: designAnswers)..fail = true;
    await showMarket(tester, AppLang.zhHant, api: api);
    final retry = find.byKey(const Key('quote-retry'));
    await _scrollTo(tester, retry);
    expect(find.text(_zh.s06QuoteFailed), findsOneWidget);
    expect(_confirm(tester).onPressed, isNull);
    api.fail = false;
    await tester.tap(retry);
    await tester.pump();
    await tester.pump();
    expect(find.text(_zh.s06QuoteFailed), findsNothing);
    expect(tester.widget<Text>(find.byKey(const Key('est-total'))).data, _zh.costCoins(v: '2,132'));
    expect(_confirm(tester).onPressed, isNotNull);
  });

  testWidgets('賣出：呼叫伺服器、提示成交；庫存變了重新試算剩下的', (tester) async {
    Screen.w390.apply(tester);
    final api = MarketApi(answers: designAnswers)
      ..afterSell = marketState(milk: [milkLot(16, 0, 1.0, 1)], coins: 14404);
    await showMarket(tester, AppLang.zhHant, api: api);
    await slideTo(tester, 130, 146);
    final confirm = find.byKey(const Key('sell-confirm'));
    await _scrollTo(tester, confirm);
    await tester.tap(confirm);
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(api.calls, contains('sell:milk:130.0'));
    expect(find.text(_zh.sold(qty: '130', unit: _zh.unitMilk, avg: '14.8', total: '1,924')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('sell-qty'))).data, '16');
    expect(api.calls.last, 'quote:milk:16.0');
    await tester.pump(const Duration(seconds: 3)); // 提示 2.5 秒後收起來
    expect(find.byKey(const Key('toast')), findsNothing);
  });

  testWidgets('斷線：滑桿、¼½全部、確認賣出都停用', (tester) async {
    Screen.w390.apply(tester);
    final api = MarketApi(answers: designAnswers);
    final (_, push) = await showMarket(tester, AppLang.zhHant, api: api);
    push.isConnected = false;
    await tester.pump();
    await _scrollTo(tester, find.byKey(const Key('sell-confirm')));
    expect(_confirm(tester).onPressed, isNull);
    final before = api.calls.length;
    await tester.tap(find.byKey(const Key('sell-chip-1')));
    await tester.pump(SellCard.debounce);
    expect(api.calls.length, before);
    expect(tester.widget<Text>(find.byKey(const Key('sell-qty'))).data, '146', reason: '斷線時按了不會變');
  });

  testWidgets('WebSocket 推播的新價格與新聞會顯示出來', (tester) async {
    Screen.w390.apply(tester);
    final (m, push) = await showMarket(tester, AppLang.zhHant);
    push.emit(const MarketPush({Commodity.milk: Quote(price: 9.0, change24h: -1.2, basePrice: 12)}, null));
    push.emit(NewsPush(NewsItem(id: 'n9', code: 'milk_up.2', commodity: Commodity.milk, up: true, time: m.gameNow)));
    await tester.pump(Duration.zero);
    await tester.pump();
    final milkRow = find.byKey(const Key('price-milk'));
    expect(find.descendant(of: milkRow, matching: find.textContaining('13.4', findRichText: true)), findsNothing);
    expect(find.descendant(of: milkRow, matching: find.textContaining('9', findRichText: true)), findsWidgets);
    // 9 ÷ 基本價 12 = 比平常低 25%
    expect(_vsColor(tester, 'milk'), AppColors.down(upIsRed: true));
    // v2：新聞標題由 app 用代碼查字串表（協定 3.11）
    expect(find.textContaining(kStringTables['zh-Hant']!['news.milk_up.2']!), findsWidgets);
  });

  testWidgets('牧場的大新聞「去市場看看」：到市場、選好那種商品（S03-15）', (tester) async {
    Screen.w390.apply(tester);
    final m = await ranchModel(
      api: MarketApi(
        answers: designAnswers,
        market: ranchMarket(news: [newsJson(401, 'beef_up.1', 'beef', 'up', ago: 60, pct: 0.25)]),
      ),
    );
    await pumpAppIn(tester, m, AppLang.zhHant, prefs: swipeHintSeen);
    await tester.tap(find.byKey(const Key('big-news-go')));
    await tester.pump();
    await tester.pump();
    expect(m.tab, AppTab.market);
    expect(m.marketCommodity, Commodity.beef);
    expect(find.text(_zh.s06SellTitle(name: _zh.beef)), findsOneWidget);
  });
}
