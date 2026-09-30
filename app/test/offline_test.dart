import 'package:cowfarm/l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

FilledButton _btn(WidgetTester tester, String key) => tester.widget<FilledButton>(
  find.descendant(of: find.byKey(Key(key)), matching: find.byType(FilledButton)),
);

void main() {
  testWidgets('斷線：頂列顯示「連線中…」，所有按鈕停用；連回來恢復', (tester) async {
    final (m, api, push) = await loadedModel(connected: false);
    await pumpApp(tester, m);

    expect(find.text(S.connecting), findsOneWidget);
    expect(find.byKey(const Key('topbar-clock')), findsNothing);
    expect(_btn(tester, 'collect').onPressed, isNull);

    // 按了也不會送出
    await tester.tap(find.byKey(const Key('collect')), warnIfMissed: false);
    await tester.pump();
    expect(api.calls, isNot(contains('collect')));

    // 商店的按鈕也停用
    await tester.tap(find.byKey(const Key('tab-shop')));
    await tester.pump();
    expect(_btn(tester, 'buy-dairy-cow').onPressed, isNull);
    expect(_btn(tester, 'up-bucket').onPressed, isNull);

    // 連回來
    push.isConnected = true;
    await tester.pump();
    await tester.pump();
    expect(find.text(S.connecting), findsNothing);
    expect(_btn(tester, 'buy-dairy-cow').onPressed, isNotNull);
    expect(_btn(tester, 'up-bucket').onPressed, isNotNull);

    // 又斷線
    push.isConnected = false;
    await tester.pump();
    expect(find.text(S.connecting), findsOneWidget);
    expect(_btn(tester, 'buy-dairy-cow').onPressed, isNull);
  });

  testWidgets('斷線時市場的賣出按鈕與牛的出貨按鈕也停用', (tester) async {
    final (m, _, _) = await loadedModel(connected: false);
    await pumpApp(tester, m);
    await tester.tap(find.byKey(const Key('cow-1')));
    await tester.pump();
    expect(_btn(tester, 'detail-ship').onPressed, isNull);
    final breedBtn = tester.widget<OutlinedButton>(
      find.descendant(of: find.byKey(const Key('detail-breed')), matching: find.byType(OutlinedButton)),
    );
    expect(breedBtn.onPressed, isNull);

    await tester.tap(find.byKey(const Key('tab-market')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('sell-confirm-milk')));
    expect(_btn(tester, 'sell-confirm-milk').onPressed, isNull);
    final slider = tester.widget<Slider>(find.byKey(const Key('sell-slider-milk')));
    expect(slider.onChanged, isNull);
  });
}
