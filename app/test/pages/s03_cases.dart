// S03 牧場（設計稿 boards/S03-牧場）和頂列、分頁列、牛的標籤（G-01、G-02、G-03、G-07、G-10）的畫面狀態，S15-01 斷線。
// 假資料照設計稿 design/m2/src/js/fixtures.js：10 頭牛（2 頭去田裡）、奶桶 36.4／42、倉庫、收購價、第一則新聞。
import 'package:cowfarm/api/breeds.dart';
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/auth/sign_in.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/state/settings.dart';
import 'package:cowfarm/theme/app_theme.dart';
import 'package:cowfarm/theme/tokens.dart';
import 'package:cowfarm/ui/kit/cow_bits.dart';
import 'package:cowfarm/ui/kit/frame.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:cowfarm/ui/ranch/dock.dart';
import 'package:cowfarm/ui/ranch/ranch_game.dart';
import 'package:cowfarm/ui/ranch/ranch_page.dart';
import 'package:cowfarm/ui/ranch/scene.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../fakes.dart';
import 'page_case.dart';

/// 一頭牛（協定 2.3 的形狀），品種照設計稿指定；用途、稀有度從品種表來。
/// [value] 出貨估值、[rice] 在田裡每小時的稻米、[fee] 上架借種的借種費、[growMin] 小牛還要幾分鐘長大（時鐘倍率 1）。
Map<String, dynamic> designCow(
  int id,
  String breed, {
  bool bull = false,
  String stage = 'adult',
  double milk = 0,
  double kg = 200,
  double value = 2000,
  int? field,
  double rice = 11,
  Object? listed,
  int? fee,
  bool bred = false,
  int growMin = 42,
}) {
  final info = breedInfo(breed)!;
  final adult = stage != 'calf';
  return {
    'id': id,
    'type': info.type.wire,
    'bull': bull,
    // v0.3 C1（協定 2.3）：小牛的品種、稀有度長大才揭曉，伺服器送 null（[breed] 只用來決定用途）
    'tier': adult ? info.tier : null,
    'breed': adult ? breed : null,
    'stage': stage,
    'born_at': t0 - 36000,
    'age_h': 10.0,
    'adult_at': adult ? t0 - 3600 : t0 + growMin * 60,
    'milk_per_h': milk,
    'milk_frac': milk > 0 ? 1.0 : 0.0,
    'weight_kg': adult ? kg : 0,
    'beef_quality': 1.0,
    'ship_value': adult ? value : 0,
    'bred': bred,
    'working': field != null,
    'field': field,
    'listed': listed,
    'can_breed': adult && !bred && field == null && listed == null,
    'can_ship': adult && field == null && listed == null,
    'can_work': info.type == CowType.dual && adult && field == null && listed == null,
    'rice_per_h': field != null ? rice : 0,
    'grade_probs': adult ? {'A': 0.4, 'B': 0.44, 'C': 0.16} : null,
    'origin': 'start',
    'stud_fee': fee == null ? null : {'price': fee, 'per_kg': 1.1, 'kg': kg, 'at_max': false},
    'hybrid': false,
    'need': const <String>[],
    'ate': const <String>[],
    'missed': const <String>[],
  };
}

/// 設計稿的 10 頭牛（fixtures.js 的 COWS）：#2 耕牛、#9 高地牛在田裡，場景裡看不到；#5 上架借種。
List<Map<String, dynamic>> designCows() => [
  designCow(3, 'holstein', milk: 14, kg: 212, value: 2514),
  designCow(7, 'jersey', milk: 14, kg: 196, value: 3102),
  designCow(12, 'strawberry', milk: 14, kg: 174, value: 5520),
  designCow(15, 'holstein', stage: 'calf'),
  designCow(2, 'yellow', bull: true, kg: 431, value: 5108, field: 0, rice: 11),
  designCow(9, 'highland', kg: 377, value: 5832, field: 2, rice: 14.3),
  designCow(5, 'angus', bull: true, kg: 790, value: 9420, listed: 7, fee: 870),
  designCow(11, 'wagyu', kg: 612, value: 10024),
  designCow(8, 'holstein', bull: true, stage: 'old', kg: 268, value: 2810, bred: true),
  designCow(14, 'jersey', bull: true, kg: 205, value: 3240),
];

