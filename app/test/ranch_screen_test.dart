import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/l10n/strings.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

FilledButton _btn(WidgetTester tester, String key) =>
    tester.widget<FilledButton>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(FilledButton)));

OutlinedButton _outlined(WidgetTester tester, String key) =>
    tester.widget<OutlinedButton>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(OutlinedButton)));

/// 牧場頁按「我的牛」開牛舍清單（M1 的清單；正式的 S03-07 在下一個 PR）。
Future<void> _openPen(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('pen-pill')));
  await tester.pump();
}

Future<void> _openCow(WidgetTester tester, String id) async {
  if (find.byKey(Key('cow-$id')).evaluate().isEmpty) await _openPen(tester);
  final card = find.byKey(Key('cow-$id'));
  await tester.scrollUntilVisible(card, 200);
  await tester.tap(card);
  await tester.pump();
}

void main() {
  testWidgets('牧場：頂列（G-02）；牛舍清單：奶桶、倉庫（含稻米）、牛的卡片', (tester) async {
    final (m, _, _) = await loadedModel();
    await pumpApp(tester, m);

    expect(find.text('晨光草原牧場'), findsOneWidget);
    expect(find.text('Lv 3'), findsOneWidget);
    expect(find.text('1,500'), findsOneWidget);
    // 原型的「遊戲時間・倍率」不再顯示（設計稿：時間一律寫真實時間）
    expect(find.textContaining('倍率'), findsNothing);

    await _openPen(tester);
    expect(find.text('6.0 / 24 瓶'), findsOneWidget);
    expect(find.text('每小時 12.0 瓶'), findsOneWidget);
    expect(find.text('牛奶 150.5 / 150 瓶（2 批）'), findsOneWidget);
    expect(find.text('牛肉 300.0 公斤（1 批）'), findsOneWidget);
    expect(find.text('稻米 20.0 公斤（1 批）'), findsOneWidget);
    expect(find.textContaining('乳牛・母・成年'), findsWidgets);
    expect(find.textContaining('耕牛・公・成年'), findsOneWidget);
    expect(find.textContaining('肉牛・母・小牛'), findsOneWidget);
    // 返回牧場
    await tester.tap(find.byKey(const Key('pen-back')));
    await tester.pump();
    expect(find.byKey(const Key('dock')), findsOneWidget);
  });

  testWidgets('v0.2：只有母乳牛產奶；工作中、已配種有標示', (tester) async {
    final (m, _, _) = await loadedModel();
    await pumpApp(tester, m);
    await _openPen(tester);
    // 母乳牛 #1 產奶；公耕牛 #2 不產奶
    expect(
      find.descendant(of: find.byKey(const Key('cow-1')), matching: find.textContaining('產奶 14.0 瓶／時')),
      findsOneWidget,
    );
    expect(find.descendant(of: find.byKey(const Key('cow-2')), matching: find.textContaining('不產奶')), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('cow-5')), 200);
    expect(
      find.descendant(of: find.byKey(const Key('cow-4')), matching: find.textContaining('產稻米 11.0 公斤／時')),
      findsOneWidget,
    );
    expect(find.descendant(of: find.byKey(const Key('cow-4')), matching: find.text(S.badgeWorking)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('cow-5')), matching: find.text(S.badgeBred)), findsOneWidget);
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

  testWidgets('奶桶依伺服器產量與倍率平滑增加，滿了就停', (tester) async {
    final clock = FakeClock();
    final (m, _, _) = await loadedModel(clock: clock);
    await pumpApp(tester, m);
    expect(m.bucketNow, closeTo(6.0, 1e-9));

    // 現實 10 秒 × 倍率 144 = 遊戲 0.4 小時 → 多 4.8 瓶
    clock.t += 10;
    expect(m.bucketNow, closeTo(10.8, 1e-9));
    expect(m.gameNow, closeTo(t0 + 1440, 1e-6));
    m.openPenList(); // 觸發重畫（M1 的清單上有奶桶的數字）
    await tester.pump();
    expect(find.text('10.8 / 24 瓶'), findsOneWidget);

    clock.t += 1000;
    expect(m.bucketNow, 24.0);
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
