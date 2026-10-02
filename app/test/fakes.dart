import 'dart:async';

import 'package:cowfarm/api/breeds.dart';
import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/api/push.dart';
import 'package:cowfarm/app.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/state/settings.dart';
import 'package:cowfarm/storage/token_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 遊戲時間基準：2026-10-01 12:00 台灣時間。
const t0 = 1790827200.0;

/// 稀有度 → 一種特徵組合（協定 1.6：稀有度 = 位元數），用來挑品種。
const _bitsForTier = [0, 1, 3, 7];

Map<String, dynamic> _cow(
  int id,
  String type,
  bool bull,
  int tier, {
  String stage = 'adult',
  double milk = 0,
  double weight = 100,
  double shipValue = 1000,
  double? adultAt,
  bool bred = false,
  int? field,
  Object? listed,
  double ricePerH = 0,
  String origin = 'start',
}) {
  final adult = stage != 'calf';
  final busy = field != null || listed != null;
  return {
    'id': id,
    'type': type,
    'bull': bull,
    'tier': tier,
    'breed': kBreedsByType[CowType.parse(type)]![_bitsForTier[tier]],
    'stage': stage,
    'born_at': t0 - (adult ? 36000 : 1800),
    'age_h': adult ? 10.0 : 0.5,
    'adult_at': adultAt ?? (adult ? t0 - 36000 : t0 + 3600),
    'milk_per_h': milk,
    'milk_frac': milk > 0 ? 1.0 : 0.0,
    'weight_kg': adult ? weight : 0,
    'beef_quality': 1.0,
    'ship_value': adult ? shipValue : 0,
    'bred': bred,
    'working': field != null,
    'field': field,
    'listed': listed,
    'can_breed': adult && !bred && !busy,
    'can_ship': adult && !busy,
    'can_work': type == 'dual' && adult && !busy,
    'rice_per_h': ricePerH,
    'grade_probs': adult ? {'A': 0.137323, 'B': 0.492535, 'C': 0.370142} : null,
    'origin': origin,
    'stud_fee': bull && adult && !bred
        ? {'price': ((weight * 1.1 / 10).round() * 10), 'per_kg': 1.1, 'kg': weight, 'at_max': false}
        : null,
  };
}

/// 剛建好的牧場（伺服器 cowecon/params.py 的 OnboardingParams）：100 幣、奶桶裡 20 瓶、開局 1 小時產奶 ×5，
/// 送一頭成年母乳牛（#1）和一頭還要 20 分鐘長大的公耕牛小牛（#2）。倍率 1（正式版），倒數就是現實時間。
Map<String, dynamic> newRanchStateJson() => {
  ...sampleStateJson(coins: 100),
  'time_scale': 1,
  'level': 1,
  'level_progress': {'earned': 0, 'level_at': 0, 'next_at': 500},
  'ranch_name': '小花的快樂牧場',
  'cows': [
    _cow(1, 'dairy', false, 0, milk: 6.0, weight: 120, shipValue: 1440),
    _cow(2, 'dual', true, 0, stage: 'calf', adultAt: t0 + 20 * 60),
  ],
  'bucket': {
    'qty': 20.0,
    'capacity': 24.0,
    'per_hour': 30.0,
    'boost': {'mult': 5.0, 'until': t0 + 3600},
  },
  'codex': [
    {'breed': 'holstein', 'found_at': t0},
    {'breed': 'yellow', 'found_at': t0},
  ],
};

/// 牧場物件（協定 1.6）。
Map<String, dynamic> ranchJson({int? id, String? name, List<int>? words, int? level = 3}) => {
  'player_id': id,
  'name': name,
  'name_words': words,
  'is_bot': name == null,
  'level': level,
};