/// 設計稿 S03-25 的雜種牛（fixtures.js 的 MIX_COW）：#20 乳牛、母，小時候要吃苜蓿、沒吃到，長大變成雜種牛
/// （伺服器照樣送原本的稀有度，畫面不顯示）。[calf] 是長大前、還是小牛的時候。
Map<String, dynamic> mixCow({bool calf = false}) => calf
    ? {
        ...designCow(20, 'holstein', stage: 'calf'),
        'need': ['alfalfa'],
      }
    : {
        ...designCow(20, 'holstein', milk: 14, kg: 206, value: 1466),
        'breed': 'hybrid',
        'tier': 2,
        'hybrid': true,
        'need': ['alfalfa'],
        'missed': ['alfalfa'],
      };

/// 設計稿的 10 頭牛，旁邊一共 [n] 坨大便：照牛的編號一頭一坨分下去（場景裡排在設計稿的第 0–(n − 1) 個位置）。
List<Map<String, dynamic>> poopCows(int n) {
  final herd = designCows()..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
  return [
    for (var i = 0; i < herd.length; i++) {...herd[i], 'poop': n ~/ herd.length + (i < n % herd.length ? 1 : 0)},
  ];
}

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
    'economy': {
      'tier_mult': [1.0, 1.3, 1.7, 2.5],
      'beef_grade_mult': {'A': 1.25, 'B': 1.0, 'C': 0.75},
      'ox_rice_per_h': 11.0,
      'field_cap_h': 8.0,
      'hybrid_mult': 0.6, // v0.3 C1：雜種牛的倍數（協定 2.3）
      // v0.3 C1 照顧（協定 2.3、2.6）
      'cure_price': 5000,
      'sick_beef_mult': 0.1,
      'poop_max_per_cow': 4,
      'sick_dirt_free': 0.5,
    },
    // 全場的大便 = 每頭牛的 poop 加起來；髒的程度 = 大便 ÷ 牛的頭數（協定 2.3）
    'poop': () {
      final total = herd.fold<int>(0, (n, c) => n + ((c['poop'] as num?)?.toInt() ?? 0));
      return {'total': total, 'dirt': herd.isEmpty ? 0.0 : total / herd.length, 'safe_until': null};
    }(),
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

/// 收奶：奶桶的 36.4 瓶全部進倉庫（設計稿：倉庫 130 → 166 瓶）。
class CollectApi extends FakeGameApi {
  CollectApi() : super(state: ranchState(), market: ranchMarket());

  @override
  Future<Map<String, dynamic>> collect() async {
    calls.add('collect');
    final bucket = Map<String, dynamic>.of(stateJson['bucket'] as Map<String, dynamic>);
    final got = (bucket['qty'] as num).toDouble();
    final wh = Map<String, dynamic>.of(stateJson['warehouse'] as Map<String, dynamic>);
    final total = (wh['milk_total'] as num) + got;
    stateJson = {
      ...stateJson,
      'bucket': {...bucket, 'qty': 0},
      'warehouse': {
        ...wh,
        'milk_total': total,
        'used': total,
        'milk_lots': [
          ...(wh['milk_lots'] as List),
          {'qty': got, 'tier': 0, 'freshness': 1.0},
        ],
      },
    };
    return {'collected': got};
  }
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

/// 載好設計稿牧場的模型（連線中、時鐘固定）。[signIn] 給了就是設好 Apple／Google 登入的建置（[signInPlatform]）。
Future<GameModel> ranchModel({
  Map<String, dynamic>? state,
  Map<String, dynamic>? market,
  FakeGameApi? api,
  bool connected = true,
  SignInService? signIn,
  SignInPlatform signInPlatform = SignInPlatform.iphone,
  PrefsStore? prefs,
}) async {
  final a = api ?? FakeGameApi(state: state ?? ranchState(), market: market ?? ranchMarket());
  if (api != null) {
    a.stateJson = state ?? a.stateJson;
    a.marketJson = market ?? a.marketJson;
  }
  final (m, _, _) = await loadedModel(
    api: a,
    connected: connected,
    signIn: signIn,
    signInPlatform: signInPlatform,
    prefs: prefs,
  );
  return m;
}

/// 右上角的大便數（「大便 9」）。
String dirtText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('dirt-count'))).textSpan!.toPlainText();

