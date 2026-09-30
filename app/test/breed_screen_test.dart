import 'package:cowfarm/state/game_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

ChoiceChip _chip(WidgetTester tester, String key) => tester.widget<ChoiceChip>(find.byKey(Key(key)));

void main() {
  testWidgets('自己配種：選公牛、母牛 → 機率（稀有度、用途、公母）與免費 → 配種', (tester) async {
    final (m, api, _) = await loadedModel();
    await pumpApp(tester, m);
    m.selectTab(AppTab.breed);
    await tester.pump();

    // 小牛 #3 還沒長大，不在清單
    expect(find.byKey(const Key('dam-3')), findsNothing);
    expect(find.text('請選一頭公牛和一頭母牛'), findsOneWidget);
    expect(find.text('每頭牛一輩子只能配種一次'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sire-2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('dam-1')));
    await tester.pump();
    await tester.pump();
    expect(api.calls, contains('preview:2:1'));
    expect(find.text('56.3%'), findsOneWidget);
    expect(find.text('37.5%'), findsOneWidget);
    expect(find.text('6.3%'), findsOneWidget);
    expect(find.text('0.0%'), findsOneWidget);
    expect(find.text('小牛用途：乳牛 50.0%、耕牛 50.0%'), findsOneWidget);
    expect(find.text('公牛機率 50.0%'), findsOneWidget);
    expect(find.text('費用 免費（自己的公母）'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('breed-go')));
    await tester.tap(find.byKey(const Key('breed-go')));
    await tester.pump();
    await tester.pump();
    expect(api.calls, contains('breed:2:1'));
    expect(m.lastCalfKey, '9');
  });

  testWidgets('已配種、工作中的牛標示出來，而且不能選', (tester) async {
    final (m, _, _) = await loadedModel();
    await pumpApp(tester, m);
    m.selectTab(AppTab.breed);
    await tester.pump();
    expect(find.text('#5 乳牛 一般（已配種）'), findsOneWidget);
    expect(find.text('#4 耕牛 一般（工作中）'), findsOneWidget);
    expect(_chip(tester, 'dam-5').onSelected, isNull);
    expect(_chip(tester, 'dam-4').onSelected, isNull);
    expect(_chip(tester, 'dam-1').onSelected, isNotNull);
    // 已配種的牛就算之前被選過，也不會被當成選好
    m.setBreedDam('5');
    m.setBreedSire('2');
    await tester.pump();
    await tester.pump();
    expect(find.text('請選一頭公牛和一頭母牛'), findsOneWidget);
  });

  testWidgets('配種後顯示新小牛長大的倒數', (tester) async {
    final api = FakeGameApi();
    final (m, _, _) = await loadedModel(api: api);
    (api.stateJson['cows'] as List).add({
      'id': 9,
      'type': 'dual',
      'bull': false,
      'tier': 1,
      'stage': 'calf',
      'adult_at': t0 + 7200,
    });
    await m.refreshState();
    m.lastCalfKey = '9';
    m.selectTab(AppTab.breed);
    await pumpApp(tester, m);
    expect(find.byKey(const Key('breed-countdown')), findsOneWidget);
    // 遊戲 2 小時 ÷ 144 = 現實 50 秒
    expect(find.text('長大還要：遊戲 2 小時（現實約 50 秒）'), findsOneWidget);
  });

  testWidgets('斷線時不試算，連回來後自動補試算', (tester) async {
    final (m, api, push) = await loadedModel(connected: false);
    await pumpApp(tester, m);
    m.setBreedSire('2');
    m.setBreedDam('1');
    m.selectTab(AppTab.breed);
    await tester.pump();
    await tester.pump();
    expect(api.calls.where((c) => c.startsWith('preview')), isEmpty);
    expect(find.text('連線中…'), findsNWidgets(2)); // 頂列＋試算區

    push.isConnected = true;
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(api.calls, contains('preview:2:1'));
    expect(find.text('費用 免費（自己的公母）'), findsOneWidget);
  });
}
