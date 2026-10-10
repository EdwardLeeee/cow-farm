import '../auth/sign_in.dart';
import 'models.dart';

/// 伺服器回的錯誤：`{"error": {"code": "...", "message": "...", "detail": {...}}}`（協定 1.4）。
///
/// 畫面依 [code] 顯示字串表的文案（Strings.errorText），**不顯示** [message]（只供除錯）。
class ApiException implements Exception {
  const ApiException(this.status, this.code, this.message, [this.detail = const {}, this.token]);
  final int status;
  final String code;
  final String message;
  final Map<String, dynamic> detail;

  /// 送出這個請求時用的 token（[HttpGameApi] 填；不知道是 null）。換回別的牧場以後，舊牧場還在路上的請求
  /// 回 401 不算這支手機的 token 失效（GameModel._handleApiError）。
  final String? token;

  /// token 失效：unauthorized（S15-03）或 signed_in_elsewhere（S14-05）。帳號綁定、找回的錯誤都不用 401。
  bool get unauthorized => status == 401;

  /// 維護中（503 maintenance，S16-01）。
  bool get maintenance => code == 'maintenance';

  @override
  String toString() => 'ApiException($status $code: $message)';
}

/// 連不上伺服器（重送幾次後仍失敗）。
class NetworkException implements Exception {
  const NetworkException(this.cause);
  final Object cause;

  @override
  String toString() => 'NetworkException($cause)';
}

/// 資料層介面：正式版用 [HttpGameApi]，測試用假資料實作。
///
/// 會改變狀態的呼叫（collect、sell、ship、shopBuy、breed、upgrade、field*、stud list/unlist/borrow）
/// 由實作負責帶 request_id，
/// 網路失敗重送時沿用同一個。
abstract class GameApi {
  /// 目前的 token；null 代表還沒登入。
  String? get token;
  set token(String? value);

  /// 建立牧場（取好名字才建立，協定 2.1）。名字不能用回 400 invalid_name（detail.reason）。
  Future<Session> createSession(String ranchName);

  /// 伺服器狀態與維護（不用 token，協定 6.1）。
  Future<ServerStatus> status();
  Future<GameState> getState();
  Future<Map<String, dynamic>> collect();

  /// qty 可以有小數：要全部賣出時送倉庫的 milk_total／beef_total 原值（protocol 1.5）。
  Future<SellQuote> sellQuote(Commodity commodity, double qty);
  Future<SellResult> sell(Commodity commodity, double qty);
  Future<ShipResult> ship(Object cowId);
  Future<BreedPreview> breedPreview(Object sire, Object dam);
  Future<BreedResult> breed(Object sire, Object dam);
  Future<Map<String, dynamic>> upgrade(UpgradeKind kind);
  Future<MarketInfo> market();
  Future<List<PricePoint>> marketHistory(Commodity commodity, String range);
  Future<Leaderboard> leaderboard(RankKind kind);

  // ---- v0.2 ----
  /// 出貨前看評級機率與估值。
  Future<ShipPreview> shipPreview(Object cowId);

  /// 商店各等級的價格與精確機率。
  Future<ShopInfo> shop();

  /// 商店抽牛（grade 是 A／B／C）。
  Future<ShopBuyResult> shopBuy(String grade);

  Future<Map<String, dynamic>> fieldAssign(Object cowId, {int? field});
  Future<Map<String, dynamic>> fieldRecall(Object cowId);
  Future<Map<String, dynamic>> fieldHarvest();
  Future<Map<String, dynamic>> fieldExpand();

  /// 改牧場名（S21，協定 2.5 節 `POST /v1/ranch/rename` `{name}`）：第一次免費，之後扣 `economy.rename_price`。
  /// 名字照 D23 由伺服器檢查（不收時回 invalid_name），錢不夠回 not_enough_coins（need、have）。
  /// 回應之後照常重新讀 state（牧場名、`profile.renames`、金幣）。
  Future<Map<String, dynamic>> renameRanch(String name);

