import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'game_api.dart';
import 'models.dart';

/// 用 HTTP 呼叫伺服器的資料層。
///
/// - 有 token 就帶 `Authorization: Bearer <token>`（`POST /v1/session`、`GET /v1/status` 不需要）。
/// - 會改變狀態的請求每次產生新的 request_id（UUID v4）；網路失敗重送時沿用同一個，
///   伺服器就會回第一次的結果，不會重複成交（協定 1.3）。
/// - 只在「沒收到回應」時重送（連線失敗、逾時、502／504、沒有錯誤本文的 503）；
///   收到 4xx、500 或 503 maintenance 就直接把錯誤交給畫面。
class HttpGameApi implements GameApi {
  HttpGameApi({
    required this.base,
    http.Client? client,
    Uuid? uuid,
    this.maxAttempts = 3,
    this.timeout = const Duration(seconds: 10),
    Future<void> Function(Duration)? sleep,
  }) : _client = client ?? http.Client(),
       _uuid = uuid ?? const Uuid(),
       _sleep = sleep ?? Future<void>.delayed;

  final Uri base;
  final http.Client _client;
  final Uuid _uuid;
  final int maxAttempts;
  final Duration timeout;
  final Future<void> Function(Duration) _sleep;

  @override
  String? token;

  static const _retryStatus = {502, 503, 504};

