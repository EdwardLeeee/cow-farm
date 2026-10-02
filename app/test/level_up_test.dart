// S11-01 場主升級慶祝：state 的等級比上一次高就跳慶祝卡（在哪一頁升級就在哪一頁跳），按「好」關掉；
// 剛打開（之前沒有 state）不跳；一次升好幾級只跳最後那一級。畫面本身在 test/pages/s11_cases.dart。
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'pages/page_case.dart';

final _zh = Strings.forLang(AppLang.zhHant);

Map<String, dynamic> _level(Map<String, dynamic> state, int level, double levelAt, double nextAt) => {
  ...state,
  'level': level,
  'level_progress': {'earned': levelAt, 'level_at': levelAt, 'next_at': nextAt},
};

void main() {
  setUpAll(loadAppAssets);

  testWidgets('升級：在市場賣東西升到 Lv4，就在市場跳慶祝卡；按「好」關掉', (tester) async {
    Screen.w390.apply(tester);
    final (m, api, _) = await loadedModel();
    expect(m.levelUp, isNull, reason: '剛打開不算升級');
    m.selectTab(AppTab.market);
    await pumpAppIn(tester, m, AppLang.zhHant);
    expect(find.byKey(const Key('level-up')), findsNothing);

    api.stateJson = _level(api.stateJson, 4, 3500, 7500);
    await m.refreshState();
    await tester.pump();
    expect(find.byKey(const Key('level-up')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('level-up-lv'))).data, '4');
    expect(find.text(_zh.s11Earned(v: '3,500')), findsOneWidget);
    expect(m.tab, AppTab.market, reason: '不換頁');

    await tester.tap(find.byKey(const Key('level-up-ok')));
    await tester.pump();
    expect(find.byKey(const Key('level-up')), findsNothing);
    expect(m.levelUp, isNull);

    // 同一級再拿一次 state：不再跳
    await m.refreshState();
    await tester.pump();
    expect(find.byKey(const Key('level-up')), findsNothing);
  });

  test('一次升好幾級只跳最後那一級；等級沒變不跳', () async {
    final (m, api, _) = await loadedModel();
    final start = m.state!.level;
    await m.refreshState();
    expect(m.levelUp, isNull);
    api.stateJson = _level(api.stateJson, start + 2, 7500, 15500);
    await m.refreshState();
    expect(m.levelUp, (level: start + 2, levelAt: 7500.0));
  });
}
