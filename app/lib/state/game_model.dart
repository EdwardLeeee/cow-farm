import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/game_api.dart';
import '../api/models.dart';
import '../api/push.dart';
import '../l10n/strings.dart';
import '../storage/token_store.dart';

/// 手機上的單調時鐘（秒）。不受使用者改手機時間影響，只用來推算畫面上的時間與奶桶。
typedef NowFn = double Function();

NowFn monotonicClock() {
  final sw = Stopwatch()..start();
  return () => sw.elapsedMicroseconds / 1e6;
}

class ActionResult<T> {
  const ActionResult.ok(this.value) : error = null;
  const ActionResult.fail(this.error) : value = null;
  final T? value;
  final String? error;
  bool get ok => error == null;
}

/// 分頁順序。
/// 底部分頁。配種裡有「自己配種／借種」，紀錄裡有「圖鑑／排行榜」。
enum AppTab { ranch, market, fields, breed, shop, records }

/// 整個 app 的狀態（ChangeNotifier）。
///
/// 規則：所有帳都由伺服器算。這裡只保存伺服器最後一次給的資料，並用單調時鐘推算
/// 「現在的遊戲時間」和「奶桶現在大概有多少」，純粹是顯示用，從來不送回伺服器。
class GameModel extends ChangeNotifier {
  GameModel({
    required this.api,
    required this.push,
    required this.tokens,
    NowFn? now,
    this.refreshEvery = const Duration(seconds: 5),
    this.marketRefreshEvery = const Duration(seconds: 30),
    this.uiTick = const Duration(milliseconds: 250),
  }) : _now = now ?? monotonicClock() {
    push.connected.addListener(_onConnectedChanged);
    _pushSub = push.messages.listen(_onPush);
  }

  final GameApi api;
  final PushClient push;
  final TokenStore tokens;
  final NowFn _now;
  final Duration refreshEvery;
  final Duration marketRefreshEvery;

  /// 畫面上倒數與奶桶多久重畫一次；測試設成 null 就不開計時器。
  final Duration? uiTick;

  StreamSubscription<PushMessage>? _pushSub;
  final _notices = StreamController<String>.broadcast();

  /// 要跳出來提示玩家的訊息（例如有人借了你的公牛）。
  Stream<String> get notices => _notices.stream;
  Timer? _stateTimer;
  Timer? _marketTimer;
  bool _disposed = false;

  // ---- 狀態 ----
  bool starting = false;
  String? startError;
  GameState? state;
  double _stateAt = 0; // 收到 state 時的單調時鐘
  String ranchName = '';
  MarketInfo? market;
  final Map<(Commodity, String), List<PricePoint>> history = {};

  bool _httpOk = true;
  bool busy = false;

  // ---- 畫面導覽 ----
  AppTab tab = AppTab.ranch;
  String? detailCowKey;
  String? breedSireKey;
  String? breedDamKey;
  String? lastCalfKey;

  bool get wsConnected => push.connected.value;

  /// 連著伺服器：已有牧場資料、WebSocket 連著、最近一次 HTTP 沒有失敗。
  bool get online => state != null && wsConnected && _httpOk;

  /// 按鈕能不能按：連著而且沒有正在處理的操作。
  bool get canAct => online && !busy;

  // ---------------------------------------------------------------------------
  // 啟動
  // ---------------------------------------------------------------------------
  /// 啟動：沒有 token 就建立訪客帳號，拿牧場與行情，連 WebSocket，開始定時校正。
  Future<void> start() async {
    await _boot();
    _stateTimer ??= Timer.periodic(refreshEvery, (_) {
      if (state == null) {
        _boot();
      } else {
        refreshState();
      }
    });
    _marketTimer ??= Timer.periodic(marketRefreshEvery, (_) => refreshMarket());
  }

  Future<void> _boot() async {
    if (starting) return;
    starting = true;
    startError = null;
    _notify();
    try {
      await _ensureSession();
      await _loadState();
      if (state == null) {
        throw const NetworkException('no state');
      }
      push.connect(api.token!);
      await refreshMarket();
    } on ApiException catch (e) {
      startError = e.message;
    } on NetworkException {
      startError = S.startFailed;
    } finally {
      starting = false;
      _notify();
    }
  }

  Future<void> _ensureSession() async {
    var token = await tokens.read(TokenStore.tokenKey);
    ranchName = await tokens.read(TokenStore.ranchKey) ?? ranchName;
    if (token == null || token.isEmpty) {
      final s = await api.createSession();
      token = s.token;
      ranchName = s.ranchName;
      await tokens.write(TokenStore.tokenKey, s.token);
      await tokens.write(TokenStore.ranchKey, s.ranchName);
    }
    api.token = token;
  }