/// 名片的位置（ranch_page.dart 的 RenderPopPlacer）：從名片往上找。
RenderPopPlacer popPlacer(WidgetTester tester) {
  RenderObject? r = tester.renderObject(find.byKey(const Key('cow-pop')));
  while (r != null && r is! RenderPopPlacer) {
    r = r.parent;
  }
  return r! as RenderPopPlacer;
}

/// 收奶後伺服器回的結果：[collected] 瓶進了倉庫，奶桶剩 [left]；倉庫滿了就是 warehouse_full。
class _CollectApi extends FakeGameApi {
  _CollectApi({
    required this.collected,
    required this.left,
    this.warehouseFull = false,
    this.spoiled = 0,
    required this.after,
  }) : super(state: ranchState(), market: ranchMarket());

  final double collected;
  final double left;
  final bool warehouseFull;

  /// 順便丟掉幾瓶壞掉的牛奶（S03-18）。
  final double spoiled;
  final Map<String, dynamic> after;

  @override
  Future<Map<String, dynamic>> collect() async {
    calls.add('collect');
    stateJson = after;
    return {'collected': collected, 'spoiled': spoiled, 'warehouse_full': warehouseFull};
  }
}

/// 全部商品一起大漲（[up]）或大跌的大新聞（S03-16、17）：commodity 是 null、targets 三種。
Map<String, dynamic> _allNews(bool up) => {
  'id': up ? 301 : 302,
  'code': up ? 'all_up.1' : 'all_down.1',
  'params': {},
  'pct': up ? 0.22 : -0.21,
  'commodity': null,
  'targets': ['milk', 'beef', 'rice'],
  'direction': up ? 'up' : 'down',
  'big': true,
  'time': t0 - 60,
  'announce_at': t0 - 60,
  'start_at': t0 - 60,
  'end_at': t0 + 7200,
  'state': 'active',
};

/// 超級大事件（[tier] super，+100%）、超級黑天鵝（crash，−90%）的新聞（D33），一分鐘前開始。[commodity] null 是三種一起。
Map<String, dynamic> _superNews(int id, String code, String? commodity, {required String tier}) => {
  'id': id,
  'code': code,
  'params': {},
  'pct': tier == 'super' ? 1.0 : -0.9,
  'commodity': commodity,
  'targets': commodity == null ? ['milk', 'beef', 'rice'] : [commodity],
  'direction': tier == 'super' ? 'up' : 'down',
  'big': true,
  'tier': tier,
  'time': t0 - 60,
  'announce_at': t0 - 60,
  'start_at': t0 - 60,
  'end_at': t0 + 7200,
  'state': 'active',
};

final _zh = Strings.forLang(AppLang.zhHant);

/// 狀態表（設計稿的 .g-sheet）：沒有頂列、分頁列的頁面，內容一個個排下來。
/// [padding] 是整張表的邊距（設計稿的 .g-sheet：左右 12、上 12、下 24；S11-03 的表右邊多留 12 給 ×）。
Future<void> pumpSheet(
  WidgetTester tester,
  AppLang lang,
  List<Widget> children, {
  GameModel? model,
  EdgeInsets padding = const EdgeInsets.fromLTRB(12, 4 + 8, 12, 16 + 8),
}) async {
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
              padding: padding,
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

/// G-02／G-03、S11-04 的一個頂列（.g-hud：高 64，頂列在上面 6、左右跟內容區一樣留 12）。
Widget hudRow(HudData d, {bool dot = false}) => SizedBox(
  height: 64,
  child: Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 6),
    child: Hud(data: d, gearDot: dot),
  ),
);

const _ranchHud = HudData(name: '晨光河畔牧場', level: 4, xp: 0.41, coins: 12480);

/// 牧場場景裡畫牛的 Flame 遊戲（A-11、A-07）。
RanchGame ranchGame(WidgetTester tester) =>
    tester.widget<GameWidget<RanchGame>>(find.byType(GameWidget<RanchGame>)).game!;

