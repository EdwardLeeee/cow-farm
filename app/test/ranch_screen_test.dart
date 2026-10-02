// 牧場分頁：S03 牧場頁（收奶、點牛的小名片）、S03-07 牛舍清單，和從清單打開的牛的詳細資料（M1 原型，S04 會換掉）。
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/l10n/strings.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/kit/cow_bits.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:cowfarm/ui/ranch/scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'pages/page_case.dart';
import 'pages/s03_cases.dart' show ranchModel, sceneCowAsset;

FilledButton _btn(WidgetTester tester, String key) =>
    tester.widget<FilledButton>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(FilledButton)));

OutlinedButton _outlined(WidgetTester tester, String key) =>
    tester.widget<OutlinedButton>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(OutlinedButton)));

final _zh = Strings.forLang(AppLang.zhHant);

/// 牧場頁按「我的牛」開牛舍清單（S03-07）。
Future<void> _openPen(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('pen-pill')));
  await tester.pump();
}

/// 清單上下捲的那一個（篩選那排也能左右捲）。
Finder get _penScroll =>
    find.descendant(of: find.byKey(const Key('pen-list')), matching: find.byType(Scrollable)).first;

Future<void> _openCow(WidgetTester tester, String id) async {
  if (find.byKey(const Key('pen-list')).evaluate().isEmpty) await _openPen(tester);
  final card = find.byKey(Key('cow-$id'));
  await tester.scrollUntilVisible(card, 200, scrollable: _penScroll);
  await tester.tap(card);
  await tester.pump();
}

/// 清單上那頭牛的那一列裡面的東西（列可能在畫面外）。
Finder _inRow(String id, Finder f) =>
    find.descendant(of: find.byKey(Key('cow-$id'), skipOffstage: false), matching: f, skipOffstage: false);

/// 清單上現在有哪幾頭牛。
Set<String> _rows() => {
  for (final e in find.byType(CowRow, skipOffstage: false).evaluate()) (e.widget.key! as ValueKey<String>).value,
};

