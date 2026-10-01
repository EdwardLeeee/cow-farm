import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/game_api.dart';
import '../api/models.dart';
import '../api/push.dart';
import '../storage/token_store.dart';

/// 手機上的單調時鐘（秒）。不受使用者改手機時間影響，只用來推算畫面上的時間與奶桶。
typedef NowFn = double Function();

NowFn monotonicClock() {
  final sw = Stopwatch()..start();
  return () => sw.elapsedMicroseconds / 1e6;
}

/// 操作失敗的原因。給玩家看的字由畫面依目前的語言查字串表（ui/widgets/action_button.dart 的 actionErrorText），
/// GameModel 不放任何給玩家看的文字。
sealed class ActionError {
  const ActionError();
}

/// 伺服器回的錯誤（協定 1.4）：畫面用錯誤碼查文案，不顯示伺服器的 message。
class ApiActionError extends ActionError {
  const ApiActionError(this.error);
  final ApiException error;
}

/// 重送幾次後仍然連不上（networkError）。
class NetworkActionError extends ActionError {
  const NetworkActionError();
}

/// 現在斷線或正在處理別的操作，沒有送出（connecting）。
class OfflineActionError extends ActionError {
  const OfflineActionError();
}

class ActionResult<T> {
  const ActionResult.ok(this.value) : error = null;
  const ActionResult.fail(ActionError this.error) : value = null;
  final T? value;
  final ActionError? error;
  bool get ok => error == null;
}

/// 要跳出來提示玩家的事（G-05）。字由畫面組。
sealed class GameNotice {
  const GameNotice();
}

/// 有人借了我上架的公牛（WS stud）：「{cow} 借給 {ranch}，收到 {price} 幣」。
class StudBorrowedNotice extends GameNotice {
  const StudBorrowedNotice({this.cowId, this.breed, this.borrower, required this.price});
  final Object? cowId;
  final String? breed;
  final RanchRef? borrower;
  final double price;
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
  final _notices = StreamController<GameNotice>.broadcast();

  /// 要跳出來提示玩家的事（例如有人借了你的公牛）。
  Stream<GameNotice> get notices => _notices.stream;
  Timer? _stateTimer;
  Timer? _marketTimer;
  bool _disposed = false;

  // ---- 狀態 ----
  bool starting = false;
  ActionError? startError;

  /// 手機上還沒有牧場（沒有 token）：要先取名（S02），用 [createRanch] 建立。協定 2.1：取好名字才建立。
  bool needsRanch = false;

