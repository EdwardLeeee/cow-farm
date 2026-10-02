// S03 牧場（設計稿 boards/S03-牧場）和頂列、分頁列（G-01、G-02、G-03、G-10）的畫面狀態，S15-01 斷線。
// 假資料照設計稿 design/m2/src/js/fixtures.js：10 頭牛（2 頭去田裡）、奶桶 36.4／42、倉庫、收購價、第一則新聞。
import 'package:cowfarm/api/breeds.dart';
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/state/settings.dart';
import 'package:cowfarm/theme/app_theme.dart';
import 'package:cowfarm/theme/tokens.dart';
import 'package:cowfarm/ui/kit/frame.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:cowfarm/ui/ranch/dock.dart';
import 'package:cowfarm/ui/ranch/scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../fakes.dart';
import 'page_case.dart';

/// 一頭牛（協定 2.3 的形狀），品種照設計稿指定；用途、稀有度從品種表來。
Map<String, dynamic> designCow(
  int id,
  String breed, {
  bool bull = false,
  String stage = 'adult',
  double milk = 0,
  double kg = 200,
  int? field,
  Object? listed,
  bool bred = false,
}) {
  final info = breedInfo(breed)!;
  final adult = stage != 'calf';
  return {
    'id': id,
    'type': info.type.wire,
    'bull': bull,
    'tier': info.tier,
    'breed': breed,
    'stage': stage,
    'born_at': t0 - 36000,
    'age_h': 10.0,
    'adult_at': adult ? t0 - 3600 : t0 + 42 * 60,
    'milk_per_h': milk,
    'milk_frac': milk > 0 ? 1.0 : 0.0,
    'weight_kg': adult ? kg : 0,
    'beef_quality': 1.0,
    'ship_value': adult ? 2000 : 0,
    'bred': bred,
    'working': field != null,
    'field': field,
    'listed': listed,
    'can_breed': adult && !bred && field == null && listed == null,
    'can_ship': adult && field == null && listed == null,
    'can_work': info.type == CowType.dual && adult && field == null && listed == null,
    'rice_per_h': field != null ? 11.0 : 0,
    'grade_probs': adult ? {'A': 0.4, 'B': 0.44, 'C': 0.16} : null,
    'origin': 'start',
    'stud_fee': null,
  };
}

/// 設計稿的 10 頭牛（fixtures.js 的 COWS）：#2 耕牛、#9 高地牛在田裡，場景裡看不到。
List<Map<String, dynamic>> designCows() => [
  designCow(3, 'holstein', milk: 14, kg: 212),
  designCow(7, 'jersey', milk: 14, kg: 196),
  designCow(12, 'strawberry', milk: 14, kg: 174),
  designCow(15, 'holstein', stage: 'calf'),
  designCow(2, 'yellow', bull: true, kg: 431, field: 0),
  designCow(9, 'highland', kg: 377, field: 2),
  designCow(5, 'angus', bull: true, kg: 790, listed: 7),
  designCow(11, 'wagyu', kg: 612),
  designCow(8, 'holstein', bull: true, stage: 'old', kg: 268, bred: true),
  designCow(14, 'jersey', bull: true, kg: 205),
];

/// 設計稿 S03-01 的牧場：Lv 4（經驗 41%）、12,480 幣、牛舍 10／12、奶桶 36.4／42（每小時 42 瓶）、倉庫 225。
Map<String, dynamic> ranchState({
  List<Map<String, dynamic>>? cows,
  double bucket = 36.4,
  double bucketCap = 42,
  double perHour = 42,
  List<Map<String, dynamic>>? milkLots,
  double warehouseCap = 225,
  double coins = 12480,
  int level = 4,
  Map<String, dynamic>? levelProgress,
  int penSlots = 12,
  int? penUsed,
  double beef = 934,
  double rice = 184,
}) {
  final herd = cows ?? designCows();
  final milk =
      milkLots ??
      [
        {'qty': 60, 'tier': 0, 'freshness': 1.0},
        {'qty': 48, 'tier': 1, 'freshness': 0.82},
        {'qty': 22, 'tier': 3, 'freshness': 0.64},
      ];
  final milkTotal = milk.fold<double>(0, (a, l) => a + (l['qty'] as num));
  return {
    ...sampleStateJson(coins: coins),
    'time_scale': 1,
    'ranch_name': '晨光河畔牧場',
    'level': level,
    'level_progress': levelProgress ?? {'earned': 5120, 'level_at': 3500, 'next_at': 7500},
    'cows': herd,
    'pen': {
      'slots': penSlots,
      'used': penUsed ?? herd.length,
      'next_cost': 12150,
      'next_open_at': null,
      'max_slots': 40,
    },
    'bucket': {'qty': bucket, 'capacity': bucketCap, 'per_hour': perHour, 'boost': null},
    'warehouse': {
      'capacity': warehouseCap,
      'used': milkTotal,
      'milk_total': milkTotal,
      'beef_total': beef,
      'rice_total': rice,
      'milk_lots': milk,
      'beef_lots': [
        {'qty': 236, 'tier': 0, 'grade': 'A'},
        {'qty': 698, 'tier': 0, 'grade': 'B'},
      ],
      'rice_lots': [
        {'qty': 120, 'quality': 1.0},
        {'qty': 64, 'quality': 0.93},
      ],
    },
  };
}

