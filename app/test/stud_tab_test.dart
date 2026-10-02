// S18 借種市場（正式畫面）：上架、下架、選公牛和母牛、借種、對話框（借不到、借種費變了）、錢不夠、借種紀錄、通知。
// 畫面狀態本身（S18-01～15）在 test/pages/s18_cases.dart。
import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/ui/breed/breed_page.dart';
import 'package:cowfarm/ui/breed/stud_log_page.dart';
import 'package:cowfarm/ui/breed/stud_tab.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'pages/page_case.dart';
import 'pages/s18_cases.dart';

final _zh = Strings.forLang(AppLang.zhHant);

AppButton _btn(WidgetTester tester, String key) => tester.widget<AppButton>(find.byKey(Key(key)));

void main() {
  setUpAll(loadAppAssets);

  testWidgets('我的公牛：上架、下架都問伺服器；市場不放自己上架的', (tester) async {
    Screen.w430.apply(tester);
    final api = StudApi();
    await showStud(tester, AppLang.zhHant, api: api);
    expect(api.calls, contains('stud'));
    expect(find.byKey(const Key('stud-listing-7')), findsNothing);
    await tester.tap(find.byKey(const Key('list-14')));
    await tester.pump();
    expect(api.calls, contains('stud-list:14'));
    await tester.tap(find.byKey(const Key('unlist-5')));
    await tester.pump();
    expect(api.calls, contains('stud-unlist:7'));
  });

  testWidgets('選公牛 → 選母牛 → 機率和借種費 → 借種：按鈕換成「已借種」、新小牛、提示付了多少', (tester) async {
    Screen.w430.apply(tester);
    final api = StudApi()..after = borrowedState();
    final m = await showStud(tester, AppLang.zhHant, api: api, listing: '43');
    // 還沒選母牛：機率卡寫「先選…」，借種鈕停用
    await tester.scrollUntilVisible(find.byKey(const Key('outcome')), 200, scrollable: studScrollable);
    expect(find.text(_zh.pickListing), findsOneWidget);
    expect(_btn(tester, 'stud-borrow').onPressed, isNull);

    await tapStud(tester, find.byKey(const Key('stud-dam-3')));
    await tester.pump();
    expect(api.calls, contains('stud-preview:43:3'));
    await tester.scrollUntilVisible(find.byKey(const Key('stud-borrow')), 200, scrollable: studScrollable);
    expect(_btn(tester, 'stud-borrow').label, _zh.borrow(price: '1,820'));

    await tapBorrow(tester);
    expect(api.calls, contains('stud-borrow:43:3:1820'), reason: '借種帶預覽看到的價格（協定 4.4）');
    expect(_btn(tester, 'stud-borrow').label, _zh.s18BorrowedBtn);
    expect(_btn(tester, 'stud-borrow').onPressed, isNull);
    expect(find.byType(CalfCard), findsOneWidget);
    expect(find.text(_zh.borrowed(price: '1,820')), findsOneWidget);
    expect(m.state!.coins, 12480 - 1820);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('新小牛剛好把牛舍佔滿：「已借種」下面不放「牛舍滿了」；換選別的才照常提醒（ceo 2026-10-02）', (tester) async {
    Screen.w430.apply(tester);
    // 10 頭牛、11 格：借之前還有一格，借到以後滿了
    final api = StudApi(state: studState(penSlots: 11))..after = borrowedState(penSlots: 11);
    await showStud(tester, AppLang.zhHant, api: api, listing: '43', dam: '3');
    await tester.scrollUntilVisible(find.byKey(const Key('stud-borrow')), 200, scrollable: studScrollable);
    expect(find.text(_zh.s08PenFull), findsNothing);

    await tapBorrow(tester);
    expect(_btn(tester, 'stud-borrow').label, _zh.s18BorrowedBtn);
    expect(find.byType(CalfCard), findsOneWidget);
    expect(find.text(_zh.s08PenFull), findsNothing);

    // 換選別的公牛（在上面，往回捲）
    final other = find.byKey(const Key('stud-listing-41'));
    await tester.scrollUntilVisible(other, -200, scrollable: studScrollable);
    await tester.ensureVisible(other);
    await tester.pump();
    await tester.tap(other);
    await tester.pump();
    await tester.pump();
    await tester.scrollUntilVisible(find.byKey(const Key('stud-borrow')), 200, scrollable: studScrollable);
    expect(find.text(_zh.s08PenFull), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('借到以後下拉重新整理：借走的那頭已經不在市場上，下面的機率、「已借種」、新小牛照樣留著', (tester) async {
    Screen.w430.apply(tester);
    final api = StudApi()..after = borrowedState();
    await showStud(tester, AppLang.zhHant, api: api, listing: '43', dam: '3');
    await tapBorrow(tester);
    expect(find.byType(CalfCard), findsOneWidget);

    api.studListings.removeWhere((l) => l['id'] == 43);
    api.calls.clear();
    // 下拉重新整理（RefreshIndicator 的動畫要一直 pump，不能 pumpAndSettle）
    final refreshed = tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    await refreshed;
    expect(api.calls, contains('stud'));
    expect(find.byKey(const Key('stud-listing-43')), findsNothing, reason: '市場照伺服器的');
    await tester.scrollUntilVisible(find.byType(CalfCard), 200, scrollable: studScrollable);
    expect(find.byType(CalfCard), findsOneWidget);
    expect(_btn(tester, 'stud-borrow').label, _zh.s18BorrowedBtn);
    expect(find.byKey(const Key('outcome')), findsOneWidget);
  });

  testWidgets('借種費變了（S18-12）：按「用新價格借」用新的價格重送；取消就不借', (tester) async {
    Screen.w430.apply(tester);
    final api = StudApi()
      ..borrowError = const ApiException(409, 'price_changed', 'changed', {'price': 1090, 'expected': 1050});
    await showStud(tester, AppLang.zhHant, api: api, listing: '44', dam: '3');
    await tapBorrow(tester);
    expect(find.text(_zh.s18FeeChangedTitle), findsOneWidget);
    await tester.tap(find.byKey(const Key('fee-changed-borrow')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.calls, contains('stud-borrow:44:3:1090'));
    expect(_btn(tester, 'stud-borrow').label, _zh.s18BorrowedBtn);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('借不到了（S18-10）：按「重新整理市場」重抓、取消選擇', (tester) async {
    Screen.w430.apply(tester);
    final api = StudApi()..borrowError = const ApiException(404, 'listing_not_found', 'gone');
    await showStud(tester, AppLang.zhHant, api: api, listing: '43', dam: '3');
    await tapBorrow(tester);
    expect(find.text(_zh.s18GoneTitle), findsOneWidget);
    api.calls.clear();
    await tester.tap(find.byKey(const Key('gone-reload')));
    await tester.pump();
    await tester.pump();
    expect(api.calls, contains('stud'));
    expect(find.byKey(const Key('stud-borrow')), findsNothing, reason: '選擇取消了');
  });

  testWidgets('預覽說借不到了（listing_gone）：一樣跳對話框', (tester) async {
    Screen.w430.apply(tester);
    final api = StudApi()
      ..blockers = [
        {'code': 'listing_gone'},
      ];
    await showStud(tester, AppLang.zhHant, api: api, listing: '43', dam: '3');
    await tester.pump();
    expect(find.text(_zh.s18GoneTitle), findsOneWidget);
  });

  testWidgets('錢不夠（S18-08）：還沒預覽就先寫還差多少、借種鈕停用', (tester) async {
    Screen.w430.apply(tester);
    final api = StudApi(state: studState(coins: 300));
    await showStud(tester, AppLang.zhHant, api: api, listing: '43', dam: '3');
    await tester.scrollUntilVisible(find.byKey(const Key('stud-borrow')), 200, scrollable: studScrollable);
    expect(find.text(_zh.notEnoughCoins(n: '1,520')), findsOneWidget);
    expect(_btn(tester, 'stud-borrow').onPressed, isNull);
  });

  testWidgets('市場載入失敗：按「重新整理」再抓', (tester) async {
    Screen.w430.apply(tester);
    final api = StudApi()..marketFail = true;
    await showStud(tester, AppLang.zhHant, api: api);
    await tester.scrollUntilVisible(find.byKey(const Key('market-failed')), 200, scrollable: studScrollable);
    api.marketFail = false;
    await tester.tap(find.byKey(const Key('market-reload')));
    await tester.pump();
    await tester.pump();
    expect(find.byType(StudRow), findsWidgets);
  });

  testWidgets('借種紀錄（S18-11）：篩選借出、借入；空的寫「還沒有…」；返回關掉', (tester) async {
    Screen.w430.apply(tester);
    final api = StudApi();
    final m = await showStud(tester, AppLang.zhHant, api: api);
    await tapStud(tester, find.byKey(const Key('stud-log-link')));
    await tester.pump();
    expect(m.studLogOpen, isTrue);
    expect(api.calls, contains('stud-log'));
    expect(find.byType(StudLogRow), findsNWidgets(4));
    await tester.tap(find.byKey(const Key('filter-1')));
    await tester.pump();
    expect(find.byType(StudLogRow), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('filter-2')));
    await tester.pump();
    expect(find.byType(StudLogRow), findsNWidgets(2));
    // 日期照伺服器的現實時間（今天、昨天、9 月 29 日）
    expect(find.textContaining(_zh.dateTime(yesterday: true, time: '21:40')), findsOneWidget);

    api.studLogJson = {'keep_days': 30, 'income_total': 0, 'entries': []};
    await tester.tap(find.byKey(const Key('btn-back')));
    await tester.pump();
    expect(m.studLogOpen, isFalse);
    await tapStud(tester, find.byKey(const Key('stud-log-link')));
    await tester.pump();
    expect(find.text(_zh.s18LogEmpty), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-1')));
    await tester.pump();
    expect(find.text(_zh.s18LogEmptyOut), findsOneWidget);
  });

  testWidgets('借種紀錄的名字：真人「名字 #編號」、電腦「電腦 名字」、刪掉的「已刪除的牧場」；牛名不加「公牛」', (tester) async {
    expect(logRanchText(_zh, RanchRef.fromJson(ranchJson(id: 3310, name: '星河松林牧舍'))), '星河松林牧舍 #3310');
    expect(
      logRanchText(_zh, RanchRef.fromJson(ranchJson(words: [9, 9, 2]))),
      '${_zh.botPrefix} ${_zh.ranchNameFromWords([9, 9, 2])}',
    );
    expect(logRanchText(_zh, null), _zh.s18DeletedRanch);
    expect(logCowText(_zh, 'holstein', 8), _zh.cowName('holstein', 8));
    expect(logCowText(_zh, 'chocolate', null), _zh.breedName('chocolate'));
  });

  for (final (lang, gap) in [(AppLang.zhHant, ''), (AppLang.en, ' '), (AppLang.th, ' ')]) {
    testWidgets('市場的公牛名（${lang.code}）：品種名和「公」${gap.isEmpty ? '連著寫' : '中間空一格'}（ceo 2026-10-02）', (tester) async {
      Screen.w430.apply(tester);
      final s = Strings.forLang(lang);
      await showStud(tester, lang);
      final row = find.byKey(const Key('stud-listing-41'));
      await tester.scrollUntilVisible(row, 200, scrollable: studScrollable);
      final name = '${s.breedName('holstein')}$gap${s.bull}';
      expect(find.descendant(of: row, matching: find.text(name, findRichText: true)), findsOneWidget);
    });
  }

  testWidgets('可點的元件無障礙只讀自己的字：借種紀錄連結、上架鈕、市場的一列都不把旁邊的字併進來（8790 走查）', (tester) async {
    Screen.w430.apply(tester);
    final semantics = tester.ensureSemantics();
    await showStud(tester, AppLang.zhHant);
    expect(
      tester.getSemantics(find.byKey(const Key('stud-log-link'))),
      isSemantics(label: _zh.s18LogTitle, isButton: true),
    );
    expect(tester.getSemantics(find.byKey(const Key('list-14'))), isSemantics(label: _zh.list, isButton: true));
    expect(tester.getSemantics(find.byKey(const Key('stud-listing-41'))).label, startsWith(_zh.breedName('holstein')));
    semantics.dispose();
  });

  testWidgets('借種紀錄的返回鈕：無障礙只讀「返回」，標題不併進按鈕（walk.cjs 在 8790 看到併成一顆）', (tester) async {
    Screen.w430.apply(tester);
    final semantics = tester.ensureSemantics();
    await showStud(tester, AppLang.zhHant);
    await tapStud(tester, find.byKey(const Key('stud-log-link')));
    await tester.pump();
    expect(
      tester.getSemantics(find.byKey(const Key('btn-back'))),
      isSemantics(label: _zh.back, isButton: true, hasTapAction: true),
    );
    // 標題和下面的小字是另一個節點（不能點）
    expect(find.bySemanticsLabel(RegExp('^${_zh.s18LogTitle}\n')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('公牛被借走時，WebSocket 通知顯示一則提示並重抓 state（G-05）', (tester) async {
    final (m, api, push) = await loadedModel();
    await pumpApp(tester, m);
    api.calls.clear();
    push.emit(
      StudPush(
        event: 'borrowed',
        listingId: 9,
        cowId: 2,
        breed: 'highland',
        price: 550,
        borrower: RanchRef.fromJson({
          'player_id': 12,
          'name_words': [0, 1, 0],
          'is_bot': true,
          'level': 4,
        }),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('notice')), findsOneWidget);
    // G-05「{cow} 借給 {ranch}，收到 {price} 幣」
    final text = _zh.gStudNoticeBody(
      cow: _zh.cowName('highland', 2),
      ranch: '${_zh.botPrefix} ${_zh.ranchNameFromWords([0, 1, 0])}',
      price: '550',
    );
    expect(find.text(text), findsOneWidget);
    expect(api.calls, contains('state'));
  });
}
