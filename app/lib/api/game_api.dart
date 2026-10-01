import 'models.dart';

/// 伺服器回的錯誤：`{"error": {"code": "...", "message": "<繁中>"}}`。
class ApiException implements Exception {
  const ApiException(this.status, this.code, this.message);
  final int status;
  final String code;
  final String message; // 伺服器給的繁中訊息，直接顯示

  bool get unauthorized => status == 401;

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

  Future<Session> createSession();
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

  /// 商店抽牛（grade 是 A／B／C）。`POST /v1/buy_calf` 已停用（410）。
  Future<ShopBuyResult> shopBuy(String grade);

  Future<Map<String, dynamic>> fieldAssign(Object cowId, {int? field});
  Future<Map<String, dynamic>> fieldRecall(Object cowId);
  Future<Map<String, dynamic>> fieldHarvest();
  Future<Map<String, dynamic>> fieldExpand();

  Future<StudMarket> stud();
  Future<BreedPreview> studPreview(Object listingId, Object dam);
  Future<Map<String, dynamic>> studList(Object cowId, double price);
  Future<Map<String, dynamic>> studUnlist(Object listingId);
  Future<BreedResult> studBorrow(Object listingId, Object dam);
}
