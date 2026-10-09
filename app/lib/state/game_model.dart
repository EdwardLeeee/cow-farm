import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../api/game_api.dart';
import '../api/models.dart';
import '../api/push.dart';
import '../auth/sign_in.dart';
import '../storage/token_store.dart';
import '../ui/ranch/herd.dart';
import 'grow_reveals.dart';
import 'settings.dart';

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

/// 設定（S13）裡的哪一頁：設定主頁、語言（S13-17）、備份牧場（S13-02）、刪除牧場（S13-03）。
enum SettingsView { home, language, backup, delete }

/// 按登入按鈕綁定帳號（S13-02）的結果：畫面照這個跳提示或對話框（S13-12、S13-08）。
enum BindStatus {
  /// 綁好了（「備份好了！已綁定 {name} 帳號」）。
  bound,

  /// 玩家關掉登入畫面（「已取消登入」）。
  cancelled,

  /// 登入畫面那邊失敗，或伺服器說憑證不對（sign_in_failed）：「登入失敗，請再試一次」。
  failed,

  /// 帳號已經綁了別的牧場（S13-08）：[BindOutcome.conflict] 是那個牧場。
  conflict,

  /// 連不上、其他錯誤：[BindOutcome.error] 照一般的錯誤提示。
  error,
}

class BindOutcome {
  const BindOutcome(this.status, {this.conflict, this.error});
  final BindStatus status;
  final LinkConflict? conflict;
  final ActionError? error;
}

/// 找回牧場（S14-02）的結果。
enum RecoverStatus {
  /// 找回來了：畫面換成 S14-04「歡迎回來」。
  recovered,

  /// 玩家關掉登入畫面（S14-08「已取消登入」）。
  cancelled,

  /// 登入畫面那邊失敗，或伺服器說憑證不對（S14-08「登入失敗，請再試一次」）。
  failed,

  /// 這個帳號沒有備份過牧場（S14-03）。
  none,

  /// 連不上、其他錯誤：[RecoverOutcome.error] 照一般的錯誤提示。
  error,
}

