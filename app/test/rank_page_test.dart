// S12 排行榜：載入失敗按「重試」、下拉重新整理（G-09）、本週收入的重算時間照手機的時區、窄手機「完成」只留打勾
// （列裡的名字露出不到 4 個字寬、「我的名次」那一條放不下）。
// 畫面狀態本身（S12-01～08）在 test/pages/s12_cases.dart。
import 'dart:async';

import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/ui/kit/pull_refresh.dart';
import 'package:cowfarm/ui/records/rank_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pages/page_case.dart';
import 'pages/s12_cases.dart';

final _zh = Strings.forLang(AppLang.zhHant);

void main() {
  setUpAll(loadAppAssets);

  testWidgets('載入失敗（S12-06）：按「重試」再讀一次，讀到就顯示前 50 名', (tester) async {
    Screen.w430.apply(tester);
    final api = RankApi(fail: true);
    await showRank(tester, AppLang.zhHant, api: api);
    expect(find.byKey(const Key('rank-failed')), findsOneWidget);
    api.fail = false;
    await tester.tap(find.byKey(const Key('rank-retry')));
    await tester.pump();
    await tester.pump();
    expect(api.calls.where((c) => c == 'rank:networth'), hasLength(2));
    expect(find.byKey(const Key('rank-row-1')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('my-rank'))).data, _zh.s12RankN(n: 37));
  });

  testWidgets('下拉重新整理：再讀一次這一種；讀的時候最上面一行「轉圈＋重新整理中…」（G-09）', (tester) async {
    Screen.w430.apply(tester);
    final api = _HoldApi();
    await showRank(tester, AppLang.zhHant, kind: RankKind.weekly, api: api);
    expect(api.calls.where((c) => c == 'rank:weekly'), hasLength(1));
    expect(find.byType(PullIndicator), findsNothing);
    final hold = api.hold = Completer<Leaderboard>();
    await tester.fling(find.byKey(const Key('rank')), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(api.calls.where((c) => c == 'rank:weekly'), hasLength(2));
    expect(find.byType(PullIndicator), findsOneWidget);
    expect(find.text(_zh.gRefreshing), findsOneWidget);
    expect(find.byKey(const Key('rank-row-1')), findsOneWidget, reason: '讀的時候舊的名次還在');
    hold.complete(designBoard(RankKind.weekly));
    await tester.pumpAndSettle();
    expect(find.byType(PullIndicator), findsNothing);
  });

  test('本週收入的重算時間照手機的時區（伺服器給現實時間；沒給就照台灣週一 00:00）', () {
    addTearDown(() => debugRankUtcOffset = null);
    debugRankUtcOffset = const Duration(hours: 8);
    expect(weeklyResetClock(designWeeklyReset), (weekday: 1, hour: 0, minute: 0), reason: '台灣：週一 00:00');
    debugRankUtcOffset = const Duration(hours: -7);
    expect(weeklyResetClock(designWeeklyReset), (weekday: 0, hour: 9, minute: 0), reason: '美國西岸夏令時間：週日 09:00');
    debugRankUtcOffset = const Duration(hours: 7);
    expect(weeklyResetClock(designWeeklyReset), (weekday: 0, hour: 23, minute: 0), reason: '泰國：週日 23:00');
    debugRankUtcOffset = const Duration(hours: 8);
    expect(weeklyResetClock(null), (weekday: 1, hour: 0, minute: 0), reason: '伺服器沒給：台灣週一 00:00');
  });

  testWidgets('「我的名次」放不下時「完成」只留打勾（泰文 320 寬）；放得下照常（繁中 430）', (tester) async {
    RankApi api() => RankApi(
      boards: {
        RankKind.collection: designBoard(
          RankKind.collection,
          me: RankEntry(rank: 2, score: 24, ranch: designMeRanch(), isMe: true),
        ),
      },
    );
    DoneBadge myBadge() => tester.widget<DoneBadge>(
      find.descendant(of: find.byKey(const Key('my-rank-bar')), matching: find.byType(DoneBadge)),
    );

    Screen.w430.apply(tester);
    await showRank(tester, AppLang.zhHant, kind: RankKind.collection, api: api());
    expect(myBadge().tight, isFalse);

    Screen.w320.apply(tester);
    await showRank(tester, AppLang.th, kind: RankKind.collection, api: api());
    expect(myBadge().tight, isTrue);
    expect(tester.takeException(), isNull, reason: '只留打勾以後放得下');
  });

  testWidgets('圖鑑榜的列：名字被截到露出不到 4 個字寬時「完成」只留打勾（英文 320 的第 1、2 名）；繁中 430 照常', (tester) async {
    bool tight(int rank) => tester
        .widget<DoneBadge>(find.descendant(of: find.byKey(Key('rank-row-$rank')), matching: find.byType(DoneBadge)))
        .tight;
    double nameWidth(int rank) => tester.getSize(find.byKey(Key('rank-name-$rank'))).width;

    Screen.w430.apply(tester);
    await showRank(tester, AppLang.zhHant, kind: RankKind.collection);
    expect([tight(1), tight(2)], [false, false]);
    expect(nameWidth(1), greaterThanOrEqualTo(15 * 4));

    Screen.w320.apply(tester);
    await showRank(tester, AppLang.en, kind: RankKind.collection);
    expect([tight(1), tight(2)], [true, true]);
    expect(find.text(Strings.forLang(AppLang.en).s12Complete), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

/// 第一次照常回答；[hold] 有值以後等它（下拉重新整理讀到一半的樣子）。
class _HoldApi extends RankApi {
  Completer<Leaderboard>? hold;

  @override
  Future<Leaderboard> leaderboard(RankKind kind) {
    final h = hold;
    if (h == null) return super.leaderboard(kind);
    calls.add('rank:${kind.wire}');
    return h.future;
  }
}
