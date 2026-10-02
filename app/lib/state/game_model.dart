import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../api/game_api.dart';
import '../api/models.dart';
import '../api/push.dart';
import '../storage/token_store.dart';
import '../ui/ranch/herd.dart';

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

/// 斷線後重新連上，state 和行情也補抓好了（S15-02「已重新連線，資料更新了」）。
class ReconnectedNotice extends GameNotice {
  const ReconnectedNotice();
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
    this.maintenanceCheckEvery = const Duration(seconds: 30),
    this.longOfflineAfter = const Duration(seconds: 60),
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

  /// 維護中多久問一次 /v1/status（協定 6.2：30 秒）。
  final Duration maintenanceCheckEvery;

  /// 斷線多久算「斷線很久」（S15-04；協定第 7 節：60 秒）。
  final Duration longOfflineAfter;

  StreamSubscription<PushMessage>? _pushSub;
  final _notices = StreamController<GameNotice>.broadcast();

  /// 要跳出來提示玩家的事（例如有人借了你的公牛）。
  Stream<GameNotice> get notices => _notices.stream;
  Timer? _stateTimer;
  Timer? _marketTimer;
  Timer? _maintTimer;
  bool _disposed = false;

  // ---- 狀態 ----
  bool starting = false;
  ActionError? startError;

  /// 手機上還沒有牧場（沒有 token）：要先取名（S02），用 [createRanch] 建立。協定 2.1：取好名字才建立。
  bool needsRanch = false;

  /// 正在建立牧場（S01-03「正在幫你準備新牧場…」）。
  bool creating = false;

  /// 牧場剛建好、還沒按歡迎卡的「進牧場」（S02-02）。按了呼叫 [enterRanch]。
  bool welcomePending = false;

  /// token 失效的原因：unauthorized（S15-03）或 signed_in_elsewhere（S14-05）。null 代表正常。
  /// 不會自動開新牧場（M1 會默默換成新牧場，scope.md 第 10 節第 9 項）。
  String? authLost;

  /// 維護中（S16-01）：/v1/status 說 active、API 回 503 maintenance、或 WebSocket 送來 active 的 maintenance。
  /// null 代表沒有在維護。維護前（active: false）照常玩，v1 不提示（協定 6.2）。
  Maintenance? maintenance;
  bool _checkingStatus = false;
  GameState? state;
  double _stateAt = 0; // 收到 state 時的單調時鐘
  String ranchName = '';
  MarketInfo? market;
  final Map<(Commodity, String), List<PricePoint>> history = {};

  bool _httpOk = true;
  bool busy = false;

  // 斷線（S15-01、S15-04）與重新連上（S15-02）。只在 [_playing] 的時候算。
  double? _offlineSince; // 從什麼時候開始連不上（單調時鐘）
  bool _onlineBefore = false; // 這次進遊戲以後連上過（第一次連上不算「重新連上」）
  bool _dropped = false; // 連上過又斷了：補抓完資料要提示 S15-02
  bool _resyncing = false;
  bool _resyncAgain = false;

  // ---- 畫面導覽 ----
  AppTab tab = AppTab.ranch;

  /// 牧場頁按「我的牛」開的牛舍清單（S03-07）。
  bool penListOpen = false;

  /// 牧場面板按倉庫卡開的倉庫詳細頁（S05-02）。
  bool warehouseOpen = false;

  /// 市場選中的商品（S06：收購價那張卡點一列，賣出面板就換成那一種）。
  Commodity marketCommodity = Commodity.milk;

  /// 牧場場景裡每頭牛的位置：這次打開 app 期間同一頭牛一直在同一個位置（ceo 2026-10-02）。只是顯示用。
  final herdLayout = HerdLayout();
  String? detailCowKey;
  String? breedSireKey;
  String? breedDamKey;
  String? lastCalfKey;

  bool get wsConnected => push.connected.value;

  /// 正在玩：有牧場資料、token 沒失效、沒有在維護。
  bool get _playing => state != null && !needsRanch && authLost == null && maintenance == null;

  /// 連著伺服器：正在玩、WebSocket 連著、最近一次 HTTP 沒有失敗。
  bool get online => _playing && wsConnected && _httpOk;

  /// 玩的途中連不上伺服器多久了（S15-01、S15-04）；連著、或不在玩（維護、token 失效）就是 null。
  Duration? get offlineFor {
    final since = _offlineSince;
    if (since == null) return null;
    return Duration(microseconds: ((_now() - since) * 1e6).round());
  }

  /// 斷線超過 [longOfflineAfter]：顯示 S15-04「連不上伺服器，已經超過 {n} 分鐘」。
  bool get longOffline => (offlineFor ?? Duration.zero) >= longOfflineAfter;

  /// S15-04 的 {n}：斷線幾分鐘（無條件捨去，至少 1）。
  int get offlineMinutes => max(1, (offlineFor ?? Duration.zero).inMinutes);

  /// 按鈕能不能按：連著而且沒有正在處理的操作。
  bool get canAct => online && !busy;