  /// 伺服器不認得 token（例如資料庫重建）：丟掉舊的，重新建立訪客帳號。
  /// HTTP 401 和 WebSocket 4401 可能同時發生，只建立一次。
  Future<void> _resetSession() => _resetting ??= _doResetSession().whenComplete(() => _resetting = null);
  Future<void>? _resetting;

  Future<void> _doResetSession() async {
    await tokens.delete(TokenStore.tokenKey);
    await tokens.delete(TokenStore.ranchKey);
    api.token = null;
    await _ensureSession();
    push.connect(api.token!);
  }

  Future<void> _loadState() async {
    try {
      _setState(await api.getState());
      _httpOk = true;
    } on ApiException catch (e) {
      if (!e.unauthorized) rethrow;
      await _resetSession();
      _setState(await api.getState());
      _httpOk = true;
    }
  }

  void _setState(GameState s) {
    state = s;
    _stateAt = _now();
    if (s.ranchName != null && s.ranchName!.isNotEmpty) ranchName = s.ranchName!;
  }

  /// 重新拿 /v1/state 校正（每次操作後、以及每幾秒一次）。
  Future<void> refreshState() async {
    if (api.token == null) return;
    try {
      await _loadState();
    } on ApiException {
      // 保留舊資料，下次再試。
    } on NetworkException {
      _httpOk = false;
    }
    _notify();
  }

  Future<void> refreshMarket() async {
    if (api.token == null) return;
    try {
      final m = await api.market();
      // 保留推播來的較新新聞
      market = m;
      for (final c in Commodity.values) {
        history[(c, '1d')] ??= m.recent[c] ?? const [];
      }
      _httpOk = true;
    } on ApiException {
      // 忽略
    } on NetworkException {
      _httpOk = false;
    }
    _notify();
  }

  // ---------------------------------------------------------------------------
  // 推播
  // ---------------------------------------------------------------------------
  void _onConnectedChanged() {
    if (push.connected.value) {
      // 重連後補一次快照。
      refreshState();
      refreshMarket();
    }
    _notify();
  }

  void _onPush(PushMessage msg) {
    switch (msg) {
      case MarketPush(:final quotes, :final serverTime):
        final m = market;
        market = m == null
            ? MarketInfo(quotes: quotes, recent: const {}, news: const [])
            : m.copyWith(quotes: {...m.quotes, ...quotes});
        if (serverTime != null) {
          for (final e in quotes.entries) {
            final key = (e.key, '1h');
            final list = history[key];
            if (list == null) continue;
            final pts = [...list, PricePoint(serverTime, e.value.price)];
            pts.removeWhere((p) => p.t < serverTime - 3600);
            history[key] = pts;
          }
        }
      case PushAuthFailed(:final token):
        if (api.token == token) {
          _resetSession().then((_) => refreshState()).catchError((Object _) {});
        } else if (api.token != null) {
          push.connect(api.token!); // 已經換過 token 了
        }
      case StudPush(:final price):
        // 有人借了我上架的公牛：提示一則，並重抓 state（金幣、公牛狀態都變了）。
        _notices.add(S.studBorrowedNotice(price.round().toString()));
        refreshState();
      case NewsPush(:final item):
        final m = market;
        if (m != null && !m.news.any((n) => n.id == item.id)) {
          market = m.copyWith(news: [item, ...m.news]);
        }
    }
    _notify();
  }

  // ---------------------------------------------------------------------------
  // 顯示用推算（不送回伺服器）
  // ---------------------------------------------------------------------------
  /// 現在的遊戲時間（Unix 秒）= 伺服器最後給的 server_time + 手機單調時鐘經過的時間 × 倍率。
  double get gameNow {
    final s = state;
    if (s == null) return 0;
    return s.serverTime + (_now() - _stateAt) * s.timeScale;
  }

  double get timeScale => state?.timeScale ?? 1;

  /// 奶桶現在大概有多少（瓶）：用伺服器給的量與每小時產量平滑推算，滿了就停。
  double get bucketNow {
    final s = state;
    if (s == null) return 0;
    return s.bucket.amountAfter(s.serverTime, gameNow - s.serverTime);
  }

  // ---------------------------------------------------------------------------
  // 導覽
  // ---------------------------------------------------------------------------
  void selectTab(AppTab t) {
    tab = t;
    detailCowKey = null;
    _notify();
  }

  void openCow(String key) {
    detailCowKey = key;
    _notify();
  }

  void closeCow() {
    detailCowKey = null;
    _notify();
  }

  void selectForBreeding(Cow cow) {
    if (cow.bull) {
      breedSireKey = cow.key;
    } else {
      breedDamKey = cow.key;
    }
    detailCowKey = null;
    tab = AppTab.breed;
    _notify();
  }

  void setBreedSire(String? key) {
    breedSireKey = key;
    _notify();
  }

  void setBreedDam(String? key) {
    breedDamKey = key;
    _notify();
  }