  /// token 失效的原因：unauthorized（S15-03）或 signed_in_elsewhere（S14-05）。null 代表正常。
  /// 不會自動開新牧場（M1 會默默換成新牧場，scope.md 第 10 節第 9 項）。
  String? authLost;
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
  /// 啟動：有 token 就拿牧場與行情、連 WebSocket、開始定時校正；沒有 token 就停在「還沒有牧場」（S02 取名）。
  Future<void> start() async {
    await _boot();
    _stateTimer ??= Timer.periodic(refreshEvery, (_) {
      if (needsRanch || authLost != null) return;
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
      if (!await _loadToken()) return;
      await _loadState();
      if (state == null) {
        throw const NetworkException('no state');
      }
      push.connect(api.token!);
      await refreshMarket();
    } on ApiException catch (e) {
      if (e.unauthorized) {
        authLost = e.code;
      } else {
        startError = ApiActionError(e);
      }
    } on NetworkException {
      startError = const NetworkActionError();
    } finally {
      starting = false;
      _notify();
    }
  }

  /// 讀手機上的 token；沒有就停在「還沒有牧場」，回 false。
  Future<bool> _loadToken() async {
    final token = await tokens.read(TokenStore.tokenKey);
    ranchName = await tokens.read(TokenStore.ranchKey) ?? ranchName;
    if (token == null || token.isEmpty) {
      needsRanch = true;
      return false;
    }
    needsRanch = false;
    api.token = token;
    return true;
  }

  /// 建立牧場（S02「就叫這個」→ S01-03 建立中）。名字先用 util/ranch_name.dart 檢查過；
  /// 伺服器還是不收時回 invalid_name（detail.reason），畫面回 S02 顯示 S02-05 的提示。
  Future<ActionResult<Session>> createRanch(String name) async {
    if (busy) return const ActionResult.fail(OfflineActionError());
    busy = true;
    _notify();
    ActionResult<Session> r;
    try {
      final session = await api.createSession(name);
      await tokens.write(TokenStore.tokenKey, session.token);
      await tokens.write(TokenStore.ranchKey, session.ranchName);
      api.token = session.token;
      ranchName = session.ranchName;
      needsRanch = false;
      authLost = null;
      _httpOk = true;
      final first = session.state;
      if (first != null) _setState(first);
      push.connect(session.token);
      r = ActionResult.ok(session);
    } on ApiException catch (e) {
      r = ActionResult.fail(ApiActionError(e));
    } on NetworkException {
      r = const ActionResult.fail(NetworkActionError());
    }
    busy = false;
    if (r.ok) {
      if (state == null) await refreshState();
      unawaited(refreshMarket());
    }
    _notify();
    return r;
  }

  /// 放棄這支手機上失效的牧場，改開新牧場（S15-03「開新牧場」）：清掉 token，回到取名。
  Future<void> startOver() async {
    await tokens.delete(TokenStore.tokenKey);
    await tokens.delete(TokenStore.ranchKey);
    api.token = null;
    push.close();
    state = null;
    market = null;
    ranchName = '';
    authLost = null;
    needsRanch = true;
    _notify();
  }

  Future<void> _loadState() async {
    _setState(await api.getState());
    _httpOk = true;
  }

  void _setState(GameState s) {
    state = s;
    _stateAt = _now();
    if (s.ranchName != null && s.ranchName!.isNotEmpty) ranchName = s.ranchName!;
  }

  /// 重新拿 /v1/state 校正（每次操作後、以及每幾秒一次）。
  Future<void> refreshState() async {
    if (api.token == null || authLost != null) return;
    try {
      await _loadState();
    } on ApiException catch (e) {
      // token 失效就停下來顯示 S15-03／S14-05；其他錯誤保留舊資料，下次再試。
      if (e.unauthorized) authLost = e.code;
    } on NetworkException {
      _httpOk = false;
    }
    _notify();
  }

  Future<void> refreshMarket() async {
    if (api.token == null || authLost != null) return;
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
      case PushAuthFailed(:final token, :final code):
        // token 失效：不重連，停下來顯示 S15-03（unauthorized）或 S14-05（signed_in_elsewhere）。
        if (api.token == token) authLost = code;
      case StudPush(:final cowId, :final breed, :final borrower, :final price):
        // 有人借了我上架的公牛：提示一則，並重抓 state（金幣、公牛狀態都變了）。
        _notices.add(StudBorrowedNotice(cowId: cowId, breed: breed, borrower: borrower, price: price));
        refreshState();
      case HelloPush() || MaintenancePush() || ServerErrorPush():
        // 維護和協定版本在第 3b 步之二接（S16）。
        break;
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
    if (!canAct) return const ActionResult.fail(OfflineActionError());
    busy = true;
    _notify();
    ActionResult<T> r;
    try {
      r = ActionResult.ok(await f());
      _httpOk = true;
    } on ApiException catch (e) {
      if (e.unauthorized) authLost = e.code;
      r = ActionResult.fail(ApiActionError(e));
    } on NetworkException {
      _httpOk = false;
      r = const ActionResult.fail(NetworkActionError());
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

  /// 上架借種：借種費由系統算（D26），主人只決定要不要上架。
  Future<ActionResult<Map<String, dynamic>>> studList(Cow bull) => _act(() => api.studList(bull.id));
  Future<ActionResult<Map<String, dynamic>>> studUnlist(Object listingId) => _act(() => api.studUnlist(listingId));

  /// 借種：[price] 是預覽看到的借種費；公牛長大了就回 price_changed（S18-12，按「用新價格借」用新價重送）。
  Future<ActionResult<BreedResult>> studBorrow(StudListing listing, Cow dam, {required int price}) async {
    final r = await _act(() => api.studBorrow(listing.id, dam.id, price: price));
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