  // ---------------------------------------------------------------------------
  // 啟動
  // ---------------------------------------------------------------------------
  /// 啟動：先問伺服器是不是在維護（S16-01）；有 token 就拿牧場與行情、連 WebSocket、開始定時校正；
  /// 沒有 token 就停在「還沒有牧場」（S02 取名）。
  Future<void> start() async {
    await _boot();
    _stateTimer ??= Timer.periodic(refreshEvery, (_) {
      if (needsRanch || authLost != null || maintenance != null) return;
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
      if (await _maintenanceAtBoot()) return;
      if (!await _loadToken()) return;
      await _loadState();
      if (state == null) {
        throw const NetworkException('no state');
      }
      push.connect(api.token!);
      await refreshMarket();
    } on ApiException catch (e) {
      if (!_handleApiError(e)) startError = ApiActionError(e);
    } on NetworkException {
      startError = const NetworkActionError();
    } finally {
      starting = false;
      _notify();
    }
  }

  /// 開機先打 /v1/status（協定 6.1，不用 token，所以還沒有牧場也會先看到維護畫面）。在維護就回 true。
  /// /v1/status 回別的錯誤不擋開機：它只決定要不要顯示維護畫面，牧場照樣往下讀。連不上就丟 NetworkException。
  Future<bool> _maintenanceAtBoot() async {
    try {
      final m = (await api.status()).maintenance;
      if (m == null || !m.active) return false;
      _enterMaintenance(m);
      return true;
    } on ApiException catch (e) {
      if (!e.maintenance) return false;
      _enterMaintenance(_maintenanceFrom(e));
      return true;
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
    creating = true;
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
      welcomePending = true;
      r = ActionResult.ok(session);
    } on ApiException catch (e) {
      _handleApiError(e);
      r = ActionResult.fail(ApiActionError(e));
    } on NetworkException {
      r = const ActionResult.fail(NetworkActionError());
    }
    busy = false;
    creating = false;
    if (r.ok) {
      if (state == null) await refreshState();
      unawaited(refreshMarket());
    }
    _notify();
    return r;
  }

  /// 歡迎卡（S02-02）按「進牧場」。
  void enterRanch() {
    welcomePending = false;
    _notify();
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
    welcomePending = false;
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

  /// 可以打要 token 的 API：有 token、token 沒失效、沒有在維護。
  bool get _canFetch => api.token != null && authLost == null && maintenance == null;

  /// 重新拿 /v1/state 校正（每次操作後、以及每幾秒一次）。成功回 true。
  Future<bool> refreshState() async {
    if (!_canFetch) return false;
    try {
      await _loadState();
    } on ApiException catch (e) {
      // token 失效、維護中就換畫面（S15-03／S14-05、S16-01）；其他錯誤保留舊資料，下次再試。
      _handleApiError(e);
      _notify();
      return false;
    } on NetworkException {
      _httpOk = false;
      _notify();
      return false;
    }
    _notify();
    // 斷過線、WebSocket 沒斷但 HTTP 先恢復了：也要補抓行情，抓完才提示 S15-02。
    if (_dropped && online && !_resyncing) unawaited(_resync());
    return true;
  }

  /// 重新拿 /v1/market。成功回 true。
  Future<bool> refreshMarket() async {
    if (!_canFetch) return false;
    try {
      final m = await api.market();
      // 保留推播來的較新新聞
      market = m;
      for (final c in Commodity.values) {
        history[(c, '1d')] ??= m.recent[c] ?? const [];
      }
      _httpOk = true;
    } on ApiException catch (e) {
      _handleApiError(e);
      _notify();
      return false;
    } on NetworkException {
      _httpOk = false;
      _notify();
      return false;
    }
    _notify();
    return true;
  }

  /// 打 API 回錯誤時先過這裡：token 失效（401）停下來顯示 S15-03／S14-05；維護中（503 maintenance）進 S16-01。
  /// 處理了回 true；其他錯誤由呼叫的地方決定（操作的錯誤畫面用錯誤碼查文案）。
  bool _handleApiError(ApiException e) {
    if (e.unauthorized) {
      authLost = e.code;
      return true;
    }
    if (e.maintenance) {
      _enterMaintenance(_maintenanceFrom(e));
      return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // 維護（S16-01；協定第 6 節）
  // ---------------------------------------------------------------------------
  /// 503 maintenance 的 detail 只有預計恢復時間（M4 部署時反向代理也回同一個形狀）。
  static Maintenance _maintenanceFrom(ApiException e) {
    final ends = e.detail['ends_at_real'];
    return Maintenance(endsAtReal: ends is num ? ends.toDouble() : null, active: true);
  }

  /// 進入維護：關掉 WebSocket（不要重連；連線剛好在維護時重連會被拒絕，推播那邊會一直退避重試），
  /// 改成每 [maintenanceCheckEvery] 打一次 /v1/status。
  void _enterMaintenance(Maintenance m) {
    maintenance = m;
    push.close();
    _maintTimer ??= Timer.periodic(maintenanceCheckEvery, (_) => checkMaintenance());
    _notify();
  }

  /// 再問一次伺服器維護好了沒（定時；也是 S16-01 的「重新載入」）。
  /// `active` 不是 true 就重新載入整個牧場：維護結束後 maintenance 是 null，
  /// 營運接著排了下一次維護時是 active: false，兩種都要回到遊戲。
  Future<void> checkMaintenance() async {
    if (maintenance == null || _checkingStatus) return;
    _checkingStatus = true;
    var over = false;
    try {
      final m = (await api.status()).maintenance;
      if (m != null && m.active) {
        maintenance = m; // 營運延長維護會改預計恢復時間
      } else {
        over = true;
      }
    } on ApiException catch (e) {
      // 部署時反向代理也回 503 maintenance；其他錯誤等下一次再問
      if (e.maintenance) {
        final m = _maintenanceFrom(e);
        if (m.endsAtReal != null) maintenance = m;
      }
    } on NetworkException {
      // 連不上：留在維護畫面，下一次再問
    } finally {
      _checkingStatus = false;
    }
    if (_disposed) return;
    if (over && maintenance != null) {
      _maintTimer?.cancel();
      _maintTimer = null;
      maintenance = null;
      await _boot(); // 開機會再問一次 /v1/status，剛好又開始維護就回到 S16-01
    } else {
      _notify();
    }
  }

  // ---------------------------------------------------------------------------
  // 推播
  // ---------------------------------------------------------------------------
  void _onConnectedChanged() {
    // 連上後先補抓 state 和行情（協定第 7 節）。
    if (push.connected.value) unawaited(_resync());
    _notify();
  }

  /// 補抓 state 和行情。斷過線的話，兩個都成功而且還連著才提示 S15-02（只提示一次）。
  /// 補抓到一半又斷線重連，就再抓一輪。
  Future<void> _resync() async {
    if (_resyncing) {
      _resyncAgain = true;
      return;
    }
    _resyncing = true;
    var ok = false;
    try {
      do {
        _resyncAgain = false;
        final r = await Future.wait([refreshState(), refreshMarket()]);
        ok = r.every((v) => v);
      } while (_resyncAgain && !_disposed);
    } finally {
      _resyncing = false;
    }
    if (_disposed) return;
    if (ok && _dropped && online) {
      _dropped = false;
      _notices.add(const ReconnectedNotice());
    }
    _notify();
  }

  /// S15-04「重試」：WebSocket 沒連著就叫它重連，並馬上補抓 state 和行情。
  Future<void> retryConnection() async {
    final token = api.token;
    if (token == null || !_playing) return;
    if (!wsConnected) push.connect(token);
    await _resync();
  }

  /// 斷線計時（S15-04）與「連上過又斷了」（S15-02）。每次狀態改變都算一次；不在玩的時候歸零。
  void _trackOnline() {
    if (!_playing) {
      _offlineSince = null;
      _onlineBefore = false;
      _dropped = false;
      return;
    }
    if (online) {
      _offlineSince = null;
      _onlineBefore = true;
    } else {
      _offlineSince ??= _now();
      if (_onlineBefore) _dropped = true;
    }
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
      case MaintenancePush(maintenance: final m):
        // 開始維護：伺服器接著用 4503 關掉 WebSocket。安排、取消維護（active: false 或 null）照常玩，v1 不提示。
        if (m != null && m.active) _enterMaintenance(m);
      case StudPush(:final cowId, :final breed, :final borrower, :final price):
        // 有人借了我上架的公牛：提示一則，並重抓 state（金幣、公牛狀態都變了）。
        _notices.add(StudBorrowedNotice(cowId: cowId, breed: breed, borrower: borrower, price: price));
        refreshState();
      case HelloPush() || ServerErrorPush():
        // error 由推播那邊轉成 PushAuthFailed；hello 的協定版本 v1 不檢查。
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
    penListOpen = false;
    warehouseOpen = false;
    _notify();
  }

  /// 市場換一種商品（S06）。
  void selectMarket(Commodity c) {
    marketCommodity = c;
    _notify();
  }

  /// 倉庫詳細頁（S05-02，從牧場面板的倉庫卡打開）。
  void openWarehouse() {
    warehouseOpen = true;
    _notify();
  }

  void closeWarehouse() {
    warehouseOpen = false;
    _notify();
  }

  void openPenList() {
    penListOpen = true;
    _notify();
  }

  void closePenList() {
    penListOpen = false;
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
      _handleApiError(e);
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
    } on ApiException catch (e) {
      if (_handleApiError(e)) _notify();
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
    if (_disposed) return;
    _trackOnline();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stateTimer?.cancel();
    _marketTimer?.cancel();
    _maintTimer?.cancel();
    _pushSub?.cancel();
    push.connected.removeListener(_onConnectedChanged);
    push.close();
    _notices.close();
    super.dispose();
  }
}
