// S17 田地（設計稿 boards/S17-田地）的畫面狀態。假資料照 design/m2/src/js/fixtures.js 的 FIELDS、FIELD_UP：
// 第 1 塊田台灣黃牛 #2 長了 62.5 / 88 公斤（每小時 11）、第 2 塊空田、第 3 塊高地牛 #9 長滿 114.4（每小時 14.3）；
// 田地 3 / 12 塊、開新田 4,608 幣；倉庫稻米 184 公斤；12,480 幣。
// 選耕牛的面板（S17-03）另外有奶茶黃牛 #18（能下田，每小時 14.3）和小牛台灣黃牛 #19（1 小時後長大）。
import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/fields/fields_page.dart';
import 'package:cowfarm/ui/kit/cow_bits.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
import 'page_case.dart';
import 's03_cases.dart';

/// 一塊田（協定 3.10 的 fields[]）。空田的上限是 null、每小時 0。
Map<String, dynamic> designField(int index, {int? cow, double rice = 0, double? cap, double rate = 0}) => {
  'index': index,
  'cow_id': cow,
  'rice': rice,
  'capacity': cow == null ? null : cap,
  'per_hour': cow == null ? 0.0 : rate,
};

/// 設計稿的三塊田（FIELDS）。
List<Map<String, dynamic>> designFields() => [
  designField(0, cow: 2, rice: 62.5, cap: 88, rate: 11),
  designField(1),
  designField(2, cow: 9, rice: 114.4, cap: 114.4, rate: 14.3),
];

/// 牧場的牛：設計稿的 10 頭（#2、#9 在田裡），加上小牛台灣黃牛 #19（1 小時後長大）；[freeOx] 再加一頭能下田的
/// 奶茶黃牛 #18（公、優良、每小時 14.3）。沒有能下田的耕牛時「派耕牛」停用（S17-02）。
List<Map<String, dynamic>> fieldsHerd({bool freeOx = true, bool listed18 = false}) => [
  ...designCows(),
  if (freeOx)
    {
      ...designCow(18, 'milkTea', bull: true, kg: 402, value: 4800),
      'rice_per_h': 14.3,
      if (listed18) ...{'listed': 30, 'can_work': false, 'can_breed': false},
    },
  designCow(19, 'yellow', stage: 'calf', growMin: 60),
];

/// 田地頁的牧場：[fields]、倉庫稻米 [stock]、開新田的價格 [cost]（null 是已經最多塊）、金幣、牛。
Map<String, dynamic> fieldsState({
  List<Map<String, dynamic>>? fields,
  double stock = 184,
  double? cost = 4608,
  int max = 12,
  double coins = 12480,
  List<Map<String, dynamic>>? cows,
}) {
  final f = fields ?? designFields();
  final base = ranchState(cows: cows ?? fieldsHerd(), coins: coins, rice: stock);
  final upgrades = (base['upgrades'] as Map).cast<String, dynamic>();
  return {
    ...base,
    'fields': f,
    'rice': {
      'in_fields': f.fold<double>(0, (a, x) => a + (x['rice'] as num)),
      'stock': stock,
      'per_hour': f.fold<double>(0, (a, x) => a + (x['per_hour'] as num)),
    },
    'upgrades': {
      ...upgrades,
      'field': {'level': f.length - 1, 'cost': cost, 'count': f.length, 'max': max},
    },
  };
}

/// 田地頁的假伺服器：記下呼叫；動作之後換成 [after] 的 state；[error] 有東西就照它失敗。
class FieldsApi extends FakeGameApi {
  FieldsApi({Map<String, dynamic>? state}) : super(state: state ?? fieldsState(), market: ranchMarket());

  Map<String, dynamic>? after;
  double harvested = 176.9;
  ApiException? error;

  Future<Map<String, dynamic>> _done(String call, Map<String, dynamic> result) async {
    calls.add(call);
    if (error case final e?) throw e;
    if (after != null) stateJson = after!;
    return result;
  }