/// 協定 v2 的 /v1/state（形狀照 docs/protocol.md 2.3）。
/// 牛：#1 母乳牛、#2 公耕牛（優良）、#3 母肉牛小牛、#4 母耕牛（在第 1 塊田工作）、#5 母乳牛（已配種）。
Map<String, dynamic> sampleStateJson({double coins = 1500, bool penFull = false, bool bullListed = false}) => {
  'server_time': t0,
  'real_time': 1790000000.0,
  'time_scale': 144,
  'coins': coins,
  'level': 3,
  'level_progress': {'earned': 2400, 'level_at': 1500, 'next_at': 3500},
  'player_id': 31,
  'ranch_name': '晨光草原牧場',
  'cows': [
    _cow(1, 'dairy', false, 0, milk: 14.0, weight: 120, shipValue: 1440),
    _cow(2, 'dual', true, 1, weight: 200, shipValue: 3120, listed: bullListed ? 9 : null),
    _cow(3, 'beef', false, 2, stage: 'calf', origin: 'B'),
    _cow(4, 'dual', false, 0, weight: 150, field: 0, ricePerH: 11.0),
    _cow(5, 'dairy', false, 0, milk: 14.0, bred: true),
  ],
  'bucket': {'qty': 6.0, 'capacity': 24.0, 'per_hour': 12.0, 'boost': null},
  'warehouse': {
    'capacity': 150,
    'used': 150.5,
    'milk_total': 150.5,
    'beef_total': 300,
    'rice_total': 20,
    'milk_lots': [
      {'qty': 100, 'tier': 0, 'freshness': 1.0},
      {'qty': 50.5, 'tier': 0, 'freshness': 0.8},
    ],
    'beef_lots': [
      {'qty': 300, 'tier': 0, 'grade': 'B'},
    ],
    'rice_lots': [
      {'qty': 20, 'quality': 1.0},
    ],
  },
  'pen': {'slots': penFull ? 5 : 6, 'used': 5, 'next_cost': 420, 'next_open_at': null, 'max_slots': 40},
  'upgrades': {
    'pen': {'level': 1, 'cost': 420, 'next_open_at': null, 'slots': 6, 'next_slots': 7},
    'bucket': {'level': 0, 'cost': 200, 'capacity': 24, 'next_capacity': 36},
    'warehouse': {'level': 0, 'cost': 5000, 'capacity': 150, 'next_capacity': 225},
    'fresh': {'level': 4, 'cost': null, 'fresh_h': 18, 'half_h': 96, 'next_fresh_h': null, 'next_half_h': null},
    'field': {'level': 1, 'cost': 2880, 'count': 2, 'max': 12},
  },
  'codex': [
    {'breed': 'holstein', 'found_at': t0 - 36000},
    {'breed': 'highland', 'found_at': t0 - 30000},
  ],
  'shop': {
    'grades': [
      {'grade': 'A', 'price': 3200},
      {'grade': 'B', 'price': 1700},
      {'grade': 'C', 'price': 900},
    ],
  },
  'fields': [
    {'index': 0, 'cow_id': 4, 'rice': 33.0, 'capacity': 88.0, 'per_hour': 11.0},
    {'index': 1, 'cow_id': null, 'rice': 0.0, 'capacity': null, 'per_hour': 0.0},
  ],
  'rice': {'in_fields': 33.0, 'stock': 20.0, 'per_hour': 11.0},
  'stud': {
    'listings': [
      if (bullListed)
        {
          'id': 9,
          'breed': 'highland',
          'type': 'dual',
          'tier': 1,
          'owner': ranchJson(id: 31, name: '晨光草原牧場'),
          'is_mine': true,
          'cow_id': 2,
          'listed_at': t0 - 600,
          'fee': {'price': 550, 'per_kg': 2.75, 'kg': 200.0, 'at_max': false},
        },
    ],
    'income': 1100,
  },
  'account': {'links': []},
  'maintenance': null,
};

Map<String, dynamic> sampleMarketJson({double milkChange = 0.5, double beefChange = -0.8, double riceChange = 0.2}) => {
  'server_time': t0,
  'milk': {
    'price': 10.5,
    'change_24h': milkChange,
    'change_24h_pct': milkChange / (10.5 - milkChange),
    'ma24': 10.2,
    'base_price': 12.0,
    'ratio': 10.5 / 12,
  },
  'beef': {
    'price': 11.2,
    'change_24h': beefChange,
    'change_24h_pct': beefChange / (11.2 - beefChange),
    'ma24': 11.8,
    'base_price': 12.0,
    'ratio': 11.2 / 12,
  },
  'rice': {
    'price': 5.2,
    'change_24h': riceChange,
    'change_24h_pct': riceChange / (5.2 - riceChange),
    'ma24': 5.05,
    'base_price': 5.0,
    'ratio': 5.2 / 5,
  },
  'news': [
    _news(1, 'milk_up.1', 'milk', 'up', 0.18, t0 - 600),
    _news(2, 'beef_down.1', 'beef', 'down', -0.12, t0 - 300),
    _news(3, 'rice_up.1', 'rice', 'up', 0.08, t0 - 200),
  ],
};

