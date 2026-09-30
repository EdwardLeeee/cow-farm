import 'dart:convert';

import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/api/http_game_api.dart';
import 'package:cowfarm/api/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final base = Uri.parse('http://127.0.0.1:8787');
  Future<void> noSleep(Duration _) async {}

  test('網路失敗重送時沿用同一個 request_id', () async {
    final bodies = <Map<String, dynamic>>[];
    var n = 0;
    final client = MockClient((req) async {
      bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
      n++;
      if (n == 1) throw http.ClientException('connection reset');
      if (n == 2) return http.Response('bad gateway', 502);
      return http.Response(jsonEncode({'qty': 5, 'avg_price': 9.5, 'total': 47.5, 'price_after': 9.4}), 200);
    });
    final api = HttpGameApi(base: base, client: client, sleep: noSleep)..token = 'tok';
    final r = await api.sell(Commodity.milk, 5);
    expect(r.total, 47.5);
    expect(bodies, hasLength(3));
    final ids = bodies.map((b) => b['request_id']).toSet();
    expect(ids, hasLength(1));
    expect(ids.single, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(bodies.first['commodity'], 'milk');
  });

  test('每個新操作用新的 request_id', () async {
    final ids = <String>[];
    final client = MockClient((req) async {
      ids.add((jsonDecode(req.body) as Map)['request_id'] as String);
      return http.Response('{}', 200);
    });
    final api = HttpGameApi(base: base, client: client, sleep: noSleep)..token = 'tok';
    await api.collect();
    await api.collect();
    await api.upgrade(UpgradeKind.bucket);
    expect(ids.toSet(), hasLength(3));
  });

  test('4xx 不重送，錯誤訊息照伺服器的繁中顯示', () async {
    var n = 0;
    final client = MockClient((req) async {
      n++;
      return http.Response.bytes(
        utf8.encode(jsonEncode({'error': {'code': 'not_enough_coins', 'message': '金幣不夠'}})),
        400,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = HttpGameApi(base: base, client: client, sleep: noSleep)..token = 'tok';
    await expectLater(
      api.shopBuy('A'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'not_enough_coins').having((e) => e.message, 'message', '金幣不夠')),
    );
    expect(n, 1);
  });

  test('一直連不上就丟 NetworkException', () async {
    final client = MockClient((req) async => throw http.ClientException('down'));
    final api = HttpGameApi(base: base, client: client, sleep: noSleep, maxAttempts: 3)..token = 'tok';
    await expectLater(api.getState(), throwsA(isA<NetworkException>()));
  });

  test('帶 Bearer token；建立帳號不帶；試算不帶 request_id', () async {
    final seen = <String, http.Request>{};
    final client = MockClient((req) async {
      seen[req.url.path] = req;
      if (req.url.path == '/v1/session') {
        return http.Response(jsonEncode({'token': 't1', 'player_id': 7, 'ranch_name': 'x'}), 200);
      }
      return http.Response(jsonEncode({'qty': 1, 'avg_price': 1, 'total': 1, 'market_price': 1}), 200);
    });
    final api = HttpGameApi(base: base, client: client, sleep: noSleep);
    final s = await api.createSession();
    expect(s.token, 't1');
    expect(seen['/v1/session']!.headers.containsKey('Authorization'), isFalse);
    api.token = s.token;
    await api.sellQuote(Commodity.beef, 3);
    final q = seen['/v1/sell/quote']!;
    expect(q.headers['Authorization'], 'Bearer t1');
    expect((jsonDecode(q.body) as Map).containsKey('request_id'), isFalse);
  });

  test('GET 查詢參數', () async {
    late Uri url;
    final client = MockClient((req) async {
      url = req.url;
      return http.Response(jsonEncode({'points': [[1, 2.5], [2, 3.0]]}), 200);
    });
    final api = HttpGameApi(base: base, client: client, sleep: noSleep)..token = 'tok';
    final pts = await api.marketHistory(Commodity.milk, '7d');
    expect(url.toString(), 'http://127.0.0.1:8787/v1/market/history?commodity=milk&range=7d');
    expect(pts.map((p) => p.price), [2.5, 3.0]);
  });

  test('v0.2 端點：路徑、欄位與 request_id', () async {
    final reqs = <http.Request>[];
    final client = MockClient((req) async {
      reqs.add(req);
      return http.Response(jsonEncode({'ok': true}), 200);
    });
    final api = HttpGameApi(base: base, client: client, sleep: noSleep)..token = 'tok';
    await api.shopBuy('C');
    await api.fieldAssign(2);
    await api.fieldAssign(2, field: 1);
    await api.fieldRecall(2);
    await api.fieldHarvest();
    await api.fieldExpand();
    await api.studList(2, 800);
    await api.studUnlist(4);
    await api.studBorrow(4, 1);
    await api.shipPreview(3);
    await api.studPreview(4, 1);
    Map<String, dynamic> body(int i) => jsonDecode(reqs[i].body) as Map<String, dynamic>;
    expect(reqs.map((r) => r.url.path).toList(), [
      '/v1/shop/buy',
      '/v1/field/assign',
      '/v1/field/assign',
      '/v1/field/recall',
      '/v1/field/harvest',
      '/v1/field/expand',
      '/v1/stud/list',
      '/v1/stud/unlist',
      '/v1/stud/borrow',
      '/v1/ship/preview',
      '/v1/stud/preview',
    ]);
    expect(body(0)['grade'], 'C');
    expect(body(1).containsKey('field'), isFalse); // 省略 = 找第一塊空田
    expect(body(2)['field'], 1);
    expect(body(6)['price'], 800);
    expect(body(8), containsPair('listing_id', 4));
    expect(body(8), containsPair('dam', 1));
    for (var i = 0; i < 9; i++) {
      expect(body(i)['request_id'], isA<String>(), reason: reqs[i].url.path);
    }
    expect(reqs[9].url.queryParameters, {'cow_id': '3'});
    expect(reqs[10].url.queryParameters, {'listing_id': '4', 'dam': '1'});
  });
}
