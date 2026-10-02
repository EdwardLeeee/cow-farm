import 'models.dart';

/// 伺服器回的錯誤：`{"error": {"code": "...", "message": "...", "detail": {...}}}`（協定 1.4）。
///
/// 畫面依 [code] 顯示字串表的文案（Strings.errorText），**不顯示** [message]（只供除錯）。
class ApiException implements Exception {
  const ApiException(this.status, this.code, this.message, [this.detail = const {}]);
  final int status;
  final String code;
  final String message;
  final Map<String, dynamic> detail;

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

  Future<StudMarket> stud();
  Future<BreedPreview> studPreview(Object listingId, Object dam);

  /// 上架：借種費由系統算，不帶價格（D26）。
  Future<Map<String, dynamic>> studList(Object cowId);
  Future<Map<String, dynamic>> studUnlist(Object listingId);

  /// 借種：[price] 是預覽看到的借種費（fee.price）；這一刻的價格不一樣就回 409 price_changed（detail.price）。
  Future<BreedResult> studBorrow(Object listingId, Object dam, {required int price});

  /// 借種紀錄（協定 4.6）。
  Future<StudLog> studLog();
}
