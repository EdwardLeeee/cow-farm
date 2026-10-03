// D33 新聞分級：tier 的讀法（伺服器還沒送 tier 時照 big）、什麼時候釘在最上面、市場新聞卡（最多三則、進行中的超級事件
// 釘在最上面、結束的回到清單、標籤）、牧場頁的超級事件提示（標籤、✕ 的範圍）、深色卡上跌的顏色。
// 畫面本身在 test/pages/s03_cases.dart（S03-22～24）、s06_cases.dart（S06-14、S06-17）。
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/ui/market/market_page.dart';
import 'package:cowfarm/ui/market/news_tier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'pages/page_case.dart';
import 'pages/s03_cases.dart';
import 'pages/s06_cases.dart';

final _zh = Strings.forLang(AppLang.zhHant);

NewsItem _news(Map<String, dynamic> extra, {int id = 1}) =>
    NewsItem.fromJson({...newsJson(id, 'milk_up.1', 'milk', 'up', ago: 60), ...extra});

void main() {
  group('tier', () {
    test('讀 tier；伺服器還沒送 tier（#115 合併前）時照 big 分一般、大新聞；不認得的也照 big', () {
      expect(_news({'big': false}).tier, NewsTier.normal);
      expect(_news({'big': true}).tier, NewsTier.big);
      expect(_news({'tier': 'normal'}).tier, NewsTier.normal);
      expect(_news({'tier': 'big', 'big': true}).tier, NewsTier.big);
      expect(_news({'tier': 'super', 'big': true}).tier, NewsTier.superUp);
      expect(_news({'tier': 'crash', 'big': true}).tier, NewsTier.crash);
      expect(_news({'tier': 'mega', 'big': true}).tier, NewsTier.big);
      expect(_news({'state': 'ended'}).ended, isTrue);
      expect(_news({'state': 'active'}).ended, isFalse);
    });

    test('釘在最上面：進行中的超級大事件、超級黑天鵝；結束（state ended、或過了 end_at）、一般和大新聞都不釘', () {
      final end = t0 + 7200;
      expect(_news({'tier': 'super', 'end_at': end}).pinnedAt(t0), isTrue);
      expect(_news({'tier': 'crash', 'end_at': end}).pinnedAt(t0), isTrue);
      expect(_news({'tier': 'super', 'end_at': end, 'state': 'ended'}).pinnedAt(t0), isFalse);
      expect(_news({'tier': 'super', 'end_at': end}).pinnedAt(end), isFalse, reason: '還沒重新讀市場，但已經過了 end_at');
      expect(_news({'tier': 'big', 'big': true}).pinnedAt(t0), isFalse);
      expect(_news({'tier': 'normal'}).pinnedAt(t0), isFalse);
    });
  });

  group('市場的新聞卡', () {
    setUpAll(loadAppAssets);

    Future<void> show(WidgetTester tester, List<Map<String, dynamic>> news) async {
      Screen.w430.apply(tester);
      final m = await ranchModel(market: ranchMarket(beef: 24));
      await pumpSheet(tester, AppLang.zhHant, [NewsCard(items: news.map(NewsItem.fromJson).toList())], model: m);
    }

    testWidgets('清單最多 3 則最新的；進行中的超級事件釘在最上面、不算在 3 則裡；結束的回到清單、照時間排', (tester) async {
      await show(tester, [
        newsJson(1, 'beef_super.1', 'beef', 'up', ago: 60, pct: 1, tier: 'super'),
        newsJson(2, 'milk_up.1', 'milk', 'up', ago: 120),
        newsJson(3, 'all_swan.1', null, 'down', ago: 180, pct: 0.9, tier: 'crash'),
        newsJson(4, 'all_down.2', null, 'down', ago: 240),
        newsJson(5, 'rice_super.1', 'rice', 'up', ago: 300, pct: 1, tier: 'super', state: 'ended'),
        newsJson(6, 'rice_up.1', 'rice', 'up', ago: 360),
        newsJson(7, 'beef_up.3', 'beef', 'up', ago: 420),
      ]);
      expect(find.byType(NewsPinCard), findsNWidgets(2));
      // 大卡照時間排（新的在上），在清單上面
      final pin1 = tester.getRect(find.byKey(const Key('news-pin-1')));
      final pin3 = tester.getRect(find.byKey(const Key('news-pin-3')));
      expect(pin1.top, lessThan(pin3.top));
      // 清單：牛奶利多、全部利空、結束的稻米超級大事件；第 4 則以後（稻米利多、牛肉利多）不放
      expect(find.text(_zh.newsHeadline(_news({'code': 'milk_up.1'}))), findsOneWidget);
      expect(find.text(_zh.newsHeadline(_news({'code': 'rice_super.1'}))), findsOneWidget);
      expect(find.text(_zh.newsHeadline(_news({'code': 'rice_up.1'}))), findsNothing);
      expect(find.text(_zh.newsHeadline(_news({'code': 'beef_up.3'}))), findsNothing);
      final ended = tester.getRect(find.text(_zh.newsHeadline(_news({'code': 'rice_super.1'}))));
      expect(ended.top, greaterThan(pin3.bottom));
    });

    testWidgets('標籤：大新聞只給 big；超級事件的 big 也是 true，只放級別（結束的回到清單也一樣）', (tester) async {
      await show(tester, [
        newsJson(1, 'beef_up.1', 'beef', 'up', ago: 60, pct: 0.3, tier: 'big'),
        newsJson(2, 'rice_super.1', 'rice', 'up', ago: 120, pct: 1, tier: 'super', state: 'ended'),
        newsJson(3, 'milk_up.1', 'milk', 'up', ago: 180),
      ]);
      expect(find.text(_zh.s06BigNews), findsOneWidget);
      expect(find.byKey(const Key('tier-super')), findsOneWidget);
      expect(find.byType(NewsPinCard), findsNothing);
    });

    testWidgets('都沒有新聞：寫「目前沒有新聞」；只有釘住的大卡時不寫', (tester) async {
      await show(tester, []);
      expect(find.text(_zh.noNews), findsOneWidget);
      await show(tester, [newsJson(1, 'beef_super.1', 'beef', 'up', ago: 60, pct: 1, tier: 'super')]);
      expect(find.byType(NewsPinCard), findsOneWidget);
      expect(find.text(_zh.noNews), findsNothing);
    });
  });

  group('牧場頁的提示', () {
    setUpAll(loadAppAssets);

    testWidgets('超級黑天鵝：標籤換成級別、沒有「大新聞」；✕ 點得到的範圍 44 × 44 四個角都點得到，按了收起來', (tester) async {
      Screen.w430.apply(tester);
      final m = await ranchModel(
        market: ranchMarket(
          milk: 1.2,
          news: [newsJson(9, 'milk_swan.1', 'milk', 'down', ago: 60, pct: 0.9, tier: 'crash')],
        ),
      );
      await pumpAppIn(tester, m, AppLang.zhHant, prefs: swipeHintSeen);
      expect(find.byKey(const Key('big-news')), findsOneWidget);
      expect(find.byKey(const Key('tier-crash')), findsOneWidget);
      expect(find.text(_zh.s06BigNews), findsNothing);
      final close = find.byKey(const Key('big-news-close'));
      final r = tester.getRect(close);
      expect(r.size, const Size(44, 44));
      final target = tester.renderObject(close);
      for (final p in [
        r.topLeft + const Offset(0.5, 0.5),
        r.topRight + const Offset(-0.5, 0.5),
        r.bottomLeft + const Offset(0.5, -0.5),
        r.bottomRight + const Offset(-0.5, -0.5),
      ]) {
        expect(tester.hitTestOnBinding(p).path.any((e) => e.target == target), isTrue, reason: '$p');
      }
      await tester.tapAt(r.topRight + const Offset(-1, 1));
      await tester.pump();
      expect(find.byKey(const Key('big-news')), findsNothing);
    });

    test('深色卡上的跌：漲紅跌綠是設計稿的淺綠；綠漲紅跌（設計稿沒畫）換成一樣亮的淺紅', () {
      expect(crashPctColor(upIsRed: true), const Color(0xFF7BE0A6));
      expect(crashPctColor(upIsRed: false), const Color(0xFFEF8F93));
    });
  });
}