  // ---------------------------------------------------------------------------
  // 操作（會改變狀態；結果一律以伺服器為準，做完重新拿 state 校正）
  // ---------------------------------------------------------------------------
  Future<ActionResult<T>> _act<T>(Future<T> Function() f) async {
    if (!canAct) return const ActionResult.fail(S.connecting);
    busy = true;
    _notify();
    ActionResult<T> r;
    try {
      r = ActionResult.ok(await f());
      _httpOk = true;
    } on ApiException catch (e) {
      if (e.unauthorized) await _resetSession();
      r = ActionResult.fail(e.message);
    } on NetworkException {
      _httpOk = false;
      r = const ActionResult.fail(S.networkError);
    }
    await refreshState();
    busy = false;
    _notify();
    return r;
  }

  Future<ActionResult<Map<String, dynamic>>> collect() => _act(api.collect);

  Future<ActionResult<SellResult>> sell(Commodity c, double qty) async {
    final r = await _act(() => api.sell(c, qty));
    if (r.ok) unawaited(refreshMarket());
    return r;
  }

  Future<ActionResult<ShipResult>> ship(Cow cow) async {
    final r = await _act(() => api.ship(cow.id));
    if (r.ok && detailCowKey == cow.key) detailCowKey = null;
    _notify();
    return r;
  }

  /// 商店抽牛（v0.2）。
  Future<ActionResult<ShopBuyResult>> shopBuy(String grade) => _act(() => api.shopBuy(grade));

  Future<ActionResult<Map<String, dynamic>>> fieldAssign(Cow cow, {int? field}) =>
      _act(() => api.fieldAssign(cow.id, field: field));
  Future<ActionResult<Map<String, dynamic>>> fieldRecall(Cow cow) => _act(() => api.fieldRecall(cow.id));
  Future<ActionResult<Map<String, dynamic>>> fieldHarvest() => _act(api.fieldHarvest);
  Future<ActionResult<Map<String, dynamic>>> fieldExpand() => _act(api.fieldExpand);

  Future<ActionResult<Map<String, dynamic>>> studList(Cow bull, double price) => _act(() => api.studList(bull.id, price));
  Future<ActionResult<Map<String, dynamic>>> studUnlist(Object listingId) => _act(() => api.studUnlist(listingId));

  Future<ActionResult<BreedResult>> studBorrow(StudListing listing, Cow dam) async {
    final r = await _act(() => api.studBorrow(listing.id, dam.id));
    if (r.ok) {
      lastCalfKey = r.value?.calf?.key;
      _notify();
    }
    return r;
  }

  Future<ActionResult<BreedResult>> breed(Cow sire, Cow dam) async {
    final r = await _act(() => api.breed(sire.id, dam.id));
    if (r.ok) {
      lastCalfKey = r.value?.calf?.key;
      _notify();
    }
    return r;
  }

  Future<ActionResult<Map<String, dynamic>>> upgrade(UpgradeKind kind) => _act(() => api.upgrade(kind));

  // ---------------------------------------------------------------------------
  // 查詢（不改變狀態）
  // ---------------------------------------------------------------------------
  Future<T?> _read<T>(Future<T> Function() f) async {
    try {
      final v = await f();
      if (!_httpOk) {
        _httpOk = true;
        _notify();
      }
      return v;
    } on ApiException {
      return null;
    } on NetworkException {
      _httpOk = false;
      _notify();
      return null;
    }
  }

  Future<SellQuote?> quote(Commodity c, double qty) => _read(() => api.sellQuote(c, qty));

  Future<BreedPreview?> breedPreview(Cow sire, Cow dam) => _read(() => api.breedPreview(sire.id, dam.id));

  Future<Leaderboard?> leaderboard(RankKind kind) => _read(() => api.leaderboard(kind));

  Future<ShipPreview?> shipPreview(Cow cow) => _read(() => api.shipPreview(cow.id));
  Future<ShopInfo?> shopInfo() => _read(api.shop);
  Future<StudMarket?> studMarket() => _read(api.stud);
  Future<BreedPreview?> studPreview(StudListing listing, Cow dam) => _read(() => api.studPreview(listing.id, dam.id));

  /// 田裡現在大概有多少稻米（顯示用推算，長滿就停）。
  double fieldRiceNow(FieldInfo f) {
    final s = state;
    if (s == null) return f.rice;
    return f.riceAfter(gameNow - s.serverTime);
  }

  Future<void> loadHistory(Commodity c, String range) async {
    final pts = await _read(() => api.marketHistory(c, range));
    if (pts != null) {
      history[(c, range)] = pts;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stateTimer?.cancel();
    _marketTimer?.cancel();
    _pushSub?.cancel();
    push.connected.removeListener(_onConnectedChanged);
    push.close();
    _notices.close();
    super.dispose();
  }
}