/// 設計稿的收購價（牛奶 13.4、牛肉 11.2、稻米 5.35，基本價 12、12、5）和第一則新聞「學校午餐加訂鮮奶」。
Map<String, dynamic> ranchMarket({
  double milk = 13.4,
  double beef = 11.2,
  double rice = 5.35,
  List<Map<String, dynamic>>? news,
}) {
  Map<String, dynamic> q(double p, double base) => {
    'price': p,
    'change_24h': 0.1,
    'change_24h_pct': 0.01,
    'ma24': p,
    'base_price': base,
    'ratio': p / base,
  };
  return {
    'server_time': t0,
    'milk': q(milk, 12),
    'beef': q(beef, 12),
    'rice': q(rice, 5),
    'news':
        news ??
        [
          {
            'id': 101,
            'code': 'milk_up.1',
            'params': {},
            'pct': 0.12,
            'commodity': 'milk',
            'targets': ['milk'],
            'direction': 'up',
            'big': false,
            'time': t0 - 720,
            'announce_at': t0 - 720,
            'start_at': t0 - 720,
            'end_at': t0 + 7200,
            'state': 'active',
          },
        ],
  };
}

/// 載好設計稿牧場的模型（連線中、時鐘固定）。
Future<GameModel> ranchModel({
  Map<String, dynamic>? state,
  Map<String, dynamic>? market,
  FakeGameApi? api,
  bool connected = true,
}) async {
  final a = api ?? FakeGameApi(state: state ?? ranchState(), market: market ?? ranchMarket());
  if (api != null) {
    a.stateJson = state ?? a.stateJson;
    a.marketJson = market ?? a.marketJson;
  }
  final (m, _, _) = await loadedModel(api: a, connected: connected);
  return m;
}

/// 收奶後伺服器回的結果：[collected] 瓶進了倉庫，奶桶剩 [left]；倉庫滿了就是 warehouse_full。
class _CollectApi extends FakeGameApi {
  _CollectApi({required this.collected, required this.left, this.warehouseFull = false, required this.after})
    : super(state: ranchState(), market: ranchMarket());

  final double collected;
  final double left;
  final bool warehouseFull;
  final Map<String, dynamic> after;

  @override
  Future<Map<String, dynamic>> collect() async {
    calls.add('collect');
    stateJson = after;
    return {'collected': collected, 'spoiled': 0.0, 'warehouse_full': warehouseFull};
  }
}

final _zh = Strings.forLang(AppLang.zhHant);

/// 狀態表（設計稿的 .g-sheet）：沒有頂列、分頁列的頁面，內容一個個排下來。
Future<void> pumpSheet(WidgetTester tester, AppLang lang, List<Widget> children, {GameModel? model}) async {
  final m = model ?? await ranchModel();
  final settings = settingsFor(lang);
  await settings.load();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<GameModel>.value(value: m),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        Provider<Strings>.value(value: Strings.forLang(lang)),
      ],
      child: MaterialApp(
        theme: appTheme(),
        locale: lang.locale,
        supportedLocales: [for (final l in AppLang.values) l.locale],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          backgroundColor: AppColors.cream,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 4 + 8, 12, 16 + 8),
              child: Column(
                key: const Key('sheet'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, c) in children.indexed) ...[if (i > 0) const SizedBox(height: 12), c],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// G-02／G-03 的一個頂列（.g-hud：高 64，頂列在上面 6、左右跟內容區一樣留 12）。
Widget _hudRow(HudData d, {bool dot = false}) => SizedBox(
  height: 64,
  child: Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 6),
    child: Hud(data: d, gearDot: dot),
  ),
);

const _ranchHud = HudData(name: '晨光河畔牧場', level: 4, xp: 0.41, coins: 12480);

