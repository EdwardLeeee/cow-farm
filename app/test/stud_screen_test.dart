import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/screens/stud_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

FilledButton _btn(WidgetTester tester, String key) =>
    tester.widget<FilledButton>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(FilledButton)));

final _scrollable = find.descendant(of: find.byType(StudView), matching: find.byType(Scrollable)).first;

Future<void> _openStud(WidgetTester tester, GameModel m) async {
  await pumpApp(tester, m);
  m.selectTab(AppTab.breed);
  await tester.pump();
  await tester.tap(find.text('借種'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('借種（S18）：上架自己的公牛，借種費由系統算（D26）', (tester) async {
    final (m, api, _) = await loadedModel();
    await _openStud(tester, m);
    expect(find.text('借種收入累計 1,100 幣'), findsOneWidget);
    expect(find.byKey(const Key('my-bull-2')), findsOneWidget);
    // #2 公耕牛 200 公斤 × 1.1，四捨五入到 10 幣（假資料照 D26 的公式）
    expect(tester.widget<Text>(find.byKey(const Key('fee-2'))).data, '220 幣');
    await tester.tap(find.byKey(const Key('list-2')));
    await tester.pump();
    await tester.pump();
    expect(api.calls, contains('stud-list:2'));
  });

  testWidgets('上架中的公牛可以下架', (tester) async {
    final (m, api, _) = await loadedModel(api: FakeGameApi(state: sampleStateJson(bullListed: true)));
    await _openStud(tester, m);
    expect(find.text('上架中：550 幣'), findsOneWidget);
    await tester.tap(find.byKey(const Key('unlist-2')));
    await tester.pump();
    await tester.pump();
    expect(api.calls, contains('stud-unlist:9'));
  });

  testWidgets('瀏覽別人的公牛 → 選自己的母牛 → 預覽機率與費用 → 借種', (tester) async {
    final (m, api, _) = await loadedModel();
    await _openStud(tester, m);
    expect(api.calls, contains('stud'));
    expect(find.text('乳牛・一般・300 幣'), findsOneWidget);
    expect(find.text('肉牛・優良・1,160 幣'), findsOneWidget);
    // v2：電腦牧場名由 app 用詞庫編號組（協定 1.6），公營種牛站也是電腦牧場
    final zh = Strings.forLang(AppLang.zhHant);
    expect(find.text('主人：電腦 ${zh.ranchNameFromWords([3, 5, 0])}　體重 275 公斤'), findsOneWidget);
    expect(find.text('主人：電腦 ${zh.ranchNameFromWords([8, 0, 5])}　體重 421 公斤'), findsOneWidget);

    await tester.tap(find.byKey(const Key('stud-listing-5')));
    await tester.pump();
    await tester.scrollUntilVisible(find.byKey(const Key('stud-dam-1')), 200, scrollable: _scrollable);
    // 已配種的 #5 不能選
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('stud-dam-5'))).onSelected, isNull);
    await tester.tap(find.byKey(const Key('stud-dam-1')));
    await tester.pump();
    await tester.pump();
    expect(api.calls, contains('stud-preview:5:1'));
    await tester.scrollUntilVisible(find.byKey(const Key('stud-borrow')), 200, scrollable: _scrollable);
    expect(find.text('費用 1,160 幣'), findsOneWidget);
    expect(find.text('小牛用途：耕牛 100.0%'), findsOneWidget);
    expect(find.text('75.0%'), findsOneWidget);
    expect(find.text('借種（1,160 幣）'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('stud-borrow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('stud-borrow')));
    await tester.pump();
    await tester.pump();
    expect(api.calls, contains('stud-borrow:5:1:1160'), reason: '借種帶預覽看到的價格（協定 4.4）');
    expect(m.lastCalfKey, '10');
  });

  testWidgets('錢不夠就不能借', (tester) async {
    final (m, _, _) = await loadedModel(api: FakeGameApi(state: sampleStateJson(coins: 500)));
    await _openStud(tester, m);
    await tester.tap(find.byKey(const Key('stud-listing-5')));
    await tester.pump();
    await tester.scrollUntilVisible(find.byKey(const Key('stud-dam-1')), 200, scrollable: _scrollable);
    await tester.tap(find.byKey(const Key('stud-dam-1')));
    await tester.pump();
    await tester.pump();
    await tester.scrollUntilVisible(find.byKey(const Key('stud-borrow')), 200, scrollable: _scrollable);
    expect(find.text('金幣不夠'), findsOneWidget);
    expect(_btn(tester, 'stud-borrow').onPressed, isNull);
  });

  testWidgets('公牛被借走時，WebSocket 通知顯示一則提示並重抓 state', (tester) async {
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
    final zh = Strings.forLang(AppLang.zhHant);
    final text = zh.gStudNoticeBody(
      cow: zh.cowName('highland', 2),
      ranch: '${zh.botPrefix} ${zh.ranchNameFromWords([0, 1, 0])}',
      price: '550',
    );
    expect(find.text(text), findsOneWidget);
    expect(api.calls, contains('state'));
  });
}
