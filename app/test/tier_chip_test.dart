// 稀有度標籤（#170：第 15 輪 02-A「只有星星」、第 16 輪 02-B 彩虹星）：一般 1、優良 2、稀有 3、傳說 4 顆星，
// 特殊牛 5 顆彩虹星，雜種牛 1 顆灰星；名字不寫在標籤上，給螢幕閱讀器唸。
import 'package:cowfarm/api/breeds.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/ui/kit/app_icon.dart';
import 'package:cowfarm/ui/kit/cow_bits.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'pages/page_case.dart';

final _zh = Strings.forLang(AppLang.zhHant);

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  Provider<Strings>.value(
    value: _zh,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    ),
  ),
);

List<String> _stars(WidgetTester tester) => [for (final w in tester.widgetList<AppIcon>(find.byType(AppIcon))) w.name];

void main() {
  setUpAll(loadAppAssets);

  for (var tier = 0; tier < 4; tier++) {
    testWidgets('稀有度 $tier：${tier + 1} 顆星，螢幕閱讀器唸「${_zh.tierName(tier)}」', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, TierChip(tier));
      expect(_stars(tester), List.filled(tier + 1, 'star'));
      expect(find.text(_zh.tierName(tier)), findsNothing, reason: '名字不寫在標籤上');
      expect(find.bySemanticsLabel(_zh.tierName(tier)), findsOneWidget);
      // .tier.stars：高 22，左右 6、框 2，星星 11、之間 1
      expect(tester.getSize(find.byType(TierChip)), Size(2 * 8 + 11.0 * (tier + 1) + tier, 22));
      semantics.dispose();
    });
  }

  testWidgets('特殊牛：5 顆彩虹星（紅橙黃綠藍）', (tester) async {
    await _pump(tester, const TierChip(4));
    expect(_stars(tester), ['starRainbow1', 'starRainbow2', 'starRainbow3', 'starRainbow4', 'starRainbow5']);
  });

  testWidgets('雜種牛：1 顆灰星，螢幕閱讀器唸「雜種」', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, const MixStarChip());
    expect(_stars(tester), ['starGray']);
    expect(find.bySemanticsLabel(_zh.badgeMix), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('rarityChip：雜種牛畫灰星，其他照圖鑑的稀有度', (tester) async {
    await _pump(
      tester,
      Row(mainAxisSize: MainAxisSize.min, children: [rarityChip(kHybrid, 2), rarityChip('goldenEar', 0)]),
    );
    expect(find.byType(MixStarChip), findsOneWidget);
    expect(tester.widget<TierChip>(find.byType(TierChip)).tier, breedInfo('goldenEar')!.tier);
  });

  testWidgets('圖鑑格子的小號：高 20、左右 5、框 1.5', (tester) async {
    await _pump(tester, const TierChip(1, compact: true));
    expect(tester.getSize(find.byType(TierChip)), const Size(2 * 6.5 + 11.0 * 2 + 1, 20));
  });
}