/// 場景裡那頭牛現在畫在螢幕的哪裡；不在場景裡（去田裡了）是 null。
Rect? sceneCowRect(WidgetTester tester, Object id) =>
    ranchGame(tester).cowRect(id)?.shift(tester.getTopLeft(find.byType(RanchScene)));

/// 點場景裡的那頭牛：牛畫在 Flame 裡，照它現在的位置點（前面有別頭牛擋住就是點到那頭）。
Future<void> tapSceneCow(WidgetTester tester, Object id) => tester.tapAt(sceneCowRect(tester, id)!.center);

/// 場景裡那頭牛現在用的圖（檔名有 _front_ 就是轉正面）。
String sceneCowAsset(WidgetTester tester, Object id) => 'assets/cows/svg/${ranchGame(tester).artOf(id)}.svg';

/// 從牧場頁按「我的牛」打開牛舍清單（S03-07）。
Future<void> openPenList(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('pen-pill')));
  await tester.pump();
}

/// G-07 的一行（.g-line）：左邊 48 寬的小字說明（設計稿的註記，不翻譯），後面一排標籤。
Widget _badgeLine(String note, List<Widget> chips) => Wrap(
  spacing: 6,
  runSpacing: 6,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: [
    SizedBox(
      width: 48,
      child: Text(
        note,
        style: AppText.style(12, weight: FontWeight.w700, color: AppColors.ink2),
      ),
    ),
    ...chips,
  ],
);

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
      expect(ranchGame(tester).cowRect(2), isNull);
      expect(ranchGame(tester).cowRect(9), isNull);
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
    'S03-06',
    '點一頭牛：轉正面、跳出小名片',
    (tester, lang) async {
      await pumpAppIn(tester, await ranchModel(), lang, prefs: swipeHintSeen);
      await tapSceneCow(tester, 12);
      await tester.pump();
    },
    check: (tester) {
      final pop = find.byKey(const Key('cow-pop'));
      expect(pop, findsOneWidget);
      expect(find.descendant(of: pop, matching: find.text(_zh.cowName('strawberry', 12))), findsOneWidget);
      // 稀有度是星星（#170）：傳說 4 顆
      expect(
        find.descendant(of: pop, matching: find.byWidgetPredicate((w) => w is TierChip && w.tier == 3)),
        findsOneWidget,
      );
      expect(find.text(_zh.s03PopMilk(tier: _zh.tierName(3), n: '14')), findsOneWidget);
      expect(find.byKey(const Key('pop-detail')), findsOneWidget);
      // 前排放得下：照原本的放法，頭頂上方、尖角朝下對準牛頭（D30 不改 S03-06）
      expect(popPlacer(tester).below, isFalse);
      expect(popPlacer(tester).tip, 34);
      expect(sceneCowAsset(tester, 12), contains('_front_'), reason: '被點到的牛轉正面');
      expect(sceneCowAsset(tester, 3), contains('_side_'), reason: '其他的牛不變');
    },
  ),
  PageCase(
    'S03-07',
    '牛舍清單（長頁）',
    (tester, lang) async {
      await pumpAppIn(tester, await ranchModel(), lang, prefs: swipeHintSeen);
      await openPenList(tester);
      await growToFit(tester, find.byKey(const Key('pen-list')));
    },
    check: (tester) {
      expect(find.text(_zh.cowsTitle), findsOneWidget);
      expect(find.text(_zh.penSummary(used: 10, slots: 12)), findsOneWidget);
      expect(find.byKey(const Key('expand-pen')), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(Key('filter-$i')), findsOneWidget);
      }
      for (final id in [3, 7, 12, 15, 2, 9, 5, 11, 8, 14]) {
        expect(find.byKey(Key('cow-$id')), findsOneWidget);
      }
      final sep = _zh.gSep;
      expect(find.text('${_zh.milkRate(v: '14')}$sep${_zh.weight(v: '212')}'), findsOneWidget);
      expect(find.text(_zh.growUp(v: _zh.countdown(42 * 60))), findsOneWidget);
      expect(find.text(_zh.s03MetaField(n: 1, rate: '11')), findsOneWidget);
      expect(find.text(_zh.s03MetaField(n: 3, rate: '14.3')), findsOneWidget);
      expect(find.text(_zh.s03MetaListed(price: '870')), findsOneWidget);
      expect(find.text('${_zh.weight(v: '612')}$sep${_zh.s03MetaValue(v: '10,024')}'), findsOneWidget);
      // #8：乳牛、公、一般、老牛、已配種
      final row8 = find.byKey(const Key('cow-8'));
      for (final t in [_zh.stageOld, _zh.badgeBred, _zh.bull]) {
        expect(find.descendant(of: row8, matching: find.text(t)), findsOneWidget);
      }
      expect(
        find.descendant(of: row8, matching: find.byWidgetPredicate((w) => w is TierChip && w.tier == 0)),
        findsOneWidget,
      );
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
    'S03-10',
    '耕牛在田裡：清單顯示「工作中」、場景裡看不到',
    (tester, lang) async {
      await pumpAppIn(tester, await ranchModel(), lang, prefs: swipeHintSeen);
      await openPenList(tester);
      // 篩選「耕牛」：只剩在田裡的 #2、#9（設計稿這塊也只畫這兩列）
      await tester.tap(find.byKey(const Key('filter-2')));
      await tester.pump();
    },
    crop: find.byKey(const Key('pen-rows')),
    check: (tester) {
      final rows = find.byKey(const Key('pen-rows'));
      expect(find.descendant(of: rows, matching: find.byType(CowRow)), findsNWidgets(2));
      expect(find.descendant(of: rows, matching: find.text(_zh.badgeWorking)), findsNWidgets(2));
      expect(find.text(_zh.s03MetaField(n: 1, rate: '11')), findsOneWidget);
      expect(find.text(_zh.s03MetaField(n: 3, rate: '14.3')), findsOneWidget);
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
              'big': false, // 只看幅度 ≥ 20%，不看 big（ceo 2026-10-02）
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
  for (final up in [true, false])
    PageCase(
      up ? 'S03-16' : 'S03-17',
      up ? '大新聞提示：全部商品一起大漲' : '大新聞提示：全部商品一起大跌',
      (tester, lang) async => pumpAppIn(
        tester,
        await ranchModel(market: ranchMarket(news: [_allNews(up)])),
        lang,
        prefs: swipeHintSeen,
      ),
      crop: find.byKey(const Key('big-news')),
      check: (tester) {
        expect(find.byKey(const Key('big-news')), findsOneWidget);
        expect(find.textContaining(_zh.s03BigNewsAll(chg: up ? '+22%' : '−21%'), findRichText: true), findsOneWidget);
      },
    ),
  // D33 超級大事件、超級黑天鵝的提示（狀態表 M2-S03-超級事件-狀態表）：跟大新聞提示同一個位置、一樣大，換顏色和標籤
  for (final (id, name, market, tier, body) in [
    (
      'S03-22',
      '超級大事件提示：牛肉收購價 +100%',
      ranchMarket(beef: 24, news: [_superNews(401, 'beef_super.1', 'beef', tier: 'super')]),
      'super',
      _zh.s03BigNewsBody(
        name: _zh.commodity(Commodity.beef),
        chg: '+100%',
        price: '24',
        unit: _zh.unitOf(Commodity.beef),
      ),
    ),
    (
      'S03-23',
      '超級黑天鵝提示：牛奶收購價 −90%',
      ranchMarket(milk: 1.2, news: [_superNews(402, 'milk_swan.1', 'milk', tier: 'crash')]),
      'crash',
      _zh.s03BigNewsBody(
        name: _zh.commodity(Commodity.milk),
        chg: '−90%',
        price: '1.2',
        unit: _zh.unitOf(Commodity.milk),
      ),
    ),
    (
      'S03-24',
      '超級大事件提示：全部商品一起 +100%',
      ranchMarket(milk: 24, beef: 24, rice: 10, news: [_superNews(403, 'all_super.1', null, tier: 'super')]),
      'super',
      _zh.s03BigNewsAll(chg: '+100%'),
    ),
  ])
    PageCase(
      id,
      name,
      (tester, lang) async => pumpAppIn(tester, await ranchModel(market: market), lang, prefs: swipeHintSeen),
      crop: find.byKey(const Key('big-news')),
      check: (tester) {
        expect(find.byKey(const Key('big-news')), findsOneWidget);
        expect(find.byKey(Key('tier-$tier')), findsOneWidget);
        expect(find.text(_zh.s06BigNews), findsNothing);
        expect(find.textContaining(body, findRichText: true), findsOneWidget);
      },
    ),
  PageCase(
    'S03-18',
    '收奶成功，順便丟掉壞掉的牛奶',
    (tester, lang) async {
      final api = _CollectApi(
        collected: 36.4,
        left: 0,
        spoiled: 2,
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
    crop: find.byKey(const Key('toast')),
    check: (tester) {
      expect(find.text(_zh.collectedSpoiled(v: '36.4', n: '2')), findsOneWidget);
    },
  ),
  PageCase(
    'S03-20',
    '點後排的牛：上面放不下，名片放到牛的下面、尖角朝上',
    (tester, lang) async {
      await pumpAppIn(tester, await ranchModel(), lang, prefs: swipeHintSeen);
      await tapSceneCow(tester, 14);
      await tester.pump();
    },
    check: (tester) {
      final p = popPlacer(tester);
      expect(p.below, isTrue, reason: '頭頂上方放不下（會碰到頂列）');
      expect(p.tip, 34, reason: '名片沒被擋，尖角在原本的位置');
      final pop = tester.getRect(find.byKey(const Key('cow-pop')));
      expect(pop.top, greaterThan(sceneCowRect(tester, 14)!.center.dy));
      // 公牛的名片寫體重（ceo 2026-10-02，照 D30 狀態表）
      expect(find.text(_zh.weight(v: '205')), findsOneWidget);
    },
  ),
  PageCase(
    'S03-21',
    '點後排的牛（右邊那頭）：一樣放到牛的下面',
    (tester, lang) async {
      await pumpAppIn(tester, await ranchModel(), lang, prefs: swipeHintSeen);
      await tapSceneCow(tester, 8);
      await tester.pump();
    },
    check: (tester) {
      final p = popPlacer(tester);
      expect(p.below, isTrue);
      expect(p.tip, greaterThan(34), reason: '名片被擋在畫面裡，尖角往右移到對準那頭牛');
      // 狀態標籤照留（scope.md S03-06：品種、稀有度、狀態）
      final pop = find.byKey(const Key('cow-pop'));
      expect(find.descendant(of: pop, matching: find.text(_zh.stageOld)), findsOneWidget);
      expect(find.text(_zh.weight(v: '268')), findsOneWidget);
    },
  ),
  PageCase(
    'S03-26',
    '牧場有大便：右上角出現大便數',
    (tester, lang) async => pumpAppIn(
      tester,
      await ranchModel(state: ranchState(cows: poopCows(4))),
      lang,
      prefs: swipeHintSeen,
    ),
    check: (tester) {
      expect(dirtText(tester), '${_zh.s03Poop} 4');
      expect(find.text(_zh.s03PoopDanger), findsNothing, reason: '4 ÷ 10 頭 = 0.4，還不會生病');
      // 設計稿的第 0–3 個位置
      for (var i = 0; i < 9; i++) {
        expect(find.byKey(Key('poop-$i')), i < 4 ? findsOneWidget : findsNothing, reason: '第 $i 個位置');
      }
    },
  ),
  PageCase(
    'S03-27',
    '太髒了：大便數變紅「會生病」',
    (tester, lang) async => pumpAppIn(
      tester,
      await ranchModel(state: ranchState(cows: poopCows(9))),
      lang,
      prefs: swipeHintSeen,
    ),
    check: (tester) {
      expect(dirtText(tester), '${_zh.s03Poop} 9');
      expect(find.text(_zh.s03PoopDanger), findsOneWidget, reason: '9 ÷ 10 頭 = 0.9 > 0.5');
      for (var i = 0; i < 9; i++) {
        expect(find.byKey(Key('poop-$i')), findsOneWidget, reason: '第 $i 個位置');
      }
    },
  ),
  PageCase(
    'S03-25',
    '小牛長大揭曉：變成雜種牛（A-13 的結尾）',
    // 設計稿：S03-01 的牧場，小乳牛 #20 長大了、變成雜種牛（設計稿的 #20 不算在牛舍 10／12 裡；app 的 #20 排在場景
    // 右半邊，看不到）。先收到 #20 還是小牛的 state，下一次收到長大了的
    (tester, lang) async {
      final api = FakeGameApi(
        state: ranchState(cows: [...designCows(), mixCow(calf: true)], penUsed: 10),
        market: ranchMarket(),
      );
      final m = await ranchModel(api: api);
      api.stateJson = ranchState(cows: [...designCows(), mixCow()], penUsed: 10);
      await m.refreshState();
      await pumpAppIn(tester, m, lang, prefs: swipeHintSeen);
    },
    check: (tester) {
      expect(find.byKey(const Key('grow-reveal')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('grow-title'))).data,
        _zh.animGrownUp(cow: _zh.calfName(CowType.dairy, 20)),
      );
      expect(find.text(_zh.cowName('hybrid', 20)), findsOneWidget);
      final name = find.byKey(const Key('grow-name'));
      expect(find.descendant(of: name, matching: find.byType(MixStarChip)), findsOneWidget);
      expect(find.descendant(of: name, matching: find.text(_zh.badgeMix)), findsOneWidget);
      expect(find.text(_zh.animMixGrown(feeds: _zh.feedList(['alfalfa']))), findsOneWidget);
      expect(find.text(_zh.animMixHint(mult: '0.6')), findsOneWidget);
      expect(find.byKey(const Key('grow-ok')), findsOneWidget);
      expect(find.byKey(const Key('grow-skip')), findsNothing, reason: '雜種牛按「好」關，沒有「點一下跳過」');
      expect(find.text('10 / 12'), findsOneWidget);
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
    (tester, lang) => pumpSheet(tester, lang, [hudRow(_ranchHud)]),
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
      hudRow(const HudData(name: '晨光河畔牧場', level: 14, xp: 0.96, coins: 999999)),
      hudRow(const HudData(name: '晨光河畔牧場', level: 14, xp: 0.03, coins: 9876543)),
      hudRow(const HudData(name: '晨光河畔牧場', level: 1, xp: 0, coins: 100)),
      hudRow(const HudData(name: '晨光河畔牧場小屋', level: 4, xp: 0.41, coins: 12480)),
      hudRow(const HudData(name: 'MorningRiverFarm', level: 4, xp: 0.41, coins: 12480)),
    ]),
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.text('999,999'), findsOneWidget, reason: '一百萬以下寫完整的數字');
      expect(find.text('987.6萬'), findsOneWidget, reason: '一百萬以上寫「萬」');
    },
  ),
  PageCase(
    'G-07',
    '牛的標籤：用途、稀有度、狀態',
    (tester, lang) {
      final s = Strings.forLang(lang);
      return pumpSheet(tester, lang, [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _badgeLine('用途', const [
                UseChip(CowType.dairy),
                UseChip(CowType.dual),
                UseChip(CowType.beef),
                SexText(bull: true),
                SexText(bull: false),
              ]),
              const SizedBox(height: 8),
              // 稀有度是星星（#170）：一般 1～傳說 4 顆、特殊牛 5 顆彩虹星、雜種牛 1 顆灰星
              _badgeLine('稀有度', [for (var t = 0; t < 5; t++) TierChip(t), const MixStarChip()]),
              const SizedBox(height: 8),
              _badgeLine('狀態', [
                CowBadge(BadgeKind.calf, s.stageCalf),
                CowBadge(BadgeKind.old, s.stageOld),
                CowBadge(BadgeKind.working, s.badgeWorking),
                CowBadge(BadgeKind.listed, s.badgeListed),
                CowBadge(BadgeKind.bred, s.badgeBred),
              ]),
            ],
          ),
        ),
      ]);
    },
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.byType(UseChip), findsNWidgets(3));
      expect(find.byType(TierChip), findsNWidgets(5));
      expect(find.byType(MixStarChip), findsOneWidget);
      expect(find.byType(CowBadge), findsNWidgets(5));
      expect(find.text(_zh.badgeListed), findsOneWidget);
    },
  ),
  PageCase(
    'G-10',
    '頂列齒輪的小點：還沒備份牧場、也還沒打開過「備份牧場」頁',
    (tester, lang) => pumpSheet(tester, lang, [hudRow(_ranchHud, dot: true)]),
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