  @override
  Future<Map<String, dynamic>> fieldAssign(Object cowId, {int? field}) =>
      _done('field-assign:$cowId:$field', {'cow_id': cowId, 'field': field ?? 0});

  @override
  Future<Map<String, dynamic>> fieldRecall(Object cowId) => _done('field-recall:$cowId', {'cow_id': cowId, 'field': 0});

  @override
  Future<Map<String, dynamic>> fieldHarvest() => _done('field-harvest', {'harvested': harvested});

  @override
  Future<Map<String, dynamic>> fieldExpand() => _done('field-expand', {'kind': 'field', 'cost': 4608});
}

/// 打開田地分頁。[tall] 是長頁（整頁一張）。
Future<GameModel> showFields(
  WidgetTester tester,
  AppLang lang, {
  FieldsApi? api,
  bool tall = false,
  bool connected = true,
}) async {
  final m = await ranchModel(api: api ?? FieldsApi(), connected: connected);
  m.selectTab(AppTab.fields);
  await pumpAppIn(tester, m, lang);
  await tester.pump();
  if (tall) await growToFit(tester, find.byKey(const Key('fields')));
  return m;
}

/// 田地頁的捲動（ListView 只蓋看得到附近的東西：要先捲過去，下面的卡片、按鈕才找得到）。
Finder get fieldsScrollable =>
    find.descendant(of: find.byKey(const Key('fields')), matching: find.byType(Scrollable)).first;

/// 把田地頁捲到 [target] 的上緣在內容區上緣往下 [gap]（設計稿的 scrollTo：el.offsetTop − 6）。
Future<void> scrollFieldsTo(WidgetTester tester, Finder target, {double gap = 6}) async {
  await tester.scrollUntilVisible(target, 200, scrollable: fieldsScrollable);
  final position = tester.state<ScrollableState>(fieldsScrollable).position;
  final box = tester.renderObject<RenderBox>(target);
  final top = RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset - gap;
  position.jumpTo(top.clamp(position.minScrollExtent, position.maxScrollExtent));
  await tester.pump();
}

/// 捲到 [target] 看得到再點（點在畫面外會點到分頁列）。
Future<void> tapFields(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 200, scrollable: fieldsScrollable);
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
  await tester.pump();
}

/// 打開第 2 塊田（空田）的選耕牛面板。
Future<void> openOxSheet(WidgetTester tester) async {
  await tapFields(tester, find.byKey(const Key('field-assign-1')));
  await tester.pump(const Duration(milliseconds: 300));
}

final _zh = Strings.forLang(AppLang.zhHant);