Map<String, dynamic> _news(int id, String code, String commodity, String dir, double pct, double t) => {
  'id': id,
  'code': code,
  'params': {},
  'pct': pct,
  'commodity': commodity,
  'targets': [commodity],
  'direction': dir,
  'big': false,
  'time': t,
  'announce_at': t,
  'start_at': t,
  'end_at': t + 36000,
  'state': 'active',
};

/// GET /v1/market/history（走勢；D24 第一版用不到，M1 的走勢圖還在用）。
final sampleHistory = <String, List<List<double>>>{
  'milk': [
    [t0 - 7200, 10.0],
    [t0 - 3600, 10.3],
    [t0, 10.5],
  ],
  'beef': [
    [t0 - 7200, 12.0],
    [t0, 11.2],
  ],
  'rice': [
    [t0 - 7200, 5.0],
    [t0, 5.2],
  ],
};

Map<String, dynamic> _shopGrade(String g, int price, double rare) => {
  'grade': g,
  'price': price,
  'tier_probs': [1 - rare, rare * 0.8, rare * 0.15, rare * 0.05],
  'type_probs': {'dairy': 0.45, 'dual': 0.275, 'beef': 0.275},
  'bull_prob': 0.5,
};

/// 假資料層：記錄呼叫，回傳固定資料。
class FakeGameApi implements GameApi {
  FakeGameApi({Map<String, dynamic>? state, Map<String, dynamic>? market})
    : stateJson = state ?? sampleStateJson(),
      marketJson = market ?? sampleMarketJson();

  Map<String, dynamic> stateJson;
  Map<String, dynamic> marketJson;
  final calls = <String>[];

  /// 試算：均價 = 市價 × (1 − 0.0005 × qty)，qty 大時折扣變多。
  double quotePrice = 10.0;

  @override
  String? token;

  /// 建立牧場時伺服器回的錯誤（例如 invalid_name）；null 就成功。
  ApiException? sessionError;

  /// /v1/status 的 maintenance（null：沒有安排維護）。
  Maintenance? maintenance;

  /// 設了就讓 /v1/status、/v1/state、/v1/market 丟這個錯（例如 503 maintenance、連不上）。
  Exception? statusError;
  Exception? stateError;
  Exception? marketError;

  /// 設了就讓 /v1/market 等到 complete 才回（測試「補抓完才提示」）。
  Completer<void>? marketGate;

  @override
  Future<Session> createSession(String ranchName) async {
    calls.add('session:$ranchName');
    if (sessionError != null) throw sessionError!;
    return Session(
      token: 'tok-new',
      playerId: 31,
      ranchName: ranchName.trim(),
      state: GameState.fromJson({...stateJson, 'ranch_name': ranchName.trim()}),
    );
  }

  @override
  Future<ServerStatus> status() async {
    calls.add('status');
    if (statusError != null) throw statusError!;
    return ServerStatus(protocol: 2, maintenance: maintenance);
  }

  @override
  Future<GameState> getState() async {
    calls.add('state');
    if (stateError != null) throw stateError!;
    return GameState.fromJson(stateJson);
  }

  @override
  Future<Map<String, dynamic>> collect() async {
    calls.add('collect');
    return {'collected': 6.0};
  }

  @override
  Future<SellQuote> sellQuote(Commodity commodity, double qty) async {
    calls.add('quote:${commodity.wire}:$qty');
    final avg = quotePrice * (1 - 0.0005 * qty);
    return SellQuote(qty: qty, avgPrice: avg, total: avg * qty, marketPrice: quotePrice);
  }

  @override
  Future<SellResult> sell(Commodity commodity, double qty) async {
    calls.add('sell:${commodity.wire}:$qty');
    return SellResult(qty: qty, avgPrice: 9.9, total: 9.9 * qty, priceAfter: 9.8);
  }

  @override
  Future<ShipResult> ship(Object cowId) async {
    calls.add('ship:$cowId');
    return const ShipResult(
      grade: 'A',
      gradeProbs: {'A': 0.137323, 'B': 0.492535, 'C': 0.370142},
      beefQty: 120,
      valueEstimate: 1800,
    );
  }

