import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/palette.dart';
import 'package:cowfarm/ui/screens/market_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Future<GameModel> _openMarket(WidgetTester tester, {FakeGameApi? api}) async {
  final (m, _, _) = await loadedModel(api: api);
  await pumpApp(tester, m);
  await tester.tap(find.byKey(const Key('tab-market')));
  await tester.pump();
  await tester.pump();
  return m;
}

Color? _color(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).style?.color;

/// 換一份行情重開市場的稻米分頁，回傳稻米漲跌的顏色。
Future<Color?> _openMarketAgain(WidgetTester tester, Map<String, dynamic> market) async {
  await _openMarket(tester, api: FakeGameApi(market: market));
  await tester.tap(find.text('稻米').first);
  await tester.pumpAndSettle();
  return _color(tester, 'change-rice');
}

void main() {
  testWidgets('漲紅跌綠：牛奶漲是紅色、牛肉跌是綠色', (tester) async {
    await _openMarket(tester);
    expect(find.byKey(const Key('price-milk')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('price-milk'))).data, '10.50');
    expect(find.text('+0.50（+5.0%）'), findsOneWidget);
    expect(_color(tester, 'change-milk'), Palette.up);
    expect(Palette.up, const Color(0xFFD32F2F)); // 紅

    await tester.tap(find.text('牛肉').first);
    await tester.pumpAndSettle();
    expect(find.text('-0.80（-6.7%）'), findsOneWidget);
    expect(_color(tester, 'change-beef'), Palette.down);
    expect(Palette.down, const Color(0xFF2E7D32)); // 綠
  });

  testWidgets('v0.2 稻米分頁：漲紅、賣出面板一樣有試算', (tester) async {
    final m = await _openMarket(tester);
    final api = m.api as FakeGameApi;
    await tester.tap(find.text('稻米').first);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('price-rice'))).data, '5.20');
    expect(_color(tester, 'change-rice'), Palette.up);
    expect(find.textContaining('颱風過境'), findsOneWidget);
    expect(find.text('庫存 20 公斤'), findsOneWidget);

    final slider = find.byKey(const Key('sell-slider-rice'));
    await tester.ensureVisible(slider);
    await tester.pump();
    final rect = tester.getRect(slider);
    await tester.tapAt(Offset(rect.right - 2, rect.center.dy));
    await tester.pump(SellPanel.debounce + const Duration(milliseconds: 50));
    await tester.pump();
    expect(api.calls, contains('quote:rice:20.0'));
    expect(find.text('${(10.0 * (1 - 0.0005 * 20)).toStringAsFixed(2)} 幣／公斤'), findsOneWidget);

    final riceDown = await _openMarketAgain(tester, sampleMarketJson(riceChange: -0.3));
    expect(riceDown, Palette.down);
  });

  testWidgets('漲跌顏色反過來也對：牛奶跌是綠色', (tester) async {
    await _openMarket(tester, api: FakeGameApi(market: sampleMarketJson(milkChange: -0.3)));
    expect(_color(tester, 'change-milk'), Palette.down);
  });

  testWidgets('新聞列表與走勢區間切換', (tester) async {
    final m = await _openMarket(tester);
    final api = m.api as FakeGameApi;
    expect(find.textContaining('學校午餐加訂鮮奶'), findsOneWidget);
    expect(api.calls, contains('history:milk:1d'));
    await tester.tap(find.byKey(const Key('range-7d')));
    await tester.pump();
    expect(api.calls, contains('history:milk:7d'));
  });

  testWidgets('賣出面板：拉滑桿後防抖動試算，顯示預估成交均價', (tester) async {
    final m = await _openMarket(tester);
    final api = m.api as FakeGameApi;
    final slider = find.byKey(const Key('sell-slider-milk'));
    await tester.ensureVisible(slider);
    await tester.pump();
    api.calls.clear();

    // 連續拉動：只在停下 300 ms 後試算一次
    final gesture = await tester.startGesture(tester.getCenter(slider) - Offset(tester.getSize(slider).width * 0.4, 0));
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(4, 0));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pump();
    expect(find.text('試算中…'), findsOneWidget);
    expect(api.calls.where((c) => c.startsWith('quote')), isEmpty);

    await tester.pump(SellPanel.debounce + const Duration(milliseconds: 50));
    await tester.pump();
    final quotes = api.calls.where((c) => c.startsWith('quote')).toList();
    expect(quotes, hasLength(1));
    final qty = double.parse(quotes.single.split(':').last);
    expect(qty, qty.roundToDouble()); // 沒拉到底時是整數
    expect(qty, greaterThan(0));
    final avg = 10.0 * (1 - 0.0005 * qty);
    expect(tester.widget<Text>(find.byKey(const Key('sell-avg-milk'))).data, '${avg.toStringAsFixed(2)} 幣／瓶');
    // 量小：沒有警告
    expect(find.byKey(const Key('sell-warn-milk')), findsNothing);
  });

  testWidgets('賣出面板：單量大時提示「一次賣太多，均價會變差」', (tester) async {
    final m = await _openMarket(tester);
    final api = m.api as FakeGameApi;
    final slider = find.byKey(const Key('sell-slider-milk'));
    await tester.ensureVisible(slider);
    await tester.pump();

    // 點滑桿最右邊 → 全部 150.5 瓶（送庫存原值，含小數）→ 均價低 7.5%
    final rect = tester.getRect(slider);
    await tester.tapAt(Offset(rect.right - 2, rect.center.dy));
    await tester.pump(SellPanel.debounce + const Duration(milliseconds: 50));
    await tester.pump();
    expect(api.calls, contains('quote:milk:150.5'));
    expect(find.text('${(10.0 * (1 - 0.0005 * 150.5)).toStringAsFixed(2)} 幣／瓶'), findsOneWidget);
    expect(find.text('數量 150.5 瓶'), findsOneWidget);
    expect(find.text('一次賣太多，均價會變差'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('sell-confirm-milk')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sell-confirm-milk')));
    await tester.pump();
    await tester.pump();
    expect(api.calls, contains('sell:milk:150.5'));
  });

  testWidgets('伺服器回 warn_big_order 就提示', (tester) async {
    final m = await _openMarket(tester, api: _WarnApi());
    final slider = find.byKey(const Key('sell-slider-milk'));
    await tester.ensureVisible(slider);
    await tester.pump();
    final rect = tester.getRect(slider);
    await tester.tapAt(Offset(rect.left + rect.width * 0.2, rect.center.dy));
    await tester.pump(SellPanel.debounce + const Duration(milliseconds: 50));
    await tester.pump();
    expect((m.api as FakeGameApi).calls.where((c) => c.startsWith('quote')), isNotEmpty);
    expect(find.text('一次賣太多，均價會變差'), findsOneWidget);
  });

  testWidgets('WebSocket 推播的新價格與新聞會顯示出來', (tester) async {
    final (m, _, push) = await loadedModel();
    await pumpApp(tester, m);
    await tester.tap(find.byKey(const Key('tab-market')));
    await tester.pump();
    push.emit(const MarketPush({Commodity.milk: Quote(price: 9.0, change24h: -1.2)}, null));
    push.emit(const NewsPush(NewsItem(id: 'n9', title: '連日高溫，冰品店大量進貨', commodity: Commodity.milk, up: true)));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('price-milk'))).data, '9.00');
    expect(tester.widget<Text>(find.byKey(const Key('change-milk'))).style?.color, Palette.down);
    expect(find.textContaining('連日高溫'), findsOneWidget);
  });
}

// 伺服器說「單量大」時，就算均價差距小也提示
class _WarnApi extends FakeGameApi {
  @override
  Future<SellQuote> sellQuote(Commodity commodity, double qty) async {
    calls.add('quote:${commodity.wire}:$qty');
    return SellQuote(qty: qty, avgPrice: 9.9, total: 9.9 * qty, marketPrice: 10, serverWarn: true);
  }
}