final s17Cases = [
  PageCase(
    'S17-01',
    '一般：田地場景與每塊田（長頁）',
    (tester, lang) => showFields(tester, lang, tall: true).then((_) {}),
    check: (tester) {
      expect(find.byKey(const Key('field-scene')), findsOneWidget);
      expect(find.text('3 ${_zh.s17OfMax(max: 12)}'), findsOneWidget);
      expect(find.text(_zh.harvestAll(kg: '177')), findsOneWidget, reason: '62.5 + 114.4 = 176.9');
      expect(find.text(_zh.s17FullIn(time: '2 小時 20 分', h: 8)), findsOneWidget, reason: '(88 − 62.5) ÷ 11 小時');
      expect(find.text(_zh.fieldFull), findsOneWidget);
      expect(find.text(_zh.expandField(cost: '4,608')), findsOneWidget);
    },
  ),
  PageCase(
    'S17-02',
    '空田：沒有能下田的耕牛時停用',
    (tester, lang) async {
      await showFields(
        tester,
        lang,
        api: FieldsApi(state: fieldsState(cows: fieldsHerd(freeOx: false))),
      );
      await scrollFieldsTo(tester, find.byKey(const Key('field-1')));
    },
    crop: find.byKey(const Key('field-1')),
    check: (tester) {
      expect(find.byKey(const Key('field-no-ox')), findsOneWidget);
      expect(tester.widget<AppButton>(find.byKey(const Key('field-assign-1'))).onPressed, isNull);
    },
  ),
  PageCase(
    'S17-03',
    '選一頭耕牛下田',
    (tester, lang) async {
      await showFields(tester, lang);
      await openOxSheet(tester);
      // 設計稿的背景是捲在最上面（看得到田地場景）
      tester.state<ScrollableState>(fieldsScrollable).position.jumpTo(0);
      await tester.pump();
    },
    check: (tester) {
      expect(find.text(_zh.pickOx(n: 2)), findsOneWidget);
      expect(tester.widget<OxOption>(find.byKey(const Key('ox-18'))).on, isTrue, reason: '預選第一頭能下田的');
      expect(tester.widget<OxOption>(find.byKey(const Key('ox-2'))).off, OxOff.working);
      expect(tester.widget<OxOption>(find.byKey(const Key('ox-19'))).off, OxOff.calf);
      expect(find.text(_zh.s17InField(n: 1)), findsOneWidget);
    },
  ),
  PageCase(
    'S17-04',
    '沒有能下田的耕牛',
    (tester, lang) async {
      // 面板開著的時候，唯一能下田的 #18 上架了（例：在別的手機上架）：面板換成「沒有能下田的成年耕牛」
      final api = FieldsApi();
      final m = await showFields(tester, lang, api: api);
      await openOxSheet(tester);
      api.stateJson = fieldsState(cows: fieldsHerd(listed18: true));
      await m.refreshState();
      await tester.pump();
    },
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.byKey(const Key('ox-none')), findsOneWidget);
      expect(find.text(_zh.noOx), findsOneWidget);
      expect(find.byKey(const Key('ox-got-it')), findsOneWidget);
    },
  ),
  PageCase(
    'S17-05',
    '耕作中：進度、產量、叫回',
    (tester, lang) async {
      await showFields(tester, lang);
      await scrollFieldsTo(tester, find.byKey(const Key('field-0')));
    },
    crop: find.byKey(const Key('field-0')),
    check: (tester) {
      expect(find.text(_zh.fieldRate(v: '11')), findsOneWidget);
      expect(find.byKey(const Key('field-recall-0')), findsOneWidget);
    },
  ),
  PageCase('S17-06', '長滿了，快收成', (tester, lang) async {
    await showFields(tester, lang);
    await scrollFieldsTo(tester, find.byKey(const Key('field-2')));
  }, check: (tester) => expect(find.text(_zh.s17Full), findsOneWidget)),
  PageCase(
    'S17-07',
    '叫回後田裡還有稻米',
    (tester, lang) async {
      final fields = [designFields()[0], designField(1, rice: 20.4), designFields()[2]];
      await showFields(
        tester,
        lang,
        api: FieldsApi(state: fieldsState(fields: fields)),
      );
      await scrollFieldsTo(tester, find.byKey(const Key('field-1')));
    },
    crop: find.byKey(const Key('field-1')),
    check: (tester) => expect(find.text(_zh.s17Leftover(kg: '20.4')), findsOneWidget),
  ),
  PageCase(
    'S17-08',
    '田裡沒有稻米：收成鈕停用',
    (tester, lang) async {
      final fields = [designField(0, cow: 2, rice: 0, cap: 88, rate: 11), designField(1), designField(2)];
      await showFields(
        tester,
        lang,
        api: FieldsApi(state: fieldsState(fields: fields)),
      );
    },
    crop: find.byKey(const Key('harvest')),
    check: (tester) {
      expect(find.text(_zh.s17HarvestNone), findsOneWidget);
      expect(tester.widget<AppButton>(find.byKey(const Key('harvest'))).onPressed, isNull);
    },
  ),
  PageCase(
    'S17-09',
    '收成成功',
    (tester, lang) async {
      final api = FieldsApi()
        ..after = fieldsState(
          stock: 361,
          fields: [
            designField(0, cow: 2, rice: 0, cap: 88, rate: 11),
            designField(1),
            designField(2, cow: 9, rice: 0, cap: 114.4, rate: 14.3),
          ],
        );
      await showFields(tester, lang, api: api);
      await tapFields(tester, find.byKey(const Key('harvest')));
      await tester.pump(const Duration(milliseconds: 300));
      // 設計稿是捲在最上面（看得到收成後的田地場景）
      tester.state<ScrollableState>(fieldsScrollable).position.jumpTo(0);
      await tester.pump();
    },
    check: (tester) {
      expect(find.text(_zh.harvested(kg: '177')), findsOneWidget);
      expect(find.text(_zh.s17HarvestNone), findsOneWidget);
    },
  ),
  PageCase(
    'S17-10',
    '開新田：金幣不夠、已經 12 塊',
    (tester, lang) async {
      final m = await ranchModel(api: FieldsApi(state: fieldsState(coins: 3200)));
      await pumpSheet(tester, lang, model: m, const [
        ExpandField(count: 3, max: 12, cost: 4608, coins: 3200),
        ExpandField(count: 12, max: 12, cost: null, coins: 3200),
      ]);
    },
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.text(_zh.notEnoughCoins(n: '1,408')), findsOneWidget);
      expect(find.text(_zh.s17MaxFields(n: 12)), findsOneWidget);
    },
  ),
  PageCase(
    'S17-11',
    '開新田成功',
    (tester, lang) async {
      final api = FieldsApi()..after = fieldsState(coins: 12480 - 4608, fields: [...designFields(), designField(3)]);
      await showFields(tester, lang, api: api);
      await tapFields(tester, find.byKey(const Key('field-expand')));
      await tester.pump(const Duration(milliseconds: 300));
    },
    crop: find.byKey(const Key('toast')),
    check: (tester) => expect(find.text(_zh.fieldExpanded(n: 4)), findsOneWidget),
  ),
  PageCase(
    'S17-12',
    '田裡剩的稻米比這頭牛的上限多',
    (tester, lang) async {
      final fields = [designField(0, cow: 2, rice: 120, cap: 88, rate: 11), designFields()[1], designFields()[2]];
      await showFields(
        tester,
        lang,
        api: FieldsApi(state: fieldsState(fields: fields)),
      );
      await scrollFieldsTo(tester, find.byKey(const Key('field-0')));
    },
    crop: find.byKey(const Key('field-0')),
    check: (tester) {
      expect(find.text('120.0'), findsOneWidget, reason: '只寫公斤數，不寫「/ 88.0」');
      expect(find.text(_zh.fieldFull), findsNWidgets(2));
    },
  ),
  PageCase(
    'S17-13',
    '病牛在田裡：停止耕田',
    // 設計稿：第 1 塊田的台灣黃牛 #2 生病了（62.5 / 88.0 公斤停住）
    (tester, lang) async {
      final cows = [for (final c in fieldsHerd()) c['id'] == 2 ? sickCow(c) : c];
      await showFields(
        tester,
        lang,
        api: FieldsApi(state: fieldsState(cows: cows)),
      );
      await scrollFieldsTo(tester, find.byKey(const Key('field-0')));
    },
    crop: find.byKey(const Key('field-0')),
    check: (tester) {
      final card = find.byKey(const Key('field-0'));
      expect(find.descendant(of: card, matching: find.byType(SickBadge)), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(_zh.badgeWorking)), findsNothing);
      expect(find.descendant(of: card, matching: find.text(_zh.s17SickStop)), findsOneWidget);
      expect(
        find.descendant(
          of: card,
          matching: find.text(_zh.fieldRate(v: '11')),
        ),
        findsNothing,
        reason: '不寫每小時',
      );
      expect(find.text('62.5 / 88.0'), findsOneWidget);
    },
  ),
];
