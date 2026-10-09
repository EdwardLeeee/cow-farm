// 小牛長大揭曉（v0.3 C1；協定 2.3「長大揭曉」）：看過是小牛的牛長大了，在牧場頁一頭一頭揭曉。一般的牛是 A-13 的最後一格
// （減少動態那張的「之後」，點一下關掉），雜種牛是 S03-25（按「好」）。看過是小牛的牛記在手機上（照牧場分開）：
// 沒開 app 的時候長大的，下次打開牧場頁時揭曉。S03-25 的畫面在 test/pages（pages_test）。
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/app.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/state/grow_reveals.dart';
import 'package:cowfarm/state/settings.dart';
import 'package:cowfarm/storage/token_store.dart';
import 'package:cowfarm/ui/kit/cow_bits.dart';
import 'package:cowfarm/ui/kit/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'pages/page_case.dart';
import 'pages/s03_cases.dart';

/// 設計稿的牧場，小乳牛 #15 長大了：娟珊（優良）。[extra] 是另外加的牛。
Map<String, dynamic> grownState({List<Map<String, dynamic>> extra = const []}) => ranchState(
  cows: [
    for (final c in designCows())
      if (c['id'] != 15) c,
    designCow(15, 'jersey'),
    ...extra,
  ],
);

final _reveal = find.byKey(const Key('grow-reveal'));