final s03Cases = <PageCase>[
  PageCase(
    'S03-01',
    '一般',
    (tester, lang) async => pumpAppIn(tester, await ranchModel(), lang, prefs: swipeHintSeen),
    check: (tester) {
      expect(find.text('晨光河畔牧場'), findsOneWidget);
      expect(find.text('Lv 4'), findsOneWidget);
      expect(find.text('12,480'), findsOneWidget, reason: '一百萬以下寫完整的數字');
      expect(find.text('87%'), findsOneWidget);
      expect(find.text(_zh.s03FullIn(time: _zh.duration(m: 9))), findsOneWidget, reason: '(42 − 36.4) ÷ 42 小時，進位到分鐘');
      expect(find.text('64%'), findsOneWidget, reason: '最舊一批牛奶的新鮮度');
      expect(find.text('12%'), findsOneWidget, reason: '牛奶比平常 +12%');
      expect(find.text('10 / 12'), findsOneWidget);
      expect(find.byKey(const Key('ticker')), findsOneWidget);
      // 場景裡有 8 頭牛：去田裡的 #2、#9 不在
      expect(find.byKey(const Key('scene-cow-2')), findsNothing);
      expect(find.byType(OfflinePill), findsNothing);
    },
  ),
  PageCase(
    'S03-02',
    '奶桶滿了',
    (tester, lang) async =>
        pumpAppIn(tester, await ranchModel(state: ranchState(bucket: 42)), lang, prefs: swipeHintSeen),
    check: (tester) {
      expect(find.byKey(const Key('bubble-full')), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text(_zh.s03FullStopped), findsOneWidget);
    },
  ),
  PageCase(
    'S03-03',
    '收奶成功',
    (tester, lang) async {
      final api = _CollectApi(
        collected: 36.4,
        left: 0,
        after: ranchState(
          bucket: 0,
          milkLots: [
            {'qty': 36.4, 'tier': 0, 'freshness': 1.0},
            {'qty': 60, 'tier': 0, 'freshness': 1.0},
            {'qty': 48, 'tier': 1, 'freshness': 0.82},
            {'qty': 22, 'tier': 3, 'freshness': 0.64},
          ],
        ),
      );
      await pumpAppIn(tester, await ranchModel(api: api), lang, prefs: swipeHintSeen);
      await tester.tap(find.byKey(const Key('collect')));
      await tester.pump();
      await tester.pump();
    },
    check: (tester) {
      expect(find.text(_zh.collected(v: '36.4')), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
    },
  ),
  PageCase(
    'S03-04',
    '倉庫滿了只收一部分',
    (tester, lang) async {
      final api = _CollectApi(
        collected: 24,
        left: 12.4,
        warehouseFull: true,
        after: ranchState(
          bucket: 12.4,
          milkLots: [
            {'qty': 24, 'tier': 0, 'freshness': 1.0},
            {'qty': 201, 'tier': 0, 'freshness': 0.9},
          ],
        ),
      );
      await pumpAppIn(tester, await ranchModel(api: api), lang, prefs: swipeHintSeen);
      await tester.tap(find.byKey(const Key('collect')));
      await tester.pump();
      await tester.pump();
    },
    check: (tester) {
      expect(find.text(_zh.s03Partial(n: '24', left: '12.4')), findsOneWidget);
      expect(find.byKey(const Key('go-upgrade')), findsOneWidget);
      expect(find.text(_zh.s03MilkFull), findsOneWidget);
    },
  ),
  PageCase(
    'S03-05',
    '奶桶是 0：收奶鈕停用',
    (tester, lang) async =>
        pumpAppIn(tester, await ranchModel(state: ranchState(bucket: 0)), lang, prefs: swipeHintSeen),
    crop: find.byKey(const Key('bucket-card')),
    check: (tester) {
      expect(tester.widget<AppButton>(find.byKey(const Key('collect'))).onPressed, isNull);
    },
  ),
  PageCase(
    'S03-08',
    '一頭牛都沒有',
    (tester, lang) async => pumpAppIn(
      tester,
      await ranchModel(state: ranchState(cows: [], bucket: 0, perHour: 0, penSlots: 10)),
      lang,
      prefs: swipeHintSeen,
    ),
    check: (tester) {
      expect(find.byKey(const Key('empty-ranch')), findsOneWidget);
      expect(find.text(_zh.s03NoMilkers), findsOneWidget);
      expect(find.text('0 / 10'), findsOneWidget);
    },
  ),
  PageCase(
    'S03-09',
    '數字最大、牛舍滿（量測用）',
    (tester, lang) async => pumpAppIn(
      tester,
      await ranchModel(
        state: ranchState(
          cows: herdOf(40),
          coins: 1234567,
          level: 14,
          levelProgress: {'earned': 960, 'level_at': 0, 'next_at': 1000},
          penSlots: 40,
          bucket: 12261,
          bucketCap: 12261,
          perHour: 1680,
          milkLots: [
            {'qty': 43786, 'tier': 0, 'freshness': 0.99},
          ],
          warehouseCap: 43786,
          beef: 12480,
          rice: 9860,
        ),
        market: ranchMarket(milk: 20.4, beef: 7.2, rice: 8.5),
      ),
      lang,
      prefs: swipeHintSeen,
    ),
    check: (tester) {
      expect(find.text('40 / 40'), findsOneWidget);
      expect(find.text(_zh.s03MilkFull), findsOneWidget);
      expect(find.text('70%'), findsNWidgets(2), reason: '牛奶、稻米比平常 +70%');
      expect(find.text('40%'), findsOneWidget, reason: '牛肉比平常 −40%');
    },
  ),
  PageCase(
    'S03-11',
    '收起來：奶桶、倉庫、收購價收成一條（收奶鈕留著）',
    (tester, lang) async =>
        pumpAppIn(tester, await ranchModel(), lang, prefs: {...swipeHintSeen, SettingsController.dockKey: '1'}),
    check: (tester) {
      expect(find.byKey(const Key('bucket-slim')), findsOneWidget);
      expect(find.byKey(const Key('storage-mini')), findsNothing);
      expect(find.byKey(const Key('collect')), findsOneWidget);
    },
  ),
  PageCase(
    'S03-12',
    '收起來的那一條：奶桶滿了、奶桶是 0',
    (tester, lang) async {
      final m = await ranchModel();
      final st = m.state!;
      DockData data(double qty) => DockData(
        bucket: qty,
        bucketCap: 42,
        perHour: 42,
        timeScale: 1,
        warehouse: st.warehouse,
        quotes: m.market!.quotes,
        upIsRed: true,
      );
      Widget slim(double qty) => Dock(
        data: data(qty),
        collapsed: true,
        pan: 0,
        onToggle: () {},
        collect: AppButton(
          Strings.forLang(lang).collect,
          kind: ButtonKind.blue,
          small: true,
          onPressed: qty > 0 ? () {} : null,
        ),
      );
      await pumpSheet(tester, lang, [slim(42), slim(0)], model: m);
    },
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.text(_zh.s03Full), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
    },
  ),
  PageCase(
    'S03-13',
    '往右滑：牧場的另一邊（池塘、大樹）',
    (tester, lang) async {
      await pumpAppIn(tester, await ranchModel(), lang, prefs: swipeHintSeen);
      await tester.drag(find.byType(RanchScene), const Offset(-1200, 0));
      await tester.pump();
    },
    check: (tester) {
      // 小滑塊在右半邊
      final bar = tester.getRect(find.byKey(const Key('pan-indicator')));
      final knob = tester.getRect(
        find.descendant(of: find.byKey(const Key('pan-indicator')), matching: find.byType(DecoratedBox)).last,
      );
      expect(knob.center.dx, greaterThan(bar.center.dx));
    },
  ),
  PageCase(
    'S03-14',
    '第一次打開牧場：提示可以左右滑動（只出現一次）',
    (tester, lang) async => pumpAppIn(tester, await ranchModel(), lang),
    check: (tester) {
      expect(find.byKey(const Key('swipe-hint')), findsOneWidget);
    },
  ),
  PageCase(
    'S03-15',
    '大新聞提示：收購價大漲（只跳出一次）',
    (tester, lang) async => pumpAppIn(
      tester,
      await ranchModel(
        market: ranchMarket(
          beef: 15.0,
          news: [
            {
              'id': 202,
              'code': 'beef_up.1',
              'params': {},
              'pct': 0.25,
              'commodity': 'beef',
              'targets': ['beef'],
              'direction': 'up',
              'big': true,
              'time': t0 - 60,
              'announce_at': t0 - 60,
              'start_at': t0 - 60,
              'end_at': t0 + 7200,
              'state': 'active',
            },
          ],
        ),
      ),
      lang,
      prefs: swipeHintSeen,
    ),
    crop: find.byKey(const Key('big-news')),
    check: (tester) {
      expect(find.byKey(const Key('big-news')), findsOneWidget);
      expect(find.text(_zh.s03BigNewsGo), findsOneWidget);
    },
  ),
  PageCase(
    'S15-01',
    '斷線、重連中：保留畫面、按鈕停用',
    (tester, lang) async => pumpAppIn(tester, await ranchModel(connected: false), lang, prefs: swipeHintSeen),
    check: (tester) {
      expect(find.byType(OfflinePill), findsOneWidget);
      expect(tester.widget<AppButton>(find.byKey(const Key('collect'))).onPressed, isNull);
    },
  ),
  PageCase(
    'G-01',
    '底部分頁列：6 個分頁各自選中',
    (tester, lang) async => pumpSheet(tester, lang, [
      for (final t in AppTab.values) SizedBox(height: 62, child: AppTabBar(active: t, bottomPadding: 0)),
    ]),
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.byType(AppTabBar), findsNWidgets(6));
      expect(find.text(_zh.tabRanch), findsNWidgets(6));
    },
  ),
  PageCase(
    'G-02',
    '頂列：牧場名、等級、經驗條、金幣、設定',
    (tester, lang) => pumpSheet(tester, lang, [_hudRow(_ranchHud)]),
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.text('12,480'), findsOneWidget);
      expect(find.byKey(const Key('gear-dot')), findsNothing);
    },
  ),
  PageCase(
    'G-03',
    '頂列：金幣很多、等級兩位數、剛開局、名字最長（量測用）',
    (tester, lang) => pumpSheet(tester, lang, [
      _hudRow(const HudData(name: '晨光河畔牧場', level: 14, xp: 0.96, coins: 999999)),
      _hudRow(const HudData(name: '晨光河畔牧場', level: 14, xp: 0.03, coins: 9876543)),
      _hudRow(const HudData(name: '晨光河畔牧場', level: 1, xp: 0, coins: 100)),
      _hudRow(const HudData(name: '晨光河畔牧場小屋', level: 4, xp: 0.41, coins: 12480)),
      _hudRow(const HudData(name: 'MorningRiverFarm', level: 4, xp: 0.41, coins: 12480)),
    ]),
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.text('999,999'), findsOneWidget, reason: '一百萬以下寫完整的數字');
      expect(find.text('987.6萬'), findsOneWidget, reason: '一百萬以上寫「萬」');
    },
  ),
  PageCase(
    'G-10',
    '頂列齒輪的小點：還沒備份牧場、也還沒打開過「備份牧場」頁',
    (tester, lang) => pumpSheet(tester, lang, [_hudRow(_ranchHud, dot: true)]),
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.byKey(const Key('gear-dot')), findsOneWidget);
    },
  ),
];

