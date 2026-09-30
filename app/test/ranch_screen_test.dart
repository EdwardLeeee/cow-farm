import 'package:cowfarm/l10n/strings.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  testWidgets('牧場：頂列、奶桶、倉庫、牛的卡片', (tester) async {
    final (m, _, _) = await loadedModel();
    await pumpApp(tester, m);

    expect(find.text('晨光草原牧場'), findsOneWidget);
    expect(find.text('Lv 3'), findsOneWidget);
    expect(find.text('金幣 1,500'), findsOneWidget);
    expect(find.text('遊戲時間 10/1 12:00 ・ 倍率 ×144'), findsOneWidget);
    expect(find.text('6.0 / 24 瓶'), findsOneWidget);
    expect(find.text('每小時 12.0 瓶'), findsOneWidget);
    expect(find.text('牛奶 150.5 / 150 瓶（2 批）'), findsOneWidget);
    expect(find.text('牛肉 300.0 公斤（1 批）'), findsOneWidget);
    expect(find.byKey(const Key('cow-1')), findsOneWidget);
    expect(find.byKey(const Key('cow-2')), findsOneWidget);
    expect(find.byKey(const Key('cow-3')), findsOneWidget);
    expect(find.textContaining('乳用・母・成年'), findsOneWidget);
    expect(find.textContaining('兼用・公・成年'), findsOneWidget);
    expect(find.textContaining('肉用・母・小牛'), findsOneWidget);
    expect(find.textContaining('產奶 11.0 瓶／時'), findsOneWidget);
  });

  testWidgets('收奶：呼叫伺服器、顯示結果、再拿一次 state 校正', (tester) async {
    final (m, api, _) = await loadedModel();
    await pumpApp(tester, m);
    api.calls.clear();

    await tester.tap(find.byKey(const Key('collect')));
    await tester.pump();
    await tester.pump();
    expect(api.calls, ['collect', 'state']);
    expect(find.text(S.collected('6.0')), findsOneWidget);
  });

  testWidgets('奶桶依伺服器產量與倍率平滑增加，滿了就停', (tester) async {
    final clock = FakeClock();
    final (m, _, _) = await loadedModel(clock: clock);
    await pumpApp(tester, m);
    expect(m.bucketNow, closeTo(6.0, 1e-9));

    // 現實 10 秒 × 倍率 144 = 遊戲 0.4 小時 → 多 4.8 瓶
    clock.t += 10;
    expect(m.bucketNow, closeTo(10.8, 1e-9));
    expect(m.gameNow, closeTo(t0 + 1440, 1e-6));
    m.selectTab(AppTab.ranch); // 觸發重畫
    await tester.pump();
    expect(find.text('10.8 / 24 瓶'), findsOneWidget);

    // 很久之後：上限是容量 24
    clock.t += 1000;
    expect(m.bucketNow, 24.0);
  });

  testWidgets('牛的詳細資料：出貨前先顯示估值，確定後才出貨', (tester) async {
    final (m, api, _) = await loadedModel();
    await pumpApp(tester, m);

    await tester.tap(find.byKey(const Key('cow-1')));
    await tester.pump();
    expect(find.text('出貨估值 約 1,440 幣'), findsOneWidget);

    await tester.tap(find.byKey(const Key('detail-ship')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('ship-confirm-body')), findsOneWidget);
    expect(find.textContaining('估值約 1,440 幣'), findsOneWidget);
    expect(api.calls.where((c) => c.startsWith('ship')), isEmpty);

    await tester.tap(find.byKey(const Key('ship-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(api.calls, contains('ship:1'));
    expect(m.detailCowKey, isNull);
  });

  testWidgets('小牛不能出貨', (tester) async {
    final (m, _, _) = await loadedModel();
    await pumpApp(tester, m);
    await tester.tap(find.byKey(const Key('cow-3')));
    await tester.pump();
    final btn = tester.widget<FilledButton>(
      find.descendant(of: find.byKey(const Key('detail-ship')), matching: find.byType(FilledButton)),
    );
    expect(btn.onPressed, isNull);
    expect(find.text(S.shipNotAdult), findsOneWidget);
    expect(find.byKey(const Key('detail-grow')), findsOneWidget);
  });

  testWidgets('「選這頭去配種」切到配種頁並選好', (tester) async {
    final (m, _, _) = await loadedModel();
    await pumpApp(tester, m);
    await tester.tap(find.byKey(const Key('cow-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('detail-breed')));
    await tester.pump();
    expect(m.tab, AppTab.breed);
    expect(m.breedDamKey, '1');
    expect(find.text(S.pickSire), findsOneWidget);
  });
}