  @override
  Future<ShipPreview> shipPreview(Object cowId) async {
    calls.add('ship-preview:$cowId');
    return const ShipPreview(
      gradeProbs: {'A': 0.137323, 'B': 0.492535, 'C': 0.370142},
      gradeMult: {'A': 1.25, 'B': 1.0, 'C': 0.75},
      valueByGrade: {'A': 1800, 'B': 1440, 'C': 1080},
      expectedValue: 1440,
      weightKg: 120,
    );
  }

  @override
  Future<ShopInfo> shop() async {
    calls.add('shop');
    return ShopInfo.fromJson({
      'free_slots': 1,
      'grades': [_shopGrade('A', 3200, 0.5), _shopGrade('B', 1700, 0.3), _shopGrade('C', 900, 0.1)],
    });
  }

  @override
  Future<ShopBuyResult> shopBuy(String grade) async {
    calls.add('shop-buy:$grade');
    return ShopBuyResult(
      grade: grade,
      cow: Cow.fromJson(_cow(6, 'beef', true, 2, stage: 'calf', origin: grade)),
      cost: 900,
    );
  }

  @override
  Future<BreedPreview> breedPreview(Object sire, Object dam) async {
    calls.add('preview:$sire:$dam');
    return const BreedPreview(
      tierProbs: [0.5625, 0.375, 0.0625, 0],
      typeProbs: {CowType.dairy: 0.5, CowType.dual: 0.5},
      bullProb: 0.5,
    );
  }