void main() {
  // 場景裡的牛要有圖的量測才畫得出來（點牛的小名片）；320 寬要用 app 的字型量，測試預設的方塊字比較寬
  setUpAll(loadAppAssets);

  testWidgets('牧場：頂列（G-02）；牛舍清單（S03-07）：標題、牛舍用量、每頭牛一列，返回牧場', (tester) async {
    final (m, _, _) = await loadedModel();
    await pumpApp(tester, m);

    expect(find.text('晨光草原牧場'), findsOneWidget);
    expect(find.text('Lv 3'), findsOneWidget);
    expect(find.text('1,500'), findsOneWidget);
    // 原型的「遊戲時間・倍率」不再顯示（設計稿：時間一律寫真實時間）
    expect(find.textContaining('倍率'), findsNothing);

    await _openPen(tester);
    expect(find.text(_zh.cowsTitle), findsOneWidget);
    expect(find.text(_zh.penSummary(used: 5, slots: 6)), findsOneWidget);
    expect(_rows(), {'cow-1', 'cow-2', 'cow-3', 'cow-4', 'cow-5'});
    // 返回牧場
    await tester.tap(find.byKey(const Key('btn-back')));
    await tester.pump();
    expect(find.byKey(const Key('dock')), findsOneWidget);
    expect(m.penListOpen, isFalse);
  });

  testWidgets('牛舍滿了：小字加「（滿了）」', (tester) async {
    final (m, _, _) = await loadedModel(api: FakeGameApi(state: sampleStateJson(penFull: true)));
    await pumpApp(tester, m);
    await _openPen(tester);
    expect(find.text(_zh.penSummary(used: 5, slots: 5) + _zh.s03PenFullSuffix), findsOneWidget);
  });

  testWidgets('v0.2：只有母乳牛產奶；在田裡寫第幾塊田；小牛寫長大倒數；工作中、已配種、小牛有標籤', (tester) async {
    final (m, _, _) = await loadedModel();
    await pumpApp(tester, m);
    await _openPen(tester);
    final sep = _zh.gSep;
    // 母乳牛 #1 產奶；公耕牛 #2 不產奶，寫體重和估值
    expect(_inRow('1', find.text('${_zh.milkRate(v: '14')}$sep${_zh.weight(v: '120')}')), findsOneWidget);
    expect(_inRow('2', find.text('${_zh.weight(v: '200')}$sep${_zh.s03MetaValue(v: '3,120')}')), findsOneWidget);
    // 小牛 #3：遊戲裡還要 1 小時，倒數寫現實時間（÷ 倍率 144）
    expect(_inRow('3', find.text(_zh.stageCalf)), findsOneWidget);
    expect(_inRow('3', find.text(_zh.growUp(v: _zh.countdown(3600 / 144)))), findsOneWidget);
    // 在田裡的 #4、已配種的 #5
    expect(_inRow('4', find.text(_zh.badgeWorking)), findsOneWidget);
    expect(_inRow('4', find.text(_zh.s03MetaField(n: 1, rate: '11'))), findsOneWidget);
    expect(_inRow('5', find.text(_zh.badgeBred)), findsOneWidget);
  });

  testWidgets('上架借種的公牛：寫借種費（D26，系統算的）', (tester) async {
    final (m, _, _) = await loadedModel(api: FakeGameApi(state: sampleStateJson(bullListed: true)));
    await pumpApp(tester, m);
    await _openPen(tester);
    expect(_inRow('2', find.text(_zh.badgeListed)), findsOneWidget);
    expect(_inRow('2', find.text(_zh.s03MetaListed(price: '550'))), findsOneWidget);
  });

  testWidgets('牛舍清單的篩選：乳牛、耕牛、肉牛、全部；「擴建」先到商店', (tester) async {
    final (m, _, _) = await loadedModel();
    await pumpApp(tester, m);
    await _openPen(tester);
    for (final (i, want) in [
      (1, {'cow-1', 'cow-5'}),
      (2, {'cow-2', 'cow-4'}),
      (3, {'cow-3'}),
      (0, {'cow-1', 'cow-2', 'cow-3', 'cow-4', 'cow-5'}),
    ]) {
      await tester.tap(find.byKey(Key('filter-$i')));
      await tester.pump();
      expect(_rows(), want, reason: '篩選 $i');
    }
    await tester.tap(find.byKey(const Key('expand-pen')));
    await tester.pump();
    expect(m.tab, AppTab.shop);
  });

  testWidgets('點場景的牛（S03-06）：轉正面、跳出小名片；再點一次或點空地收起來；「看詳細」打開那頭牛', (tester) async {
    final (m, _, _) = await loadedModel();
    await pumpApp(tester, m);
    final pop = find.byKey(const Key('cow-pop'));
    expect(pop, findsNothing);

    // 產奶的母牛：寫產量（稀有度一般）
    await tester.tap(find.byKey(const Key('scene-cow-1')));
    await tester.pump();
    expect(pop, findsOneWidget);
    expect(find.text(_zh.s03PopMilk(tier: _zh.tierName(0), n: '14')), findsOneWidget);
    // 再點同一頭：收起來
    await tester.tap(find.byKey(const Key('scene-cow-1')));
    await tester.pump();
    expect(pop, findsNothing);

    // 小牛（不產奶）：狀態看標籤「小牛」，不寫產量那一行（設計稿只畫了產奶的牛）。#2 在場景右半邊，一開始看不到
    await tester.tap(find.byKey(const Key('scene-cow-3')));
    await tester.pump();
    expect(find.descendant(of: pop, matching: find.text(_zh.cowName(m.state!.cows[2].breed, 3))), findsOneWidget);
    expect(find.descendant(of: pop, matching: find.text(_zh.stageCalf)), findsOneWidget);
    expect(
      find.descendant(
        of: pop,
        matching: find.textContaining(_zh.growUp(v: '')),
      ),
      findsNothing,
    );
    expect(sceneCowAsset(tester, 3), contains('_front_'));
    // 點名片本身（名字）：不會收起來（名片擋住，點不到後面的空地）
    await tester.tap(find.descendant(of: pop, matching: find.text(_zh.cowName(m.state!.cows[2].breed, 3))));
    await tester.pump();
    expect(pop, findsOneWidget);
    // 點空地（右上方的天空，小名片最右到 12 + 208 + … 碰不到）：收起來
    final scene = tester.getRect(find.byType(RanchScene));
    await tester.tapAt(Offset(scene.right - 4, 230));
    await tester.pump();
    expect(pop, findsNothing);

    // 看詳細：打開那頭牛（M1 的詳細資料）
    await tester.tap(find.byKey(const Key('scene-cow-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('pop-detail')));
    await tester.pump();
    expect(m.detailCowKey, '1');
  });

  testWidgets('後排的牛：小名片不會超出畫面上緣（320×568，設計稿沒畫到）', (tester) async {
    Screen.w320.apply(tester);
    await pumpAppIn(tester, await ranchModel(), AppLang.zhHant, prefs: swipeHintSeen);
    // #8 在後排（場景 y 338），名片照設計稿會超出畫面上緣約 70；被面板蓋住點不到，直接呼叫點牛
    final scene = tester.widget<RanchScene>(find.byType(RanchScene));
    scene.onTapCow!(scene.cows.firstWhere((c) => c.cow.id == 8).cow);
    await tester.pump();
    final pop = tester.getRect(find.byKey(const Key('cow-pop')));
    expect(pop.top, closeTo(Screen.w320.safeTop + 6, 0.01));
    expect(pop.width, 208);
    // 前排的牛照設計稿：名片下緣在頭頂上方 14（尖角另外畫在下緣外面）
    scene.onTapCow!(scene.cows.firstWhere((c) => c.cow.id == 3).cow);
    await tester.pump();
    expect(tester.getRect(find.byKey(const Key('cow-pop'))).top, greaterThan(Screen.w320.safeTop + 6));
  });

  testWidgets('收奶（S03 的面板）：呼叫伺服器、顯示結果、再拿一次 state 校正', (tester) async {
    final (m, api, _) = await loadedModel();
    await pumpApp(tester, m);
    api.calls.clear();

    await tester.tap(find.byKey(const Key('collect')));
    await tester.pump();
    await tester.pump();
    expect(api.calls, ['collect', 'state']);
    expect(find.text(Strings.forLang(AppLang.zhHant).collected(v: '6')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3)); // 提示 2.5 秒後收起來
  });

  testWidgets('奶桶是 0 時收奶鈕停用（S03-05，M1 問題 4）', (tester) async {
    final api = FakeGameApi()..stateJson['bucket'] = {'qty': 0.0, 'capacity': 24.0, 'per_hour': 0.0, 'boost': null};
    final (m, _, _) = await loadedModel(api: api);
    await pumpApp(tester, m);
    expect(tester.widget<AppButton>(find.byKey(const Key('collect'))).onPressed, isNull);
  });

  testWidgets('奶桶依伺服器產量與倍率平滑增加，滿了就停（牧場頁每隔 uiTick 重畫，不用等伺服器）', (tester) async {
    final clock = FakeClock();
    final (m, _, _) = await loadedModel(clock: clock, uiTick: const Duration(milliseconds: 250));
    await pumpApp(tester, m);
    expect(m.bucketNow, closeTo(6.0, 1e-9));
    expect(find.textContaining('6 / 24', findRichText: true), findsOneWidget);

    // 現實 10 秒 × 倍率 144 = 遊戲 0.4 小時 → 多 4.8 瓶
    clock.t += 10;
    expect(m.bucketNow, closeTo(10.8, 1e-9));
    expect(m.gameNow, closeTo(t0 + 1440, 1e-6));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('10.8 / 24', findRichText: true), findsOneWidget);

    clock.t += 1000;
    expect(m.bucketNow, 24.0);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('24 / 24', findRichText: true), findsOneWidget);
  });

  testWidgets('出貨（S20）：先顯示各評級機率與收入，確定後揭曉評級', (tester) async {
    final (m, api, _) = await loadedModel();
    await pumpApp(tester, m);

    await _openCow(tester, '1');
    expect(find.text('出貨估值 約 1,440 幣'), findsOneWidget);
    expect(find.byKey(const Key('detail-grade-probs')), findsOneWidget);

    await tester.tap(find.byKey(const Key('detail-ship')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(api.calls, contains('ship-preview:1'));
    expect(find.byKey(const Key('ship-confirm-body')), findsOneWidget);
    expect(find.text('A 級 13.7%　收入約 1,800 幣'), findsOneWidget);
    expect(find.text('B 級 49.3%　收入約 1,440 幣'), findsOneWidget);
    expect(find.text('C 級 37.0%　收入約 1,080 幣'), findsOneWidget);
    expect(find.text('期望收入 約 1,440 幣'), findsOneWidget);
    expect(api.calls.where((c) => c.startsWith('ship:')), isEmpty);

    await tester.tap(find.byKey(const Key('ship-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(api.calls, contains('ship:1'));
    expect(find.byKey(const Key('ship-result')), findsOneWidget);
    expect(find.text('評級：A 級'), findsOneWidget);
    expect(find.text('120.0 公斤牛肉放進倉庫，現在全部賣掉約 1,800 幣。'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ship-result-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ship-result')), findsNothing);
    expect(m.detailCowKey, isNull);
  });

  testWidgets('小牛不能出貨', (tester) async {
    final (m, _, _) = await loadedModel();
    await pumpApp(tester, m);
    await _openCow(tester, '3');
    expect(_btn(tester, 'detail-ship').onPressed, isNull);
    expect(find.text(S.shipNotAdult), findsOneWidget);
    expect(find.byKey(const Key('detail-grow')), findsOneWidget);
  });

  testWidgets('田裡工作中的耕牛：不能出貨、不能配種，可以叫回', (tester) async {
    final (m, api, _) = await loadedModel();
    await pumpApp(tester, m);
    await _openCow(tester, '4');
    expect(find.text('在第 1 塊田工作'), findsOneWidget);
    expect(find.text(S.recallFirst), findsOneWidget);
    expect(_btn(tester, 'detail-ship').onPressed, isNull);
    expect(_outlined(tester, 'detail-breed').onPressed, isNull);
    await tester.tap(find.byKey(const Key('detail-recall')));
    await tester.pump();
    await tester.pump();
    expect(api.calls, contains('field-recall:4'));
  });

  testWidgets('已配種的牛不能再選去配種', (tester) async {
    final (m, _, _) = await loadedModel();
    await pumpApp(tester, m);
    await _openCow(tester, '5');
    expect(find.byKey(const Key('detail-bred')), findsOneWidget);
    expect(_outlined(tester, 'detail-breed').onPressed, isNull);
  });

  testWidgets('公牛可以從詳細資料上架借種（借種費由系統算，D26）', (tester) async {
    final (m, api, _) = await loadedModel();
    await pumpApp(tester, m);
    await _openCow(tester, '2');
    await tester.ensureVisible(find.byKey(const Key('detail-list')));
    await tester.tap(find.byKey(const Key('detail-list')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(api.calls, contains('stud-list:2'));
  });

  testWidgets('「選這頭去配種」切到配種頁並選好', (tester) async {
    final (m, _, _) = await loadedModel();
    await pumpApp(tester, m);
    await _openCow(tester, '1');
    await tester.tap(find.byKey(const Key('detail-breed')));
    await tester.pump();
    expect(m.tab, AppTab.breed);
    expect(m.breedDamKey, '1');
    expect(find.text(S.pickSire), findsOneWidget);
  });
}
