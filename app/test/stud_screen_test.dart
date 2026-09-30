import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/screens/stud_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

FilledButton _btn(WidgetTester tester, String key) => tester.widget<FilledButton>(
  find.descendant(of: find.byKey(Key(key)), matching: find.byType(FilledButton)),
);

final _scrollable = find.descendant(of: find.byType(StudView), matching: find.byType(Scrollable)).first;

Future<void> _openStud(WidgetTester tester, GameModel m) async {
  await pumpApp(tester, m);
  m.selectTab(AppTab.breed);
  await tester.pump();
  await tester.tap(find.text('借種'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('借種（S18）：上架自己的公牛（選價位）', (tester) async {
    final (m, api, _) = await loadedModel();
    await _openStud(tester, m);
    expect(find.text('借種收入累計 1,100 幣'), findsOneWidget);
    expect(find.byKey(const Key('my-bull-2')), findsOneWidget);
    await tester.tap(find.byKey(const Key('price-2-800')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('list-2')));
    await tester.pump();
    await tester.pump();
    expect(api.calls, contains('stud-list:2:800'));
  });

  testWidgets('上架中的公牛可以下架', (tester) async {
    final (m, api, _) = await loadedModel(api: FakeGameApi(state: sampleStateJson(bullListed: true)));
    await _openStud(tester, m);
    expect(find.text('上架中：800 幣'), findsOneWidget);
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
    expect(find.text('肉牛・優良・800 幣'), findsOneWidget);
    expect(find.text('主人：電腦 公營種牛站'), findsOneWidget);
    expect(find.text('主人：電腦 北坡牧場　體重 421 公斤'), findsOneWidget);

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
    expect(find.text('費用 800 幣'), findsOneWidget);
    expect(find.text('小牛用途：耕牛 100.0%'), findsOneWidget);
    expect(find.text('75.0%'), findsOneWidget);
    expect(find.text('借種（800 幣）'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('stud-borrow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('stud-borrow')));
    await tester.pump();
    await tester.pump();
    expect(api.calls, contains('stud-borrow:5:1'));
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
    push.emit(const StudPush(event: 'borrowed', listingId: 9, cowId: 2, price: 800));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('notice')), findsOneWidget);
    expect(find.text('有人借了你的公牛，收到 800 幣'), findsOneWidget);
    expect(api.calls, contains('state'));
  });
}