class RecoverOutcome {
  const RecoverOutcome(this.status, {this.error});
  final RecoverStatus status;
  final ActionError? error;
}

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
    this.signInPlatform = SignInPlatform.none,
    this.signIn,
    PrefsStore? prefs,
  }) : _now = now ?? monotonicClock(),
       _grows = GrowReveals(prefs ?? MemoryPrefsStore()) {
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

  /// 這個建置能不能用 Apple／Google 登入、是哪種手機（main.dart 用 config.dart 的 resolveSignInPlatform；
  /// 網頁版、沒設 client ID 是 none）。none 的時候畫面上沒有任何登入的入口（ceo 2026-10-03）。
  final SignInPlatform signInPlatform;

  /// 叫出 Apple／Google 的登入畫面。[signInPlatform] 是 none 時是 null。
  final SignInService? signIn;

  /// 畫面要不要放登入的入口（「備份牧場」、齒輪小點、找回我的牧場）。
  bool get canSignIn => signInPlatform.enabled && signIn != null;

  StreamSubscription<PushMessage>? _pushSub;
  final _notices = StreamController<GameNotice>.broadcast();

  /// 要跳出來提示玩家的事（例如有人借了你的公牛）。
  Stream<GameNotice> get notices => _notices.stream;
  Timer? _stateTimer;
  Timer? _marketTimer;
  Timer? _maintTimer;
  bool _disposed = false;

  /// 小牛長大揭曉（A-13、S03-25）：看過是小牛的牛記在手機上（[prefs]），長大了就排著等牧場頁揭曉。
  final GrowReveals _grows;

  /// 下一頭小牛長大（adult_at）的時候重抓 state（協定 2.3）。[start] 以後才排（測試不開計時器）。
  Timer? _growTimer;
  bool _started = false;

  // ---- 狀態 ----
  bool starting = false;
  ActionError? startError;

  /// 手機上還沒有牧場（沒有 token）：要先取名（S02），用 [createRanch] 建立。協定 2.1：取好名字才建立。
  bool needsRanch = false;

  /// 正在建立牧場（S01-03「正在幫你準備新牧場…」）。
  bool creating = false;

  /// 牧場剛建好、還沒按歡迎卡的「進牧場」（S02-02）。按了呼叫 [enterRanch]。
  bool welcomePending = false;

  /// 牧場剛刪除（S13-04「牧場已經刪除了」）。按「開新牧場」呼叫 [startNewRanch]，才進 S02 取名。
  bool ranchDeleted = false;

  /// 登入畫面關掉以後、等伺服器回覆綁定（S13-15「綁定中…」）。登入畫面開著的時候不算。
  bool binding = false;

  // ---- 找回牧場（S14；能登入的建置才有） ----
  /// 第一次打開選了「開新牧場」（S14-01 → S02），或從 S13-04、S15-03 按「開新牧場」：之後沒有牧場就直接取名。
  bool newRanchChosen = false;

  /// 開著「找回我的牧場」（S14-02）。
  bool recoverOpen = false;

  /// 登入畫面關掉以後、等伺服器回覆找回（S14-06「登入中…」）。
  bool recovering = false;

  /// 這個帳號沒有備份過牧場（S14-03）：「換一個帳號」「開新牧場」。
  bool recoverNone = false;

  /// 找回來了，還沒按「進牧場」（S14-04「歡迎回來！」）。
  bool welcomeBack = false;

  /// 第一次打開、手機上沒有牧場：能登入的建置先問「開新牧場」還是「找回我的牧場」（S14-01）。
  bool get showsFirstOpen => needsRanch && canSignIn && !newRanchChosen && !ranchDeleted && !creating;

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

  /// 開著的設定頁（頂列的齒輪打開，S13）；null 是沒有開。關掉回到原本那一頁。
  SettingsView? settingsView;

  /// 牧場頁按「我的牛」開的牛舍清單（S03-07）。
  bool penListOpen = false;

  /// 牧場面板按倉庫卡開的倉庫詳細頁（S05-02）。
  bool warehouseOpen = false;

  /// 市場選中的商品（S06：收購價那張卡點一列，賣出面板就換成那一種）。
  Commodity marketCommodity = Commodity.milk;

  /// 商店顯示「設施」（S10）還是「抽牛」（S19）。
  bool shopFacility = false;

  /// 配種頁顯示「借種」（S18）還是「自己配種」（S08）。
  bool breedStud = false;

  /// 借種分頁按「借種紀錄」開的紀錄頁（S18-11）。
  bool studLogOpen = false;

  /// 紀錄頁顯示「排行榜」（S12）還是「圖鑑」（S09）。
  bool recordsRank = false;

  /// 圖鑑打開的品種（S09-03、S09-04）；null 是列表。
  String? codexBreed;

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
    _started = true;
    await _grows.loaded; // 先知道哪些牛看過是小牛，第一次收到 state 就能揭曉沒開 app 的時候長大的
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
      final st = await api.status();
      _markReal(st.realTime);
      final m = st.maintenance;
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
    await _forgetRanch();
    newRanchChosen = true;
    _notify();
  }

  /// 刪除牧場（S13-03 按「刪除我的牧場」；協定 5.6）。成功就忘掉這個牧場，畫面換成 S13-04「牧場已經刪除了」。
  /// 失敗（S13-05）再按一次用同一個 request_id：第一次其實刪掉了、只是沒收到回應的話，伺服器回第一次的回應。
  Future<ActionResult<void>> deleteRanch() async {
    if (busy) return const ActionResult.fail(OfflineActionError());
    busy = true;
    _notify();
    final requestId = _deleteRequestId ??= const Uuid().v4();
    try {
      await api.deleteRanch(requestId: requestId);
    } on ApiException catch (e) {
      // 401 unauthorized：token 已經失效。刪除時遇到，多半是前一次其實刪掉了、超過 10 分鐘伺服器就不認得那個
      // request_id（協定 5.6：刪除後這個 token 收到 unauthorized，app 回到 S13-04），一樣當成刪掉了。
      // signed_in_elsewhere（牧場已經在別的手機）、維護照一般的處理（S14-05、S16-01）。
      if (e.code != 'unauthorized') {
        busy = false;
        _handleApiError(e);
        _notify();
        return ActionResult.fail(ApiActionError(e));
      }
    } on NetworkException {
      busy = false;
      _notify();
      return const ActionResult.fail(NetworkActionError());
    }
    busy = false;
    _deleteRequestId = null;
    ranchDeleted = true;
    _grows.forget(state?.playerId);
    await _forgetRanch();
    _notify();
    return const ActionResult.ok(null);
  }

  String? _deleteRequestId;

  /// S13-04「牧場已經刪除了」按「開新牧場」：進 S02 取名。
  void startNewRanch() {
    ranchDeleted = false;
    newRanchChosen = true;
    _notify();
  }

  /// 忘掉這支手機上的牧場：token、牧場資料、推播、開著的頁面都清掉，回到「還沒有牧場」。
  /// 先清掉記憶體裡的 token，還在路上的回應（舊牧場的 state、401）就會丟掉（[_loadState]、[_handleApiError]）。
  Future<void> _forgetRanch() async {
    api.token = null;
    push.close();
    _clearRanchView();
    market = null;
    ranchName = '';
    needsRanch = true;
    await tokens.delete(TokenStore.tokenKey);
    await tokens.delete(TokenStore.ranchKey);
  }

  /// 換了牧場（刪除、換回）：舊牧場的資料和開著的頁面都清掉，回到牧場分頁。牛的編號每個牧場都從 1 開始，
  /// 選好的公牛母牛、剛生的小牛、場景的位置都不能留給新牧場。
  void _clearRanchView() {
    state = null;
    // 舊牧場還沒揭曉的小牛不能留到新牧場（手機上記的照牧場分開，不用清）
    _grows.clear();
    _growTimer?.cancel();
    _growTimer = null;
    // 舊牧場還沒按「好」的升級慶祝（S11-01）、還沒按掉的備份提醒（S11-05）不能留到新牧場
    levelUp = null;
    backupRemind = false;
    authLost = null;
    welcomePending = false;
    binding = false;
    tab = AppTab.ranch;
    settingsView = null;
    profileOpen = false;
    renameOpen = false;
    detailCowKey = null;
    penListOpen = false;
    warehouseOpen = false;
    studLogOpen = false;
    breedSireKey = null;
    breedDamKey = null;
    lastCalfKey = null;
    herdLayout.clear();
    _offlineSince = null;
    _onlineBefore = false;
    _dropped = false;
    recoverOpen = false;
    recovering = false;
    recoverNone = false;
    welcomeBack = false;
  }

  // ---------------------------------------------------------------------------
  // 備份牧場：綁定 Apple／Google 帳號（S13-02 等；協定 5.0–5.4）
  // ---------------------------------------------------------------------------
  /// 綁定的帳號（協定 2.3 account.links）；空的代表還沒備份。
  List<AccountLink> get accountLinks => state?.accountLinks ?? const [];

  /// 按登入按鈕（S13-02）：拿 nonce → 叫出 Apple／Google 的登入畫面 → 把憑證送給伺服器綁定。
  /// 每次都重新拿 nonce（只能用一次，不論成功失敗）；request_id 每次也是新的：同一個帳號再綁一次伺服器回 200。
  Future<BindOutcome> bindAccount(SignInProvider provider) async {
    final service = signIn;
    if (service == null || !canSignIn || busy) return const BindOutcome(BindStatus.error, error: OfflineActionError());
    busy = true;
    _notify();
    try {
      final nonce = await api.accountNonce();
      final result = await service.signIn(provider, nonce: nonce);
      switch (result) {
        case SignInCancelled():
          return const BindOutcome(BindStatus.cancelled);
        case SignInFailed():
          return const BindOutcome(BindStatus.failed);
        case SignInCredential(:final idToken, :final authorizationCode):
          binding = true;
          _notify();
          final token = api.token;
          final links = await api.linkAccount(
            provider: provider,
            idToken: idToken,
            nonce: nonce,
            authorizationCode: authorizationCode,
            requestId: const Uuid().v4(),
          );
          if (api.token != token) return const BindOutcome(BindStatus.error, error: OfflineActionError());
          _setLinks(links);
          return const BindOutcome(BindStatus.bound);
      }
    } on ApiException catch (e) {
      if (e.code == 'account_in_use') {
        final conflict = LinkConflict.fromDetail(e.detail);
        if (conflict != null) return BindOutcome(BindStatus.conflict, conflict: conflict);
      }
      if (e.code == 'sign_in_failed') return const BindOutcome(BindStatus.failed);
      _handleApiError(e);
      return BindOutcome(BindStatus.error, error: ApiActionError(e));
    } on NetworkException {
      return const BindOutcome(BindStatus.error, error: NetworkActionError());
    } finally {
      busy = false;
      binding = false;
      _notify();
    }
  }

  /// 解除綁定（S13-13 按「解除」；協定 5.4）。伺服器說本來就沒綁（not_linked，例如在別的手機解除了）也算解除了。
  Future<ActionResult<void>> unlinkAccount(SignInProvider provider) async {
    if (busy) return const ActionResult.fail(OfflineActionError());
    busy = true;
    _notify();
    try {
      final links = await api.unlinkAccount(provider, requestId: const Uuid().v4());
      _setLinks(links);
      return const ActionResult.ok(null);
    } on ApiException catch (e) {
      if (e.code == 'not_linked') {
        _setLinks([
          for (final l in accountLinks)
            if (l.provider != provider.wire) l,
        ]);
        return const ActionResult.ok(null);
      }
      _handleApiError(e);
      return ActionResult.fail(ApiActionError(e));
    } on NetworkException {
      return const ActionResult.fail(NetworkActionError());
    } finally {
      busy = false;
      _notify();
    }
  }

  void _setLinks(List<AccountLink> links) {
    final st = state;
    if (st != null) state = st.withAccountLinks(links);
  }

  /// 換回那個牧場（S13-09 按「換回，並刪除現在的牧場」；協定 5.3）。伺服器在同一個動作裡刪掉這支手機現在的
  /// 牧場、發那個牧場的新 token。ticket 只能用一次：沒收到回應時再按，用同一個 ticket 和 request_id 原封不動重送，
  /// 伺服器 10 分鐘內回第一次的回應（裡面有新的 token）；換了 ticket（重新綁定）才用新的 request_id。
  Future<ActionResult<void>> switchRanch(LinkConflict conflict) async {
    if (busy) return const ActionResult.fail(OfflineActionError());
    busy = true;
    _notify();
    final pending = _switchRequest;
    final requestId = pending != null && pending.ticket == conflict.ticket ? pending.id : const Uuid().v4();
    _switchRequest = (ticket: conflict.ticket, id: requestId);
    try {
      final session = await api.switchAccount(ticket: conflict.ticket, requestId: requestId);
      _switchRequest = null;
      await _adoptRanch(session);
      return const ActionResult.ok(null);
    } on ApiException catch (e) {
      // ticket 過期、用過了：重送也不會成功，下次重新綁定拿新的
      _switchRequest = null;
      _handleApiError(e);
      return ActionResult.fail(ApiActionError(e));
    } on NetworkException {
      return const ActionResult.fail(NetworkActionError());
    } finally {
      busy = false;
      _notify();
    }
  }

  ({String ticket, String id})? _switchRequest;

  // ---------------------------------------------------------------------------
  // 找回牧場（S14；協定 5.5）
  // ---------------------------------------------------------------------------
  /// S14-01 按「開新牧場」：進 S02 取名，不用登入。
  void chooseNewRanch() {
    newRanchChosen = true;
    recoverOpen = false;
    recoverNone = false;
    _notify();
  }

  /// 按「找回我的牧場」（S14-01）：打開 S14-02。
  void openRecover() {
    if (!canSignIn) return;
    recoverOpen = true;
    recoverNone = false;
    _notify();
  }

  /// S14-02 的返回：回到 S14-01。
  void closeRecover() {
    if (recovering) return;
    recoverOpen = false;
    recoverNone = false;
    _notify();
  }

  /// S14-03 按「換一個帳號」：回到登入按鈕（登入以後已經登出 Google，再按會重新選帳號）。
  void recoverAnother() {
    recoverNone = false;
    _notify();
  }

  /// S14-04 按「進牧場」。
  void enterRecoveredRanch() {
    welcomeBack = false;
    _notify();
  }

  /// 按 S14-02 的登入按鈕：拿 nonce → Apple／Google 的登入畫面 → 找回（不帶 token）。成功就換成那個牧場的 token，
  /// 畫面換成 S14-04「歡迎回來」。找回可以重來：沒收到回應就重新登入再找回一次，伺服器再發一個新的 token，
  /// 所以 request_id 每次都是新的（跟換回不一樣，見 [switchRanch]）。
  Future<RecoverOutcome> recoverRanch(SignInProvider provider) async {
    final service = signIn;
    if (service == null || !canSignIn || busy) {
      return const RecoverOutcome(RecoverStatus.error, error: OfflineActionError());
    }
    busy = true;
    recoverNone = false;
    _notify();
    try {
      final nonce = await api.accountNonce();
      final result = await service.signIn(provider, nonce: nonce);
      switch (result) {
        case SignInCancelled():
          return const RecoverOutcome(RecoverStatus.cancelled);
        case SignInFailed():
          return const RecoverOutcome(RecoverStatus.failed);
        case SignInCredential(:final idToken):
          recovering = true;
          _notify();
          final session = await api.recoverAccount(
            provider: provider,
            idToken: idToken,
            nonce: nonce,
            requestId: const Uuid().v4(),
          );
          await _adoptRanch(session);
          welcomeBack = true;
          return const RecoverOutcome(RecoverStatus.recovered);
      }
    } on ApiException catch (e) {
      if (e.code == 'account_not_linked') {
        recoverNone = true;
        return const RecoverOutcome(RecoverStatus.none);
      }
      if (e.code == 'sign_in_failed') return const RecoverOutcome(RecoverStatus.failed);
      _handleApiError(e);
      return RecoverOutcome(RecoverStatus.error, error: ApiActionError(e));
    } on NetworkException {
      return const RecoverOutcome(RecoverStatus.error, error: NetworkActionError());
    } finally {
      busy = false;
      recovering = false;
      _notify();
    }
  }

  /// 換成伺服器給的另一個牧場（換回；之後找回也走這裡）：先換掉記憶體裡的 token，舊牧場還在路上的回應
  /// （state、401）就會丟掉；清掉舊牧場的畫面，存新 token，用回應裡的 state，重新連推播、抓行情。
  Future<void> _adoptRanch(Session session) async {
    api.token = session.token;
    push.close();
    _clearRanchView();
    ranchName = session.ranchName;
    needsRanch = false;
    ranchDeleted = false;
    await tokens.write(TokenStore.tokenKey, session.token);
    await tokens.write(TokenStore.ranchKey, session.ranchName);
    if (api.token != session.token) return; // 這段時間又換了牧場
    _httpOk = true;
    final first = session.state;
    if (first != null) _setState(first);
    push.connect(session.token);
    if (state == null) await refreshState();
    unawaited(refreshMarket());
  }

  Future<void> _loadState() async {
    final token = api.token;
    await _grows.loaded;
    final s = await api.getState();
    if (api.token != token) return; // 這段時間牧場換了（刪除）：舊牧場的資料不要
    _setState(s);
    _httpOk = true;
  }

  void _setState(GameState s) {
    final before = state?.level;
    state = s;
    _stateAt = _now();
    _markReal(s.realTime);
    if (s.ranchName != null && s.ranchName!.isNotEmpty) ranchName = s.ranchName!;
    // 等級比上一次高：要慶祝（S11-01）。剛打開、剛開新牧場（之前沒有 state）不算；一次升好幾級只記最後那一級
    if (before != null && s.level > before) levelUp = (level: s.level, levelAt: s.levelProgress.levelAt);
    _grows.track(s);
    _scheduleGrowRefresh(s);
  }

  /// 下一頭要在牧場頁揭曉的牛（長大了、還沒揭曉；照長大的時間）。沒有是 null。
  Cow? get grownCow => _grows.next(state);

  /// 揭曉完了（一般的牛點一下，雜種牛按「好」）：換下一頭。
  void dismissGrown(Cow cow) {
    _grows.done(cow.id, state?.playerId);
    _notify();
  }

  /// 在最早的那頭小牛長大的時候重抓 state（協定 2.3：伺服器不推播，app 在 adult_at 重抓）。平常 [refreshEvery] 也會抓，
  /// 這裡讓揭曉不用多等那幾秒。
  void _scheduleGrowRefresh(GameState s) {
    _growTimer?.cancel();
    _growTimer = null;
    if (!_started || _disposed) return;
    final now = gameNow;
    double? next;
    for (final c in s.cows) {
      final at = c.adultAt;
      if (c.stage == CowStage.calf && at != null && at > now && (next == null || at < next)) next = at;
    }
    if (next == null) return;
    final scale = timeScale > 0 ? timeScale : 1;
    // 晚 0.5 秒再抓：伺服器只算到它的 server_time，手機的時鐘快一點的話抓到的還是小牛（下次照樣會抓到）
    _growTimer = Timer(Duration(milliseconds: ((next - now) / scale * 1000).ceil() + 500), () {
      _growTimer = null;
      refreshState();
    });
  }

  /// 剛升級、還沒按「好」的慶祝（S11-01）：升到幾級、這一級的門檻（累積收入）。
  ({int level, double levelAt})? levelUp;

  /// 按了慶祝卡的「好」。
  void dismissLevelUp() {
    levelUp = null;
    _notify();
  }

  /// 升到 Lv2 以後提醒備份牧場（S11-05）：慶祝卡關掉以後跳一次。要不要跳由畫面決定（能登入的建置、還沒備份、
  /// 這支手機還沒對這個牧場提醒過；設定存在手機上）。
  bool backupRemind = false;

  void remindBackup() {
    backupRemind = true;
    _notify();
  }

  void closeBackupRemind() {
    backupRemind = false;
    _notify();
  }

  // 伺服器最後一次給的現實時間（Unix 秒）和那時候的單調時鐘。
  double? _realAt;
  double _realMono = 0;

  void _markReal(double? real) {
    if (real == null || real <= 0) return;
    _realAt = real;
    _realMono = _now();
  }

  /// 現在的現實時間（Unix 秒）：伺服器最後給的 real_time，加上之後手機單調時鐘走的時間。還沒收過就是 null。
  double? get realNow {
    final at = _realAt;
    return at == null ? null : at + (_now() - _realMono);
  }

  /// 維護已經過了預計恢復的時間，還沒結束（S16-04「比預計的時間晚一點」）。沒有預計時間（S16-05）就是 false。
  bool get maintenanceLate {
    final ends = maintenance?.endsAtReal, now = realNow;
    return ends != null && now != null && now > ends;
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
      // 已經沒有 token（牧場剛刪除）、或已經換成別的牧場的 token（換回）：是舊牧場還在路上的請求，不算失效
      if (api.token != null && (e.token == null || e.token == api.token)) authLost = e.code;
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
      final st = await api.status();
      _markReal(st.realTime);
      final m = st.maintenance;
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
            : m.copyWith(
                quotes: {...m.quotes, for (final e in quotes.entries) e.key: e.value.mergedOver(m.quotes[e.key])},
              );
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
    studLogOpen = false;
    codexBreed = null;
    _notify();
  }

  /// 牧場資料（S21-01）開著：點頂列的頭像或名牌打開，返回關掉。整頁，沒有頂列和分頁列。
  bool profileOpen = false;

  void openProfile() {
    profileOpen = true;
    _notify();
  }

  void closeProfile() {
    profileOpen = false;
    renameOpen = false;
    _notify();
  }

  /// 改名頁（S21-04）開著：在牧場資料點牧場名打開，返回回到牧場資料。
  bool renameOpen = false;

  void openRename() {
    renameOpen = true;
    _notify();
  }

  void closeRename() {
    renameOpen = false;
    _notify();
  }

  /// 改牧場名（S21）：成功就關掉改名頁（回到牧場資料，提示由牧場資料頁顯示）。
  Future<ActionResult<Map<String, dynamic>>> renameRanch(String name) async {
    final r = await _act(() => api.renameRanch(name));
    if (r.ok) {
      renameOpen = false;
      _notify();
    }
    return r;
  }

  /// 換頭像（S21）。
  Future<ActionResult<Map<String, dynamic>>> setAvatar(String breed) => _act(() => api.setAvatar(breed));

  /// 頂列的齒輪：打開設定主頁（S13-01）。
  void openSettings() {
    settingsView = SettingsView.home;
    _notify();
  }

  /// 設定主頁的一列：語言（S13-17）、刪除牧場（S13-03）。
  void openSettingsView(SettingsView v) {
    settingsView = v;
    _notify();
  }

  /// 設定的返回：語言、刪除牧場回到設定主頁；設定主頁關掉設定，回到原本那一頁。
  void settingsBack() {
    settingsView = settingsView == SettingsView.home ? null : SettingsView.home;
    _notify();
  }

  /// 商店換「抽牛」或「設施」（S19、S10）。
  void selectShop({required bool facility}) {
    shopFacility = facility;
    _notify();
  }

  /// 到商店的設施升級（S10）：擴建牛舍、加大倉庫的按鈕都到這裡。
  void openFacility() {
    shopFacility = true;
    selectTab(AppTab.shop);
  }

  /// 配種頁換「自己配種」或「借種」（S08、S18）。
  void selectBreed({required bool stud}) {
    breedStud = stud;
    _notify();
  }

  /// 借種紀錄（S18-11）。
  void openStudLog() {
    studLogOpen = true;
    _notify();
  }

  void closeStudLog() {
    studLogOpen = false;
    _notify();
  }

  /// 紀錄頁換「圖鑑」或「排行榜」（S09、S12）。
  void selectRecords({required bool rank}) {
    recordsRank = rank;
    codexBreed = null;
    _notify();
  }

  /// 排行榜看的是哪一種（S12：總資產、圖鑑、本週收入）。
  RankKind rankKind = RankKind.networth;

  void selectRankKind(RankKind kind) {
    rankKind = kind;
    _notify();
  }

  /// 圖鑑的品種詳細（S09-03、S09-04）。
  void openCodex(String breed) {
    codexBreed = breed;
    _notify();
  }

  void closeCodex() {
    codexBreed = null;
    _notify();
  }

  /// 遊戲時間 [t] 是手機時區的哪個時刻。現實時間用伺服器的：state 那一刻的 real_time，加上之後過了多久
  /// （遊戲時間 ÷ 倍率）；不看手機的時鐘（還沒有 real_time 時才用）。
  DateTime realLocalTime(double t) {
    final st = state;
    final scale = timeScale > 0 ? timeScale : 1;
    final nowReal = st == null || st.realTime <= 0
        ? DateTime.now().millisecondsSinceEpoch / 1000
        : st.realTime + (gameNow - st.serverTime) / scale;
    return DateTime.fromMillisecondsSinceEpoch(((nowReal - (gameNow - t) / scale) * 1000).round());
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
    breedStud = false;
    studLogOpen = false;
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
  Future<StudLog?> studLog() => _read(api.studLog);

  /// 借種前看可能結果（協定 4.3）。那一筆已經被借走或下架時伺服器回 404 listing_not_found：[gone] 是 true，
  /// 畫面跳 S18-10「這頭公牛已經被借走或下架了」，不當成一般的載入失敗（一般的失敗 3 秒後自動再試）。
  Future<({BreedPreview? preview, bool gone})> studPreview(StudListing listing, Cow dam) async {
    var gone = false;
    final p = await _read<BreedPreview?>(() async {
      try {
        return await api.studPreview(listing.id, dam.id);
      } on ApiException catch (e) {
        if (e.code != 'listing_not_found') rethrow;
        gone = true;
        return null;
      }
    });
    return (preview: p, gone: gone);
  }

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
    _growTimer?.cancel();
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
