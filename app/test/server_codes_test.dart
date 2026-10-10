// 收尾（ceo 2026-10-10 審查）：
// - 到了 adult_at、state 還沒重抓的小牛（品種、稀有度還是 null）：不畫稀有度、不能上架。
// - 病牛不能上架（協定 2.6 的 cow_sick）。
// - 伺服器之後新加的品種、飼料代號（協定：伺服器只會「加」東西）：名字寫「？？？」、飼料圖示留空位，畫面不出錯。
import 'dart:io';

import 'package:cowfarm/api/breeds.dart';
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/ui/cow/stamps.dart';
import 'package:cowfarm/ui/kit/cow_bits.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';
import 'pages/page_case.dart';
import 'pages/s03_cases.dart';
import 'pages/s18_cases.dart';

final _zh = Strings.forLang(AppLang.zhHant);

/// 小公牛 #21（安格斯）：adult_at 已經過了 1 分鐘，伺服器的 state 還沒重抓（stage 還是 calf、品種是 null）。
Map<String, dynamic> _justGrown() => {...designCow(21, 'angus', bull: true, stage: 'calf'), 'adult_at': t0 - 60};

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  Provider<Strings>.value(
    value: _zh,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    ),
  ),
);

void main() {
  setUpAll(loadAppAssets);

  test('canListAt：還沒揭曉的小牛、病牛都不能上架', () {
    final calf = Cow.fromJson(_justGrown());
    expect(calf.isAdultAt(t0), isTrue, reason: '照時間已經長大了');
    expect(calf.revealed, isFalse);
    expect(calf.canListAt(t0), isFalse);
    final bull = designCow(14, 'jersey', bull: true, kg: 205);
    expect(Cow.fromJson(bull).canListAt(t0), isTrue);
    expect(Cow.fromJson(sickCow(bull)).canListAt(t0), isFalse, reason: '病牛不能上架');
  });

  testWidgets('cowRarityChip：還沒揭曉的小牛不放稀有度（不是 1 顆星）；揭曉了照品種', (tester) async {
    await _pump(
      tester,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [cowRarityChip(Cow.fromJson(_justGrown())), cowRarityChip(Cow.fromJson(designCow(11, 'wagyu')))],
      ),
    );
    expect(find.byType(TierChip), findsOneWidget);
    expect(tester.widget<TierChip>(find.byType(TierChip)).tier, breedInfo('wagyu')!.tier);
  });

  testWidgets('借種頁「我的公牛」：到了 adult_at 還沒重抓的小公牛、病牛都沒有「上架」', (tester) async {
    Screen.w430.apply(tester);
    final base = studState();
    final cows = [
      for (final c in base['cows'] as List)
        if ((c as Map)['id'] == 14) sickCow(c.cast<String, dynamic>()) else c,
      _justGrown(),
    ];
    await showStud(tester, AppLang.zhHant, api: StudApi(state: {...base, 'cows': cows}));
    expect(find.byKey(const Key('list-21')), findsNothing, reason: '還沒揭曉');
    expect(find.byKey(const Key('list-14')), findsNothing, reason: '生病了');
    expect(tester.takeException(), isNull);
  });

  test('伺服器新加的品種、飼料：名字寫「？？？」，不丟例外', () {
    expect(_zh.breedName('zebu'), _zh.gUnknownBreed);
    expect(_zh.cowName('zebu', 30), '${_zh.gUnknownBreed} #30');
    expect(_zh.feedName('barley'), _zh.gUnknownBreed);
    expect(_zh.feedList(['oats', 'barley']), '${_zh.feedName('oats')}${_zh.gListSep}${_zh.gUnknownBreed}');
    expect(_zh.breedName('jersey'), isNot(_zh.gUnknownBreed));
  });

  test('有圖示的飼料（kFeedIcons）跟 assets/ui/icons/feed_*.svg 一樣', () {
    final files = {
      for (final f in Directory('assets/ui/icons').listSync())
        if (f.uri.pathSegments.last case final n when n.startsWith('feed_') && n.endsWith('.svg'))
          n.substring(5, n.length - 4),
    };
    expect(files, kFeedIcons);
  });

  testWidgets('集點卡遇到新加的飼料：圖示留一樣大的空位、名字寫「？？？」，畫面不出錯', (tester) async {
    final calf = Cow.fromJson({
      ...designCow(15, 'holstein', stage: 'calf'),
      'need': ['oats', 'barley'],
      'ate': ['oats'],
    });
    await _pump(tester, SizedBox(width: 400, child: StampCard(cow: calf)));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text(_zh.gUnknownBreed), findsOneWidget);
  });
}