  @override
  Future<BreedResult> breed(Object sire, Object dam) async {
    calls.add('breed:$sire:$dam');
    return BreedResult(
      calf: Cow(
        id: 9,
        type: CowType.dual,
        bull: false,
        tier: 1,
        breed: 'highland',
        stage: CowStage.calf,
        adultAt: t0 + 7200,
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> upgrade(UpgradeKind kind) async {
    calls.add('upgrade:${kind.wire}');
    return {};
  }

  @override
  Future<Map<String, dynamic>> fieldAssign(Object cowId, {int? field}) async {
    calls.add('field-assign:$cowId:$field');
    return {'cow_id': cowId, 'field': field ?? 1};
  }

  @override
  Future<Map<String, dynamic>> fieldRecall(Object cowId) async {
    calls.add('field-recall:$cowId');
    return {'cow_id': cowId, 'field': 0};
  }

  @override
  Future<Map<String, dynamic>> fieldHarvest() async {
    calls.add('field-harvest');
    return {'harvested': 33.0};
  }

  @override
  Future<Map<String, dynamic>> fieldExpand() async {
    calls.add('field-expand');
    return {'kind': 'field', 'cost': 2880};
  }

  /// 借種市場（協定 4.1）：公營種牛站的 300 幣乳牛、電腦牧場的 1,160 幣肉牛。
  List<Map<String, dynamic>> studListings = [
    {
      'id': 1,
      'breed': 'holstein',
      'type': 'dairy',
      'tier': 0,
      'owner': ranchJson(words: [3, 5, 0], level: null),
      'is_mine': false,
      'cow_id': null,
      'listed_at': t0 - 3600,
      'fee': {'price': 300, 'per_kg': 1.1, 'kg': 275.0, 'at_max': true},
    },
    {
      'id': 5,
      'breed': 'galloway',
      'type': 'beef',
      'tier': 1,
      'owner': ranchJson(id: 3, words: [8, 0, 5], level: 6),
      'is_mine': false,
      'cow_id': 12,
      'listed_at': t0 - 600,
      'fee': {'price': 1160, 'per_kg': 2.75, 'kg': 420.5, 'at_max': false},
    },
  ];

  /// 借種紀錄（GET /v1/stud/log 的回應）。
  Map<String, dynamic> studLogJson = {'keep_days': 30, 'income_total': 1100, 'entries': []};

  @override
  Future<StudLog> studLog() async {
    calls.add('stud-log');
    return StudLog.fromJson(studLogJson);
  }

  @override
  Future<StudMarket> stud() async {
    calls.add('stud');
    return StudMarket.fromJson({'listings': studListings, 'mine': []});
  }

  @override
  Future<BreedPreview> studPreview(Object listingId, Object dam) async {
    calls.add('stud-preview:$listingId:$dam');
    final fee = studListings.firstWhere((l) => '${l['id']}' == '$listingId')['fee'];
    return BreedPreview(
      tierProbs: const [0.75, 0.25, 0, 0],
      fee: StudFee.fromJson(fee),
      typeProbs: const {CowType.dual: 1.0},
      bullProb: 0.5,
    );
  }

  @override
  Future<Map<String, dynamic>> studList(Object cowId) async {
    calls.add('stud-list:$cowId');
    return {};
  }

  @override
  Future<Map<String, dynamic>> studUnlist(Object listingId) async {
    calls.add('stud-unlist:$listingId');
    return {};
  }

  @override
  Future<BreedResult> studBorrow(Object listingId, Object dam, {required int price}) async {
    calls.add('stud-borrow:$listingId:$dam:$price');
    return BreedResult(
      calf: Cow(
        id: 10,
        type: CowType.dual,
        bull: true,
        tier: 1,
        breed: 'highland',
        stage: CowStage.calf,
        adultAt: t0 + 7200,
      ),
    );
  }

  @override
  Future<MarketInfo> market() async {
    calls.add('market');
    if (marketGate != null) await marketGate!.future;
    if (marketError != null) throw marketError!;
    return MarketInfo.fromJson(marketJson);
  }

  @override
  Future<List<PricePoint>> marketHistory(Commodity commodity, String range) async {
    calls.add('history:${commodity.wire}:$range');
    return PricePoint.listFrom(sampleHistory[commodity.wire]);
  }

  @override
  Future<Leaderboard> leaderboard(RankKind kind) async {
    calls.add('rank:${kind.wire}');
    return Leaderboard(
      entries: [
        RankEntry(rank: 1, ranch: RanchRef.fromJson(ranchJson(id: 3, words: [8, 0, 5], level: 6)), score: 52000),
        RankEntry(rank: 2, ranch: RanchRef.fromJson(ranchJson(id: 31, name: '晨光草原牧場')), score: 31000, isMe: true),
        RankEntry(rank: 3, ranch: RanchRef.fromJson(ranchJson(id: 4, words: [0, 1, 0], level: 2)), score: 20000),
      ],
      me: RankEntry(rank: 2, ranch: RanchRef.fromJson(ranchJson(id: 31, name: '晨光草原牧場')), score: 31000, isMe: true),
    );
  }
}

/// 假推播：測試直接控制連線狀態與訊息。
class FakePush implements PushClient {
  FakePush({bool connected = true}) : _connected = ValueNotifier(connected);
  final ValueNotifier<bool> _connected;
  final _ctrl = StreamController<PushMessage>.broadcast();
  String? token;
  int connects = 0;
  int closes = 0;

  @override
  ValueListenable<bool> get connected => _connected;

  set isConnected(bool v) => _connected.value = v;

  @override
  Stream<PushMessage> get messages => _ctrl.stream;

  void emit(PushMessage m) => _ctrl.add(m);

  @override
  void connect(String token) {
    connects++;
    this.token = token;
  }

  /// 跟正式的推播一樣：關掉就是斷線。
  @override
  void close() {
    closes++;
    _connected.value = false;
  }
}

/// 可控制的單調時鐘。
class FakeClock {
  double t = 1000;
  double call() => t;
}

/// 建好模型並載入假資料（不開計時器）。
/// [uiTick]：畫面多久重畫一次（倒數、奶桶）；預設 null 不重畫，測試要自己觸發。
Future<(GameModel, FakeGameApi, FakePush)> loadedModel({
  FakeGameApi? api,
  bool connected = true,
  FakeClock? clock,
  Duration? uiTick,
}) async {
  final a = api ?? FakeGameApi();
  final p = FakePush(connected: connected);
  final c = clock ?? FakeClock();
  final m = GameModel(
    api: a,
    push: p,
    tokens: MemoryTokenStore({TokenStore.tokenKey: 'tok'}),
    now: c.call,
    uiTick: uiTick,
  );
  await m.refreshState(); // token 還沒設時不會動作
  a.token = 'tok';
  await m.refreshState();
  await m.refreshMarket();
  return (m, a, p);
}

/// 繁中的設定。測試環境的手機語言是英文，M1 的畫面測試比對繁中的字，所以固定用繁中。
SettingsController zhSettings() =>
    SettingsController(MemoryPrefsStore(), deviceLocales: () => const [Locale('zh', 'TW')]);

/// 把 app 放進 430×932（iPhone 14 Pro Max 的邏輯尺寸）。
Future<void> pumpApp(WidgetTester tester, GameModel m) async {
  tester.view.physicalSize = const Size(430 * 3, 932 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(CowFarmApp(model: m, settings: zhSettings()));
  await tester.pump();
}
