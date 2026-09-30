import 'package:cowfarm/state/game_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  testWidgets('配種：選公牛、母牛 → 機率與費用 → 配種 → 倒數', (tester) async {
    final (m, api, _) = await loadedModel();
    await pumpApp(tester, m);
    m.selectTab(AppTab.breed);
    await tester.pump();

    // 小牛 #3 還沒長大，不在母牛清單
    expect(find.byKey(const Key('dam-3')), findsNothing);
    expect(find.text('請選一頭公牛和一頭母牛'), findsOneWidget);

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
    expect(find.text('費用 600 幣'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('breed-go')));
    await tester.tap(find.byKey(const Key('breed-go')));
    await tester.pump();
    await tester.pump();
    expect(api.calls, contains('breed:2:1'));
    expect(m.lastCalfKey, '9');
  });

  testWidgets('配種後顯示新小牛長大的倒數', (tester) async {
    final api = FakeGameApi();
    final (m, _, _) = await loadedModel(api: api);
    // 伺服器回的 state 裡已經有新小牛 #9
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

  testWidgets('錢不夠就不能配種', (tester) async {
    final (m, _, _) = await loadedModel(api: FakeGameApi(state: sampleStateJson(coins: 100)));
    await pumpApp(tester, m);
    m.setBreedSire('2');
    m.setBreedDam('1');
    m.selectTab(AppTab.breed);
    await tester.pump();
    await tester.pump();
    expect(find.text('金幣不夠'), findsOneWidget);
    final btn = tester.widget<FilledButton>(
      find.descendant(of: find.byKey(const Key('breed-go')), matching: find.byType(FilledButton)),
    );
    expect(btn.onPressed, isNull);
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
    expect(find.text('費用 600 幣'), findsOneWidget);
  });
}
