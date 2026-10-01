import 'package:cowfarm/api/breeds.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  testWidgets('圖鑑：24 個品種，已發現 2 種，其他顯示「？」（協定 2.3）', (tester) async {
    final (m, _, _) = await loadedModel();
    await pumpApp(tester, m);
    m.selectTab(AppTab.records);
    await tester.pump();
    expect(find.text('已發現 2 / 24'), findsOneWidget);
    expect(find.text('？'), findsNWidgets(22));
    final zh = Strings.forLang(AppLang.zhHant);
    expect(find.text('${zh.breedName('holstein')}\n一般'), findsOneWidget);
    expect(find.text('${zh.breedName('highland')}\n優良'), findsOneWidget);
    for (final breed in kCodexOrder) {
      expect(find.byKey(Key('codex-$breed')), findsOneWidget);
    }
  });

  testWidgets('排行榜：三個分頁、自己的名次、電腦假玩家標「電腦」', (tester) async {
    final (m, api, _) = await loadedModel();
    await pumpApp(tester, m);
    m.selectTab(AppTab.records);
    await tester.pump();
    await tester.tap(find.text('排行榜'));
    await tester.pumpAndSettle();
    expect(find.text('總資產'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('本週收入'), findsOneWidget);
    expect(api.calls, contains('rank:networth'));
    expect(find.text('我的名次：2　31,000 幣'), findsOneWidget);
    // v2：電腦牧場名用詞庫編號組，前面加「電腦」，後面加 #編號（協定 1.6）
    final zh = Strings.forLang(AppLang.zhHant);
    expect(find.text('電腦 ${zh.ranchNameFromWords([8, 0, 5])} #0003'), findsOneWidget);
    expect(find.text('電腦 ${zh.ranchNameFromWords([0, 1, 0])} #0004'), findsOneWidget);
    expect(find.text('晨光草原牧場 #0031'), findsOneWidget);

    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('rank:collection'));
    expect(find.text('我的名次：2　31,000'), findsOneWidget);
  });
}
