import 'package:cowfarm/state/game_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  testWidgets('圖鑑：12 格，已發現 2 格，其他顯示「？」', (tester) async {
    final (m, _, _) = await loadedModel();
    await pumpApp(tester, m);
    m.selectTab(AppTab.codex);
    await tester.pump();
    expect(find.text('已發現 2 / 12'), findsOneWidget);
    expect(find.text('？'), findsNWidgets(10));
    expect(find.text('乳用\n一般'), findsOneWidget);
    expect(find.text('兼用\n優良'), findsOneWidget);
    for (final t in ['dairy', 'dual', 'beef']) {
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(Key('codex-$t-$i')), findsOneWidget);
      }
    }
  });

  testWidgets('排行榜：三個分頁、自己的名次、電腦假玩家標「電腦」', (tester) async {
    final (m, api, _) = await loadedModel();
    await pumpApp(tester, m);
    m.selectTab(AppTab.rank);
    await tester.pump();
    await tester.pump();
    expect(find.text('總資產'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('本週收入'), findsOneWidget);
    expect(api.calls, contains('rank:networth'));
    expect(find.text('我的名次：2　31,000 幣'), findsOneWidget);
    expect(find.text('電腦 北坡牧場'), findsOneWidget);
    expect(find.text('電腦 河谷牧場'), findsOneWidget); // 已有前綴，不重複加
    expect(find.text('晨光草原牧場'), findsNWidgets(2)); // 頂列＋榜上自己

    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('rank:collection'));
    expect(find.text('我的名次：2　31,000'), findsOneWidget);
  });
}