  /// 換頭像（S21，協定 2.5 節 `POST /v1/ranch/avatar` `{breed}`）：[breed] 是品種代號，只能選圖鑑發現過的
  /// （沒發現回 409 avatar_locked）。
  Future<Map<String, dynamic>> setAvatar(String breed);

  // ---- v0.3 C1 照顧（協定 2.6） ----
  /// 清大便（免費）：[piles] 是每頭牛清幾坨（比那頭牛現有的多就清到 0）；null 是全部清。
  /// 回應有 `cleaned`（清了幾坨）、`poop`（同 `state.poop`）、`coins`、`state`。
  Future<Map<String, dynamic>> clean(Map<Object, int>? piles);

  /// 治療一頭病牛（`economy.cure_price` 幣，馬上好）。回應有 `cow_id`、`cost`、`cow`、`coins`、`state`；
  /// 錯誤 `cow_not_found`、`cow_not_sick`、`not_enough_coins`。
  Future<Map<String, dynamic>> cure(Object cowId);

  // ---- v0.3 C1b 圖鑑的配種表（協定 2.7） ----
  /// 每個品種的代表配法（`GET /v1/codex/pairings`，固定資料，同一版伺服器不會變）：品種 → 4 組 `{sire, dam}`。
  Future<Map<String, List<BreedPair>>> codexPairings();

  Future<StudMarket> stud();
  Future<BreedPreview> studPreview(Object listingId, Object dam);

  /// 上架：借種費由系統算，不帶價格（D26）。
  Future<Map<String, dynamic>> studList(Object cowId);
  Future<Map<String, dynamic>> studUnlist(Object listingId);

  /// 借種：[price] 是預覽看到的借種費（fee.price）；這一刻的價格不一樣就回 409 price_changed（detail.price）。
  Future<BreedResult> studBorrow(Object listingId, Object dam, {required int price});

  /// 借種紀錄（協定 4.6）。
  Future<StudLog> studLog();

  // ---- 帳號（協定第 5 節） ----
  /// 拿 nonce（協定 5.1；不用 token）：每次叫出 Apple／Google 的登入畫面前拿一個，只能用一次。
  Future<String> accountNonce();

  /// 綁定 Apple／Google 帳號（協定 5.2）：成功回綁定的帳號（`account.links`）。
  /// 帳號已經綁了別的牧場回 409 `account_in_use`（detail 是 [LinkConflict]）；憑證不對回 `sign_in_failed`。
  Future<List<AccountLink>> linkAccount({
    required SignInProvider provider,
    required String idToken,
    required String nonce,
    String? authorizationCode,
    required String requestId,
  });

  /// 解除綁定（協定 5.4）：回剩下的綁定。
  Future<List<AccountLink>> unlinkAccount(SignInProvider provider, {required String requestId});

  /// 找回牧場（協定 5.5；不用 token）：新手機或重裝後用綁定的帳號登入，伺服器發那個牧場的新 token，
  /// 原本的 token 全部失效（舊手機收到 signed_in_elsewhere）。帳號沒有綁牧場回 `account_not_linked`（S14-03）。
  /// 找回可以重來：沒收到回應就重新登入再找回一次，伺服器再發一個新 token。
  Future<Session> recoverAccount({
    required SignInProvider provider,
    required String idToken,
    required String nonce,
    required String requestId,
  });

  /// 換回那個牧場（協定 5.3）：伺服器刪掉這支手機現在的牧場、發那個牧場的新 token。[ticket] 只能用一次，
  /// 沒收到回應時用同一個 [ticket]、[requestId] 原封不動重送，10 分鐘內拿到第一次的回應。
  Future<Session> switchAccount({required String ticket, required String requestId});

  /// 刪除牧場（協定 5.6）。[requestId] 由呼叫的人給：沒收到回應、玩家再按一次時用同一個，
  /// 第一次其實刪掉了的話，伺服器 10 分鐘內回第一次的回應（`deleted: true`），不是 401。
  Future<void> deleteRanch({required String requestId});
}
