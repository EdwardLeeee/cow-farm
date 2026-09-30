import 'dart:async';

import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/api/push.dart';
import 'package:cowfarm/app.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/storage/token_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 遊戲時間基準：2026-10-01 12:00 台灣時間。
const t0 = 1790827200.0;

Map<String, dynamic> sampleStateJson({double coins = 1500, bool penFull = false}) => {
  'server_time': t0,
  'real_time': 1790000000.0,
  'time_scale': 144,
  'coins': coins,
  'level': 3,
  'ranch_name': '晨光草原牧場',
  'cows': [
    {
      'id': 1,
      'type': 'dairy',
      'bull': false,
      'tier': 0,
      'stage': 'adult',
      'age_h': 10,
      'milk_per_h': 11.0,
      'weight_kg': 120,
      'ship_value': 1440,
      'adult_at': t0 - 36000,
      'ready_at': t0 - 1,
    },
    {
      'id': 2,
      'type': 'dual',
      'bull': true,
      'tier': 1,
      'stage': 'adult',
      'age_h': 5,
      'milk_per_h': 0,
      'weight_kg': 200,
      'ship_value': 3120,
      'adult_at': t0 - 18000,
      'ready_at': t0 - 1,
    },
    {
      'id': 3,
      'type': 'beef',
      'bull': false,
      'tier': 2,
      'stage': 'calf',
      'age_h': 0.5,
      'milk_per_h': 0,
      'weight_kg': 0,
      'adult_at': t0 + 3600,
    },
  ],
  // 形狀照伺服器 backend/server/views.py
  'bucket': {'qty': 6.0, 'capacity': 24.0, 'per_hour': 12.0, 'boost': null},
  'warehouse': {
    'capacity': 150,
    'used': 150.5,
    'milk_total': 150.5,
    'beef_total': 300,
    'milk_lots': [
      {'qty': 100, 'tier': 0, 'freshness': 1.0},
      {'qty': 50.5, 'tier': 0, 'freshness': 0.8},
    ],
    'beef_lots': [
      {'qty': 300, 'tier': 0},
    ],
  },
  'pen': {'slots': penFull ? 3 : 4, 'used': 3, 'next_cost': 420, 'next_open_at': null, 'max_slots': 40},
  'upgrades': {
    'pen': {'level': 1, 'cost': 420, 'next_open_at': null, 'slots': 4, 'next_slots': 5},
    'bucket': {'level': 0, 'cost': 200, 'capacity': 24, 'next_capacity': 36},
    'warehouse': {'level': 0, 'cost': 5000, 'capacity': 150, 'next_capacity': 225},
    'fresh': {'level': 4, 'cost': null, 'fresh_h': 18, 'half_h': 96, 'next_fresh_h': null, 'next_half_h': null},
  },
  'codex': [
    {'type': 'dairy', 'tier': 0},
    {'type': 'dual', 'tier': 1},
  ],
  'shop': {
    'calf_price': {'dairy': 1000, 'dual': 1000, 'beef': 1000},
  },
  'breed': {'first_free': false},
};

