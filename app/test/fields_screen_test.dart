import 'package:cowfarm/state/game_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

FilledButton _btn(WidgetTester tester, String key) => tester.widget<FilledButton>(
  find.descendant(of: find.byKey(Key(key)), matching: find.byType(FilledButton)),
);

OutlinedButton _outlined(WidgetTester tester, String key) => tester.widget<OutlinedButton>(
  find.descendant(of: find.byKey(Key(key)), matching: find.byType(OutlinedButton)),
);

Future<(GameModel, FakeGameApi)> _open(WidgetTester tester, {FakeClock? clock, FakeGameApi? api}) async {
  final (m, a, _) = await loadedModel(clock: clock, api: api);
  await pumpApp(tester, m);
  m.selectTab(AppTab.fields);
  await tester.pump();
  return (m, a);
}

void main() {
  testWidgets('田地（S17）：清單、稻米進度、收成、開新田', (tester) async {
    final (_, api) = await _open(tester);
    expect(find.text('田地 2 / 12 塊'), findsOneWidget);
    expect(find.text('倉庫稻米 20.0 公斤　全部田地每小時 11.0 公斤'), findsOneWidget);
    expect(find.text('第 1 塊田　耕牛 #4 工作中'), findsOneWidget);
    expect(find.text('第 2 塊田　空田'), findsOneWidget);
    expect(find.text('稻米 33.0 / 88 公斤'), findsOneWidget);
    expect(find.text('收成（田裡約 33.0 公斤）'), findsOneWidget);

    await tester.tap(find.byKey(const Key('harvest')));
    await tester.pump();
    await tester.pump();
    expect(api.calls, contains('field-harvest'));
    expect(find.text('收成了 33.0 公斤稻米'), findsOneWidget);

    // 開新田 2,880 幣 > 金幣 1,500
    expect(find.text('開新田（2,880 幣）'), findsOneWidget);
    expect(_outlined(tester, 'field-expand').onPressed, isNull);
  });

  testWidgets('稻米依產量與倍率平滑增加，長滿就停', (tester) async {
    final clock = FakeClock();
    final (m, _) = await _open(tester, clock: clock);
    final f = m.state!.fields.first;
    clock.t += 25; // 遊戲 1 小時 → +11 公斤
    expect(m.fieldRiceNow(f), closeTo(44, 1e-9));
    clock.t += 1000;
    expect(m.fieldRiceNow(f), 88);
  });

  testWidgets('派耕牛下田（空田）與叫回', (tester) async {
    final api = FakeGameApi();
    // 讓 #2 公耕牛可以下田（預設就是成年、沒上架、不在田裡）
    final (_, a) = await _open(tester, api: api);
    await tester.tap(find.byKey(const Key('field-assign-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('選一頭耕牛下田'), findsOneWidget);
    // 只有能下田的耕牛：#2（#4 已經在田裡）
    expect(find.byKey(const Key('pick-ox-2')), findsOneWidget);
    expect(find.byKey(const Key('pick-ox-4')), findsNothing);
    await tester.tap(find.byKey(const Key('pick-ox-2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(a.calls, contains('field-assign:2:1'));

    await tester.tap(find.byKey(const Key('field-recall-0')));
    await tester.pump();
    await tester.pump();
    expect(a.calls, contains('field-recall:4'));
  });

  testWidgets('錢夠就能開新田', (tester) async {
    final (_, api) = await _open(tester, api: FakeGameApi(state: sampleStateJson(coins: 5000)));
    await tester.ensureVisible(find.byKey(const Key('field-expand')));
    expect(_outlined(tester, 'field-expand').onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('field-expand')));
    await tester.pump();
    await tester.pump();
    expect(api.calls, contains('field-expand'));
    expect(_btn(tester, 'harvest').onPressed, isNotNull);
  });
}
