import 'package:cowfarm/api/breeds.dart';
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'pages/page_case.dart';

void main() {
  // app 的字型：沒載入時測試用的方塊字每個字一樣寬（1 個字級），320 寬的頂列會被撐爆
  setUpAll(loadAppAssets);

  testWidgets('圖鑑（S09）：24 格，已發現 2 種；點一格看品種詳細，返回鍵、返回鈕回到列表', (tester) async {
    final (m, _, _) = await loadedModel();
    await pumpApp(tester, m);
    m.selectTab(AppTab.records);
    await tester.pump();
    final zh = Strings.forLang(AppLang.zhHant);
    expect(find.text('2 / 24'), findsOneWidget);
    expect(find.text(zh.breedName('holstein')), findsOneWidget);
    for (final breed in kCodexOrder) {
      expect(find.byKey(Key('codex-$breed'), skipOffstage: false), findsOneWidget, reason: breed);
    }

    await tester.tap(find.byKey(const Key('codex-holstein')));
    await tester.pump();
    expect(m.codexBreed, 'holstein');
    expect(find.text('No.01'), findsOneWidget);
    // Android 的返回鍵：先關品種詳細，不是關掉 app
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(m.codexBreed, isNull);
    expect(find.byKey(const Key('codex')), findsOneWidget);

    await tester.tap(find.byKey(const Key('codex-jersey')));
    await tester.pump();
    expect(find.text(zh.gUnknownBreed), findsOneWidget, reason: '娟珊還沒發現');
    await tester.tap(find.byKey(const Key('btn-back')));
    await tester.pump();
    expect(m.codexBreed, isNull);
  });

  testWidgets('圖鑑：畫面 339 寬以下一排 3 格，以上 4 格；品種名不換行（screens.css 的 @media、.dex-name）', (tester) async {
    final zh = Strings.forLang(AppLang.zhHant);
    final dairy = [
      for (final b in kCodexOrder)
        if (breedInfo(b)?.type == CowType.dairy) b,
    ];
    for (final (screen, cols) in [(Screen.w320, 3), (Screen.w360, 4)]) {
      final (m, _, _) = await loadedModel();
      await pumpApp(tester, m);
      screen.apply(tester); // pumpApp 固定 430 寬，之後才換成要測的寬度
      m.selectTab(AppTab.records);
      await tester.pump();
      final first = tester.getRect(find.byKey(Key('codex-${dairy[0]}')));
      final next = tester.getRect(find.byKey(Key('codex-${dairy[cols]}')));
      expect(next.top, greaterThan(first.bottom), reason: '${screen.label}：第 ${cols + 1} 格換到下一排');
      expect(next.left, first.left, reason: screen.label);
      final last = tester.getRect(find.byKey(Key('codex-${dairy[cols - 1]}')));
      expect(last.top, first.top, reason: '${screen.label}：第 $cols 格還在第一排');
      final name = find.descendant(
        of: find.byKey(Key('codex-${dairy[0]}')),
        matching: find.text(zh.breedName(dairy[0])),
      );
      expect(tester.widget<Text>(name).softWrap, isFalse);
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