void main() {
  setUpAll(loadAppAssets);
  final zh = Strings.forLang(AppLang.zhHant);

  testWidgets('上一次是小牛、這次長大了：牧場頁揭曉（A-13 的最後一格），點一下關掉，以後不再出', (tester) async {
    Screen.w390.apply(tester);
    final prefs = MemoryPrefsStore();
    final api = FakeGameApi(state: ranchState(), market: ranchMarket());
    final m = await ranchModel(api: api, prefs: prefs);
    expect(m.grownCow, isNull, reason: '#15 還是小牛');
    expect(prefs.values[GrowReveals.key], '15@31', reason: '看過是小牛，記在手機上（照牧場分開）');

    api.stateJson = grownState();
    await m.refreshState();
    expect(m.grownCow?.id, 15);
    await pumpAppIn(tester, m, AppLang.zhHant, prefs: swipeHintSeen);
    expect(_reveal, findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('grow-title'))).data,
      zh.animGrownUp(cow: zh.calfName(CowType.dairy, 15)),
      reason: '「小乳牛 #15 長大了！」',
    );
    // 名牌：品種名、用途、公母、稀有度（伺服器揭曉的）
    final name = find.byKey(const Key('grow-name'));
    expect(find.descendant(of: name, matching: find.text(zh.cowName('jersey', 15))), findsOneWidget);
    expect(find.descendant(of: name, matching: find.byType(UseChip)), findsOneWidget);
    expect(find.descendant(of: name, matching: find.text(zh.cow)), findsOneWidget);
    expect(tester.widget<TierChip>(find.descendant(of: name, matching: find.byType(TierChip))).tier, 1);
    expect(find.byKey(const Key('grow-skip')), findsOneWidget, reason: '「點一下跳過」');
    expect(find.byKey(const Key('grow-ok')), findsNothing, reason: '一般的牛沒有「好」');

    // 點哪裡都關（這裡點標題）
    await tester.tap(find.byKey(const Key('grow-title')));
    await tester.pump();
    expect(_reveal, findsNothing);
    expect(m.grownCow, isNull);
    expect(prefs.values[GrowReveals.key], '', reason: '揭曉完就不用記了');
    await m.refreshState();
    await tester.pump();
    expect(_reveal, findsNothing, reason: '同一頭不再揭曉');
  });

  testWidgets('沒開 app 的時候長大的：打開就照長大的時間一頭一頭揭曉；雜種牛（S03-25）點暗幕不關，要按「好」', (tester) async {
    Screen.w390.apply(tester);
    final prefs = MemoryPrefsStore({GrowReveals.key: '20@31,15@31'});
    // #15 先長大（t0 − 3600），#20 後長大（t0 − 60）
    final m = await ranchModel(
      state: grownState(
        extra: [
          {...mixCow(), 'adult_at': t0 - 60},
        ],
      ),
      prefs: prefs,
    );
    expect(m.grownCow?.id, 15);
    await pumpAppIn(tester, m, AppLang.zhHant, prefs: swipeHintSeen);
    expect(find.text(zh.cowName('jersey', 15)), findsOneWidget);
    await tester.tapAt(const Offset(20, 300));
    await tester.pump();

    expect(find.text(zh.cowName('hybrid', 20)), findsOneWidget, reason: '換下一頭：雜種牛 #20');
    expect(find.byKey(const Key('grow-skip')), findsNothing);
    await tester.tapAt(const Offset(20, 300));
    await tester.pump();
    expect(_reveal, findsOneWidget, reason: '雜種牛點暗幕不關');
    await tester.tap(find.byKey(const Key('grow-ok')));
    await tester.pump();
    expect(_reveal, findsNothing);
    expect(prefs.values[GrowReveals.key], '');
  });

  testWidgets('不在牧場頁的時候長大：回到牧場頁才揭曉', (tester) async {
    Screen.w390.apply(tester);
    final api = FakeGameApi(state: ranchState(), market: ranchMarket());
    final m = await ranchModel(api: api);
    m.selectTab(AppTab.market);
    await pumpAppIn(tester, m, AppLang.zhHant, prefs: swipeHintSeen);
    api.stateJson = grownState();
    await m.refreshState();
    await tester.pump();
    expect(_reveal, findsNothing);
    m.selectTab(AppTab.ranch);
    await tester.pump();
    expect(_reveal, findsOneWidget);
  });

  testWidgets('開著動畫：跟減少動態版一樣淡入 0.2 秒（A-13 的發光、白光還沒做）', (tester) async {
    Screen.w390.apply(tester);
    final api = FakeGameApi(state: ranchState(), market: ranchMarket());
    final m = await ranchModel(api: api);
    final settings = settingsFor(AppLang.zhHant, swipeHintSeen);
    await settings.load();
    await tester.pumpWidget(
      AppMotion(
        enabled: true,
        child: CowFarmApp(model: m, settings: settings),
      ),
    );
    await tester.pump();
    api.stateJson = grownState();
    await m.refreshState();
    await tester.pump();
    double opacity() =>
        tester.widget<Opacity>(find.ancestor(of: _reveal, matching: find.byType(Opacity)).first).opacity;
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacity(), closeTo(0.5, 0.2));
    await tester.pump(const Duration(milliseconds: 150));
    expect(opacity(), 1);
    // 關掉動畫的計時器（牛走動）
    await tester.pumpWidget(const SizedBox());
  });

  test('還沒揭曉就出貨了（state 裡沒有這頭牛）：不揭曉，手機上也不再記', () async {
    final prefs = MemoryPrefsStore({GrowReveals.key: '99@31'});
    final m = await ranchModel(prefs: prefs);
    expect(m.grownCow, isNull);
    expect(prefs.values[GrowReveals.key], '15@31');
  });

  test('照牧場分開記：別的牧場同一個編號的牛不會揭曉；換牧場清掉，牧場刪除了就忘掉', () async {
    final g = GrowReveals(MemoryPrefsStore());
    await g.loaded;
    GameState st(int playerId, {bool calf = false}) => GameState.fromJson({
      ...ranchState(cows: [calf ? designCow(15, 'holstein', stage: 'calf') : designCow(15, 'jersey')]),
      'player_id': playerId,
    });
    g.track(st(31, calf: true));
    final other = st(32);
    g.track(other);
    expect(g.next(other), isNull, reason: '牧場 32 沒看過 #15 是小牛');
    final mine = st(31);
    g.track(mine);
    expect(g.next(mine)?.id, 15);
    g.clear(); // 換牧場
    expect(g.next(mine), isNull);
    g.track(mine); // 換回來：收到 state 再排
    expect(g.next(mine)?.id, 15);
    g.forget(31); // 牧場刪除了
    g.track(mine);
    expect(g.next(mine), isNull);
  });

  test('在最早的那頭小牛長大的時間重抓 state（協定 2.3），不用等定時校正', () async {
    final st = ranchState(cows: [designCow(15, 'holstein', stage: 'calf')]);
    (st['cows'] as List).first['adult_at'] = t0 + 0.2;
    final api = FakeGameApi(state: st, market: ranchMarket());
    final m = GameModel(
      api: api,
      push: FakePush(),
      tokens: MemoryTokenStore({TokenStore.tokenKey: 'tok'}),
      now: FakeClock().call,
      uiTick: null,
      refreshEvery: const Duration(hours: 1),
      marketRefreshEvery: const Duration(hours: 1),
    );
    await m.start();
    int fetched() => api.calls.where((c) => c == 'state').length;
    final n = fetched();
    // 0.2 秒後長大，晚 0.5 秒再抓
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(fetched(), n, reason: '還沒到');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(fetched(), n + 1);
    m.dispose();
  });
}
