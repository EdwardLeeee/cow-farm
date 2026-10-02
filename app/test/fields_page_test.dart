// S17 田地（正式畫面）：收成、派耕牛（面板）、叫回、開新田、伺服器拒絕、斷線、稻米的推算和顯示的數字。
// 畫面狀態本身（S17-01～12）在 test/pages/s17_cases.dart。
import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/ui/fields/fields_page.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'pages/page_case.dart';
import 'pages/s03_cases.dart';
import 'pages/s17_cases.dart';

final _zh = Strings.forLang(AppLang.zhHant);

AppButton _btn(WidgetTester tester, String key) => tester.widget<AppButton>(find.byKey(Key(key)));

OxOption _ox(WidgetTester tester, String id) => tester.widget<OxOption>(find.byKey(Key('ox-$id')));

/// 另一頭能下田的耕牛：台灣黃牛 #20（母、一般，每小時 11）。
Map<String, dynamic> _ox20() => {...designCow(20, 'yellow', kg: 380, value: 4200), 'rice_per_h': 11.0};

void main() {
  setUpAll(loadAppAssets);

  testWidgets('收成：叫伺服器，提示收了多少；收完田裡沒有稻米，按鈕停用', (tester) async {
    Screen.w430.apply(tester);
    final api = FieldsApi()
      ..after = fieldsState(
        stock: 361,
        fields: [
          designField(0, cow: 2, rice: 0, cap: 88, rate: 11),
          designField(1),
          designField(2, cow: 9, rice: 0, cap: 114.4, rate: 14.3),
        ],
      );
    await showFields(tester, AppLang.zhHant, api: api);
    expect(_btn(tester, 'harvest').label, _zh.harvestAll(kg: '177'));
    await tapFields(tester, find.byKey(const Key('harvest')));
    expect(api.calls, contains('field-harvest'));
    expect(find.text(_zh.harvested(kg: '177')), findsOneWidget);
    expect(_btn(tester, 'harvest').label, _zh.s17HarvestNone);
    expect(_btn(tester, 'harvest').onPressed, isNull);
    // 收完以後兩塊田都沒長滿：每小時 11 + 14.3
    expect(find.text('25.3 ${_zh.gKg}'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('派耕牛：面板預選產量最高的那頭；換選另一頭，「派去田裡」帶這塊田；派完面板關掉', (tester) async {
    Screen.w430.apply(tester);
    final api = FieldsApi(state: fieldsState(cows: [...fieldsHerd(), _ox20()]));
    await showFields(tester, AppLang.zhHant, api: api);
    await openOxSheet(tester);
    expect(find.text(_zh.pickOx(n: 2)), findsOneWidget);
    expect(_ox(tester, '18').on, isTrue, reason: '#18 每小時 14.3，比 #20 的 11 多');
    expect(_ox(tester, '20').on, isFalse);
    // 不能選的（在田裡）點了沒反應
    await tester.tap(find.byKey(const Key('ox-2')));
    await tester.pump();
    expect(_ox(tester, '18').on, isTrue);

    await tester.tap(find.byKey(const Key('ox-20')));
    await tester.pump();
    expect(_ox(tester, '20').on, isTrue);
    await tester.tap(find.byKey(const Key('ox-assign')));
    await tester.pump();
    await tester.pump();
    expect(api.calls, contains('field-assign:20:1'));
    expect(find.byKey(const Key('sheet')), findsNothing);
  });

  testWidgets('面板：「取消」、點暗幕都會關掉；能下田的都沒了換成「沒有能下田的成年耕牛」，「知道了」關掉', (tester) async {
    Screen.w430.apply(tester);
    final api = FieldsApi();
    final m = await showFields(tester, AppLang.zhHant, api: api);
    await openOxSheet(tester);
    await tester.tap(find.byKey(const Key('ox-cancel')));
    await tester.pump();
    expect(find.byKey(const Key('sheet')), findsNothing);

    await openOxSheet(tester);
    await tester.tapAt(const Offset(215, 120)); // 暗幕（面板上面）
    await tester.pump();
    expect(find.byKey(const Key('sheet')), findsNothing);

    await openOxSheet(tester);
    api.stateJson = fieldsState(cows: fieldsHerd(listed18: true));
    await m.refreshState();
    await tester.pump();
    expect(find.byKey(const Key('ox-none')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ox-got-it')));
    await tester.pump();
    expect(find.byKey(const Key('sheet')), findsNothing);
    // 沒有能下田的耕牛：空田的「派耕牛」停用，加一行橘字（S17-02）
    await tester.scrollUntilVisible(find.byKey(const Key('field-no-ox')), 200, scrollable: fieldsScrollable);
    expect(_btn(tester, 'field-assign-1').onPressed, isNull);
  });

  testWidgets('叫回：叫伺服器（叫回的是那塊田的牛）', (tester) async {
    Screen.w430.apply(tester);
    final api = FieldsApi();
    await showFields(tester, AppLang.zhHant, api: api);
    await tapFields(tester, find.byKey(const Key('field-recall-0')));
    expect(api.calls, contains('field-recall:2'));
  });

  testWidgets('伺服器拒絕（這塊田已經有牛了）：面板關掉，提示原因', (tester) async {
    Screen.w430.apply(tester);
    final api = FieldsApi()..error = const ApiException(409, 'field_occupied', 'occupied');
    await showFields(tester, AppLang.zhHant, api: api);
    await openOxSheet(tester);
    await tester.tap(find.byKey(const Key('ox-assign')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('sheet')), findsNothing);
    expect(find.text(_zh.errorText('field_occupied')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('開新田：錢夠就開，提示第幾塊；錢不夠停用、寫還差多少；已經最多塊換成「田地已經 12 塊（最多）」', (tester) async {
    Screen.w430.apply(tester);
    final api = FieldsApi()..after = fieldsState(coins: 12480 - 4608, fields: [...designFields(), designField(3)]);
    await showFields(tester, AppLang.zhHant, api: api);
    await tapFields(tester, find.byKey(const Key('field-expand')));
    expect(api.calls, contains('field-expand'));
    expect(find.text(_zh.fieldExpanded(n: 4)), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('開新田：錢不夠、已經最多塊', (tester) async {
    Screen.w430.apply(tester);
    await showFields(tester, AppLang.zhHant, api: FieldsApi(state: fieldsState(coins: 3200)));
    await tester.scrollUntilVisible(find.byKey(const Key('field-expand-coins')), 200, scrollable: fieldsScrollable);
    expect(_btn(tester, 'field-expand').onPressed, isNull);
    expect(find.text(_zh.notEnoughCoins(n: '1,408')), findsOneWidget);

    await showFields(tester, AppLang.zhHant, api: FieldsApi(state: fieldsState(cost: null)));
    await tester.scrollUntilVisible(find.byKey(const Key('field-expand')), 200, scrollable: fieldsScrollable);
    expect(_btn(tester, 'field-expand').label, _zh.s17MaxFields(n: 12));
    expect(_btn(tester, 'field-expand').onPressed, isNull);
  });

  testWidgets('斷線：收成、派耕牛、叫回、開新田都停用', (tester) async {
    Screen.w430.apply(tester);
    await showFields(tester, AppLang.zhHant, connected: false);
    expect(_btn(tester, 'harvest').onPressed, isNull);
    await tester.scrollUntilVisible(find.byKey(const Key('field-recall-0')), 200, scrollable: fieldsScrollable);
    expect(_btn(tester, 'field-recall-0').onPressed, isNull);
    await tester.scrollUntilVisible(find.byKey(const Key('field-assign-1')), 200, scrollable: fieldsScrollable);
    expect(_btn(tester, 'field-assign-1').onPressed, isNull);
    await tester.scrollUntilVisible(find.byKey(const Key('field-expand')), 200, scrollable: fieldsScrollable);
    expect(_btn(tester, 'field-expand').onPressed, isNull);
  });

  testWidgets('卡片上的按鈕：無障礙只讀按鈕自己的字（不把卡片上的字併進來；8790 走查找不到「派耕牛」）', (tester) async {
    Screen.w430.apply(tester);
    final semantics = tester.ensureSemantics();
    await showFields(tester, AppLang.zhHant);
    await tester.scrollUntilVisible(find.byKey(const Key('field-assign-1')), 200, scrollable: fieldsScrollable);
    expect(
      tester.getSemantics(find.byKey(const Key('field-assign-1'))),
      isSemantics(label: _zh.assignOx, isButton: true),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('field-recall-0'))),
      isSemantics(label: _zh.recall, isButton: true),
    );
    semantics.dispose();
  });

  test('稻米照產量推算，長滿就停；剩的比上限多的不再長（S17-12）', () {
    const growing = FieldInfo(index: 0, cowId: 2, rice: 62.5, capacity: 88, perHour: 11);
    expect(growing.riceAfter(3600), 73.5);
    expect(growing.riceAfter(36000), 88);
    const over = FieldInfo(index: 0, cowId: 2, rice: 120, capacity: 88, perHour: 11);
    expect(over.riceAfter(3600), 120);
    const empty = FieldInfo(index: 1, rice: 20.4);
    expect(empty.riceAfter(3600), 20.4);
  });

  test('「約 x 後長滿」：無條件進位到分；一小時以上寫「x 小時 y 分」（0 分也寫）', () {
    expect(fullInText(_zh, (88 - 62.5) / 11 * 60), '2 小時 20 分');
    expect(fullInText(_zh, 480), '8 小時 0 分');
    expect(fullInText(_zh, 59.2), '1 小時 0 分');
    expect(fullInText(_zh, 0.4), '1 分');
  });

  test('最多存幾小時：田的上限 ÷（壯年一般耕牛每小時 × 稀有度倍率）；算不出來寫 8', () {
    const e = Economy(tierMult: [1.0, 1.3, 1.7, 2.5], oxRicePerH: 11);
    Cow ox(int tier) => Cow.fromJson({...designCow(2, 'yellow', bull: true), 'tier': tier});
    expect(fieldCapHours(e, 88, ox(0)), 8);
    expect(fieldCapHours(e, 114.4, ox(1)), 8);
    expect(fieldCapHours(null, 88, ox(0)), 8);
    expect(fieldCapHours(e, null, null), 8);
  });

  test('面板的順序：能下田的（產量高的先）、在田裡的（田號小的先）、上架中的、小牛（快長大的先）；乳牛、肉牛不列', () {
    final cows = [
      for (final j in [...fieldsHerd(listed18: true), _ox20(), designCow(21, 'yellow', stage: 'calf', growMin: 20)])
        Cow.fromJson(j),
    ];
    final order = [for (final (c, off) in oxOptions(cows, t0)) '${c.key}:${off?.name ?? 'free'}'];
    expect(order, ['20:free', '2:working', '9:working', '18:listed', '21:calf', '19:calf']);
  });
}
