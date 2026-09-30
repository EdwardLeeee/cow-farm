import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'game_api.dart';
import 'models.dart';

/// 用 HTTP 呼叫伺服器的資料層。
///
/// - 除了 `POST /v1/session` 以外都帶 `Authorization: Bearer <token>`。
/// - 會改變狀態的請求每次產生新的 request_id（UUID v4）；網路失敗重送時沿用同一個，
///   伺服器就會回第一次的結果，不會重複成交。
/// - 只在「沒收到回應」時重送（連線失敗、逾時、502/503/504）；收到 4xx 就直接把錯誤交給畫面。
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
      if (_retryStatus.contains(res.statusCode)) {
        lastError = 'HTTP ${res.statusCode}';
        continue;
      }
      return _decode(res);
    }
    throw NetworkException(lastError ?? 'unknown');
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
  Future<Session> createSession() async => Session.fromJson(await _post('/v1/session', const {}));

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
  Future<Map<String, dynamic>> ship(Object cowId) => _mutate('/v1/ship', {'cow_id': cowId});

  @override
  Future<Map<String, dynamic>> buyCalf(CowType type, bool bull) =>
      _mutate('/v1/buy_calf', {'type': type.wire, 'bull': bull});

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
}