/// [n] 頭牛（量測用）：乳牛、耕牛、肉牛輪流，有公有母、有小牛，編號 1–n。
List<Map<String, dynamic>> herdOf(int n) {
  const breeds = [
    'holstein',
    'yellow',
    'angus',
    'jersey',
    'buffalo',
    'wagyu',
    'fluffyHolstein',
    'highland',
    'chocolate',
    'strawberry',
  ];
  return [
    for (var i = 1; i <= n; i++)
      designCow(
        i,
        breeds[i % breeds.length],
        bull: i % 3 == 0,
        stage: i % 7 == 0 ? 'calf' : 'adult',
        milk: breedInfo(breeds[i % breeds.length])!.type == CowType.dairy && i % 3 != 0 && i % 7 != 0 ? 14 : 0,
      ),
  ];
}

/// 只拍截圖、不算頁面 ID：牧場有 0、1、8、20、40 頭牛時的排法（ceo 2026-10-02），20、40 頭另外拍往右滑到底。
final herdShotCases = <PageCase>[
  for (final n in [0, 1, 8, 20, 40])
    PageCase(
      'herd-${n.toString().padLeft(2, '0')}',
      '牧場 $n 頭牛',
      (tester, lang) async => pumpAppIn(
        tester,
        await ranchModel(state: ranchState(cows: herdOf(n), penSlots: 40)),
        lang,
        prefs: swipeHintSeen,
      ),
    ),
  for (final n in [20, 40])
    PageCase('herd-$n-right', '牧場 $n 頭牛，往右滑到底', (tester, lang) async {
      await pumpAppIn(
        tester,
        await ranchModel(state: ranchState(cows: herdOf(n), penSlots: 40)),
        lang,
        prefs: swipeHintSeen,
      );
      await tester.drag(find.byType(RanchScene), const Offset(-1200, 0));
      await tester.pump();
    }),
];
