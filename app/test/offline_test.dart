import 'package:cowfarm/l10n/strings.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  testWidgets('斷線：頂列顯示「連線中…」，所有按鈕停用；連回來恢復', (tester) async {
    final (m, api, push) = await loadedModel(connected: false);
    await pumpApp(tester, m);

    expect(find.text(S.connecting), findsOneWidget);
    expect(find.byKey(const Key('topbar-clock')), findsNothing);
    expect(tester.widget<AppButton>(find.byKey(const Key('collect'))).onPressed, isNull);

    // 按了也不會送出
    await tester.tap(find.byKey(const Key('collect')), warnIfMissed: false);
    await tester.pump();
    expect(api.calls, isNot(contains('collect')));

    // 商店的按鈕也停用（抽牛 S19、設施 S10）
    AppButton btn(String key) => tester.widget<AppButton>(find.byKey(Key(key)));
    await tester.tap(find.byKey(const Key('tab-shop')));
    await tester.pump();
    await tester.pump();
    expect(btn('buy-C').onPressed, isNull);
    await tester.tap(find.byKey(const Key('seg-1')));
    await tester.pump();
    expect(btn('up-bucket').onPressed, isNull);

    // 連回來
    push.isConnected = true;
    await tester.pump();
    await tester.pump();
    expect(find.text(S.connecting), findsNothing);
    expect(btn('up-bucket').onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('seg-0')));
    await tester.pump();
    expect(btn('buy-C').onPressed, isNotNull);

    // 又斷線
    push.isConnected = false;
    await tester.pump();
    expect(find.text(S.connecting), findsOneWidget);
    expect(btn('buy-C').onPressed, isNull);
  });

  testWidgets('斷線時市場的賣出按鈕與牛的出貨按鈕也停用', (tester) async {
    final (m, _, _) = await loadedModel(connected: false);
    await pumpApp(tester, m);
    await tester.tap(find.byKey(const Key('pen-pill')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('cow-1')));
    await tester.pump();
    expect(tester.widget<AppButton>(find.byKey(const Key('detail-ship'))).onPressed, isNull);
    expect(tester.widget<AppButton>(find.byKey(const Key('detail-breed'))).onPressed, isNull);

    // 市場（S06）：確認賣出、¼½全部都停用
    await tester.tap(find.byKey(const Key('tab-market')));
    await tester.pump();
    await tester.pump();
    final confirm = find.byKey(const Key('sell-confirm'));
    await tester.scrollUntilVisible(confirm, 150, scrollable: find.byType(Scrollable).first);
    expect(tester.widget<AppButton>(confirm).onPressed, isNull);
    final qty = tester.widget<Text>(find.byKey(const Key('sell-qty'))).data;
    await tester.tap(find.byKey(const Key('sell-chip-1')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('sell-qty'))).data, qty, reason: '斷線時按了不會變');
  });
}