  Uri _uri(String path, [Map<String, String>? query]) {
    final basePath = base.path.endsWith('/') ? base.path.substring(0, base.path.length - 1) : base.path;
    return base.replace(path: '$basePath$path', queryParameters: query);
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() doRequest) async {
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) await _sleep(Duration(milliseconds: 300 * (1 << (attempt - 1))));
      http.Response res;
      try {
        res = await doRequest().timeout(timeout);
      } on http.ClientException catch (e) {
        lastError = e;
        continue;
      } on TimeoutException catch (e) {
        lastError = e;
        continue;
      }
      // 503 有兩種：伺服器回的「維護中」（有錯誤本文，直接交給畫面），和反向代理回的連不上（重送）
      if (_retryStatus.contains(res.statusCode) && !_isMaintenance(res)) {
        lastError = 'HTTP ${res.statusCode}';
        continue;
      }
      return _decode(res);
    }
    throw NetworkException(lastError ?? 'unknown');
  }

  static bool _isMaintenance(http.Response res) {
    if (res.statusCode != 503) return false;
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      return body is Map && body['error'] is Map && (body['error'] as Map)['code'] == 'maintenance';
    } on FormatException {
      return false;
    }
  }

  Map<String, dynamic> _decode(http.Response res) {
    Object? body;
    try {
      body = res.body.isEmpty ? const <String, dynamic>{} : jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      body = null;
    }
    if (res.statusCode >= 400) {
      final err = body is Map && body['error'] is Map ? (body['error'] as Map) : const {};
      throw ApiException(
        res.statusCode,
        '${err['code'] ?? 'http_${res.statusCode}'}',
        '${err['message'] ?? 'HTTP ${res.statusCode}'}',
        err['detail'] is Map ? (err['detail'] as Map).cast<String, dynamic>() : const {},
      );
    }
    if (body is Map) return body.cast<String, dynamic>();
    return {'data': body};
  }

  Future<Map<String, dynamic>> _get(String path, [Map<String, String>? query]) =>
      _send(() => _client.get(_uri(path, query), headers: _headers));

  /// 不會改變狀態的 POST（例如試算）。
  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) =>
      _send(() => _client.post(_uri(path), headers: _headers, body: jsonEncode(body)));

  /// 會改變狀態的 POST：產生一次 request_id，重送時沿用。
  Future<Map<String, dynamic>> _mutate(String path, Map<String, dynamic> body) {
    final payload = {...body, 'request_id': _uuid.v4()};
    final encoded = jsonEncode(payload);
    return _send(() => _client.post(_uri(path), headers: _headers, body: encoded));
  }

  @override
  Future<Session> createSession(String ranchName) async =>
      Session.fromJson(await _mutate('/v1/session', {'ranch_name': ranchName}));

  @override
  Future<ServerStatus> status() async => ServerStatus.fromJson(await _get('/v1/status'));

  @override
  Future<GameState> getState() async => GameState.fromJson(await _get('/v1/state'));

  @override
  Future<Map<String, dynamic>> collect() => _mutate('/v1/collect', const {});

  @override
  Future<SellQuote> sellQuote(Commodity commodity, double qty) async =>
      SellQuote.fromJson(await _post('/v1/sell/quote', {'commodity': commodity.wire, 'qty': qty}));

  @override
  Future<SellResult> sell(Commodity commodity, double qty) async =>
      SellResult.fromJson(await _mutate('/v1/sell', {'commodity': commodity.wire, 'qty': qty}));

  @override
  Future<ShipResult> ship(Object cowId) async => ShipResult.fromJson(await _mutate('/v1/ship', {'cow_id': cowId}));

  @override
  Future<BreedPreview> breedPreview(Object sire, Object dam) async =>
      BreedPreview.fromJson(await _get('/v1/breed/preview', {'sire': '$sire', 'dam': '$dam'}));

  @override
  Future<BreedResult> breed(Object sire, Object dam) async =>
      BreedResult.fromJson(await _mutate('/v1/breed', {'sire': sire, 'dam': dam}));

  @override
  Future<Map<String, dynamic>> upgrade(UpgradeKind kind) => _mutate('/v1/upgrade', {'kind': kind.wire});

  @override
  Future<MarketInfo> market() async => MarketInfo.fromJson(await _get('/v1/market'));

  @override
  Future<List<PricePoint>> marketHistory(Commodity commodity, String range) async {
    final j = await _get('/v1/market/history', {'commodity': commodity.wire, 'range': range});
    return PricePoint.listFrom(j['points'] ?? j['history'] ?? j['data']);
  }

  @override
  Future<Leaderboard> leaderboard(RankKind kind) async =>
      Leaderboard.fromJson(await _get('/v1/leaderboard', {'kind': kind.wire}));

  // ---- v0.2 ----
  @override
  Future<ShipPreview> shipPreview(Object cowId) async =>
      ShipPreview.fromJson(await _get('/v1/ship/preview', {'cow_id': '$cowId'}));

  @override
  Future<ShopInfo> shop() async => ShopInfo.fromJson(await _get('/v1/shop'));

  @override
  Future<ShopBuyResult> shopBuy(String grade) async =>
      ShopBuyResult.fromJson(await _mutate('/v1/shop/buy', {'grade': grade}));

  @override
  Future<Map<String, dynamic>> fieldAssign(Object cowId, {int? field}) =>
      _mutate('/v1/field/assign', {'cow_id': cowId, 'field': ?field});

  @override
  Future<Map<String, dynamic>> fieldRecall(Object cowId) => _mutate('/v1/field/recall', {'cow_id': cowId});

  @override
  Future<Map<String, dynamic>> fieldHarvest() => _mutate('/v1/field/harvest', const {});

  @override
  Future<Map<String, dynamic>> fieldExpand() => _mutate('/v1/field/expand', const {});

  @override
  Future<StudMarket> stud() async => StudMarket.fromJson(await _get('/v1/stud'));

  @override
  Future<BreedPreview> studPreview(Object listingId, Object dam) async =>
      BreedPreview.fromJson(await _get('/v1/stud/preview', {'listing_id': '$listingId', 'dam': '$dam'}));

  @override
  Future<Map<String, dynamic>> studList(Object cowId) => _mutate('/v1/stud/list', {'cow_id': cowId});

  @override
  Future<Map<String, dynamic>> studUnlist(Object listingId) => _mutate('/v1/stud/unlist', {'listing_id': listingId});

  @override
  Future<BreedResult> studBorrow(Object listingId, Object dam, {required int price}) async =>
      BreedResult.fromJson(await _mutate('/v1/stud/borrow', {'listing_id': listingId, 'dam': dam, 'price': price}));
}
