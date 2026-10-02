import 'package:cowfarm/app.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// 360 dp 寬的小手機：每個分頁都畫得出來、不溢出（溢出在測試裡會丟例外）。
void main() {
  for (final tab in AppTab.values) {
    testWidgets('360 寬：${tab.name} 不溢出', (tester) async {
      final (m, _, _) = await loadedModel();
      tester.view.physicalSize = const Size(360 * 3, 740 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(CowFarmApp(model: m, settings: zhSettings()));
      m.selectTab(tab);
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      // 市場（S06）：三種商品各點一次
      if (tab == AppTab.market) {
        for (final c in ['milk', 'beef', 'rice']) {
          await tester.tap(find.byKey(Key('price-$c')));
          await tester.pump();
          await tester.pump();
          expect(tester.takeException(), isNull, reason: c);
        }
      }
      // 次分頁也看一次：配種、商店是正式畫面的分頁膠囊（seg-0、seg-1），紀錄還是 M1 的 Tab
      if (tab == AppTab.breed || tab == AppTab.shop) {
        for (final seg in ['seg-1', 'seg-0']) {
          await tester.tap(find.byKey(Key(seg)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '${tab.name} $seg');
        }
      }
      final tabs = find.byType(Tab);
      if (tab == AppTab.records) {
        expect(tabs.evaluate().length, greaterThan(1), reason: '${tab.name} 應該有次分頁');
      }
      for (var i = 0; i < tabs.evaluate().length; i++) {
        await tester.tap(tabs.at(i));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('360 寬：牛的詳細資料不溢出', (tester) async {
    final (m, _, _) = await loadedModel();
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(CowFarmApp(model: m, settings: zhSettings()));
    for (final id in ['1', '2', '3', '4', '5']) {
      m.openCow(id);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'cow $id');
    }
  });
}