Map<String, dynamic> sampleMarketJson({double milkChange = 0.5, double beefChange = -0.8}) => {
  'server_time': t0,
  'milk': {
    'price': 10.5,
    'change_24h': milkChange,
    'change_24h_pct': milkChange / (10.5 - milkChange),
    'ma24': 10.2,
    'history': [
      [t0 - 7200, 10.0],
      [t0 - 3600, 10.3],
      [t0, 10.5],
    ],
  },
  'beef': {
    'price': 11.2,
    'change_24h': beefChange,
    'change_24h_pct': beefChange / (11.2 - beefChange),
    'ma24': 11.8,
    'history': [
      [t0 - 7200, 12.0],
      [t0, 11.2],
    ],
  },
  'news': [
    {'id': 'n1', 'title': '學校午餐加訂鮮奶', 'commodity': 'milk', 'direction': 'up', 'time': t0 - 600},
    {'id': 'n2', 'title': '進口牛肉到港量創新高', 'commodity': 'beef', 'direction': 'down', 'time': t0 - 300},
  ],
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

  @override
  Future<Session> createSession() async {
    calls.add('session');
    return const Session(token: 'tok-new', playerId: 'p1', ranchName: '晨光草原牧場');
  }

  @override
  Future<GameState> getState() async {
    calls.add('state');
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
  Future<Map<String, dynamic>> ship(Object cowId) async {
    calls.add('ship:$cowId');
    return {};
  }

  @override
  Future<Map<String, dynamic>> buyCalf(CowType type, bool bull) async {
    calls.add('buy:${type.wire}:$bull');
    return {};
  }

  @override
  Future<BreedPreview> breedPreview(Object sire, Object dam) async {
    calls.add('preview:$sire:$dam');
    return const BreedPreview(tierProbs: [0.5625, 0.375, 0.0625, 0], fee: 600);
  }

  @override
  Future<BreedResult> breed(Object sire, Object dam) async {
    calls.add('breed:$sire:$dam');
    return BreedResult(
      calf: Cow(id: 9, type: CowType.dual, bull: false, tier: 1, stage: CowStage.calf, adultAt: t0 + 7200),
    );
  }

  @override
  Future<Map<String, dynamic>> upgrade(UpgradeKind kind) async {
    calls.add('upgrade:${kind.wire}');
    return {};
  }

  @override
  Future<MarketInfo> market() async {
    calls.add('market');
    return MarketInfo.fromJson(marketJson);
  }

  @override
  Future<List<PricePoint>> marketHistory(Commodity commodity, String range) async {
    calls.add('history:${commodity.wire}:$range');
    return PricePoint.listFrom(marketJson[commodity.wire]['history']);
  }

  @override
  Future<Leaderboard> leaderboard(RankKind kind) async {
    calls.add('rank:${kind.wire}');
    return Leaderboard(
      entries: [
        const RankEntry(rank: 1, name: '北坡牧場', score: 52000, isBot: true),
        const RankEntry(rank: 2, name: '晨光草原牧場', score: 31000, isMe: true),
        const RankEntry(rank: 3, name: '電腦 河谷牧場', score: 20000, isBot: true),
      ],
      me: const RankEntry(rank: 2, name: '晨光草原牧場', score: 31000, isMe: true),
    );
  }
}

/// 假推播：測試直接控制連線狀態與訊息。
class FakePush implements PushClient {
  FakePush({bool connected = true}) : _connected = ValueNotifier(connected);
  final ValueNotifier<bool> _connected;
  final _ctrl = StreamController<PushMessage>.broadcast();
  String? token;

  @override
  ValueListenable<bool> get connected => _connected;

  set isConnected(bool v) => _connected.value = v;

  @override
  Stream<PushMessage> get messages => _ctrl.stream;

  void emit(PushMessage m) => _ctrl.add(m);

  @override
  void connect(String token) => this.token = token;

  @override
  void close() {}
}

/// 可控制的單調時鐘。
class FakeClock {
  double t = 1000;
  double call() => t;
}

/// 建好模型並載入假資料（不開計時器）。
Future<(GameModel, FakeGameApi, FakePush)> loadedModel({
  FakeGameApi? api,
  bool connected = true,
  FakeClock? clock,
}) async {
  final a = api ?? FakeGameApi();
  final p = FakePush(connected: connected);
  final c = clock ?? FakeClock();
  final m = GameModel(api: a, push: p, tokens: MemoryTokenStore({TokenStore.tokenKey: 'tok'}), now: c.call, uiTick: null);
  await m.refreshState(); // token 還沒設時不會動作
  a.token = 'tok';
  await m.refreshState();
  await m.refreshMarket();
  return (m, a, p);
}

/// 把 app 放進 430×932（iPhone 14 Pro Max 的邏輯尺寸）。
Future<void> pumpApp(WidgetTester tester, GameModel m) async {
  tester.view.physicalSize = const Size(430 * 3, 932 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(CowFarmApp(model: m));
  await tester.pump();
}
