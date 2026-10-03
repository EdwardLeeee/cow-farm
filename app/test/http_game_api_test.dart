import 'dart:convert';

import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/api/http_game_api.dart';
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/auth/sign_in.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes.dart';

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
        utf8.encode(
          jsonEncode({
            'error': {'code': 'not_enough_coins', 'message': '金幣不夠'},
          }),
        ),
        400,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = HttpGameApi(base: base, client: client, sleep: noSleep)..token = 'tok';
    await expectLater(
      api.shopBuy('A'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'not_enough_coins')
            .having((e) => e.message, 'message', '金幣不夠'),
      ),
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
    final s = await api.createSession('小花的快樂牧場');
    expect(s.token, 't1');
    expect(s.playerId, 7);
    final session = seen['/v1/session']!;
    expect(session.headers.containsKey('Authorization'), isFalse);
    // 取好名字才建立（協定 2.1）；帶 request_id，逾時重送時拿回同一個牧場
    expect(jsonDecode(session.body), containsPair('ranch_name', '小花的快樂牧場'));
    expect((jsonDecode(session.body) as Map)['request_id'], isA<String>());
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
      return http.Response(
        jsonEncode({
          'points': [
            [1, 2.5],
            [2, 3.0],
          ],
        }),
        200,
      );
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
    await api.studList(2);
    await api.studUnlist(4);
    await api.studBorrow(4, 1, price: 530);
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
    expect(body(6).containsKey('price'), isFalse, reason: '借種費由系統算（D26），上架不帶價格');
    expect(body(8), containsPair('listing_id', 4));
    expect(body(8), containsPair('dam', 1));
    expect(body(8), containsPair('price', 530), reason: '借種要帶預覽看到的價格（協定 4.4）');
    for (var i = 0; i < 9; i++) {
      expect(body(i)['request_id'], isA<String>(), reason: reqs[i].url.path);
    }
    expect(reqs[9].url.queryParameters, {'cow_id': '3'});
    expect(reqs[10].url.queryParameters, {'listing_id': '4', 'dam': '1'});
  });

  test('借種紀錄（協定 4.6）：借出、借入；對方的牧場刪除了是 null', () async {
    final client = MockClient((req) async {
      expect(req.method, 'GET');
      expect(req.url.path, '/v1/stud/log');
      return http.Response(
        jsonEncode({
          'server_time': 1791141900.0,
          'keep_days': 30,
          'income_total': 1510,
          'entries': [
            {
              'kind': 'out',
              't': 1791141900.0,
              'price': 60,
              'bull': {'id': 2, 'breed': 'yellow'},
              'calf': null,
              'ranch': {
                'player_id': 12,
                'name': null,
                'name_words': [0, 1, 0],
                'is_bot': true,
                'level': 4,
              },
            },
            {
              'kind': 'in',
              't': 1791138300.0,
              'price': 970,
              'bull': {'id': null, 'breed': 'angus'},
              'calf': {'id': 9, 'breed': 'galloway'},
              'ranch': null,
            },
          ],
        }),
        200,
      );
    });
    final log = await (HttpGameApi(base: base, client: client, sleep: noSleep)..token = 'tok').studLog();
    expect(log.keepDays, 30);
    expect(log.incomeTotal, 1510);
    expect(log.entries, hasLength(2));
    final (out, inn) = (log.entries[0], log.entries[1]);
    expect((out.out, out.price, out.bullBreed, out.bullId, out.calfBreed), (true, 60, 'yellow', 2, null));
    expect(out.ranch?.nameWords, [0, 1, 0]);
    expect((inn.out, inn.price, inn.bullId, inn.calfId, inn.calfBreed), (false, 970, null, 9, 'galloway'));
    expect(inn.ranch, isNull);
  });

  test('錯誤：帶 detail；503 維護中不重送，交給畫面（S16-01）', () async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      if (req.url.path == '/v1/state') {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'maintenance',
              'message': '維護中',
              'detail': {'ends_at_real': 1790784000.0},
            },
          }),
          503,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response(
        jsonEncode({
          'error': {
            'code': 'not_enough_coins',
            'message': '金幣不夠',
            'detail': {'need': 1000, 'have': 414},
          },
        }),
        409,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = HttpGameApi(base: base, client: client, sleep: noSleep)..token = 'tok';
    await expectLater(api.getState(), throwsA(isA<ApiException>().having((e) => e.maintenance, 'maintenance', isTrue)));
    expect(calls, 1, reason: '維護中的 503 不重送');
    await expectLater(
      api.upgrade(UpgradeKind.bucket),
      throwsA(isA<ApiException>().having((e) => e.detail, 'detail', {'need': 1000, 'have': 414})),
    );
  });

  test('沒有錯誤本文的 503（反向代理）照樣重送', () async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      return calls < 3 ? http.Response('Service Unavailable', 503) : http.Response(jsonEncode({'coins': 1}), 200);
    });
    final api = HttpGameApi(base: base, client: client, sleep: noSleep)..token = 'tok';
    await api.collect();
    expect(calls, 3);
  });

  test('刪除牧場（協定 5.6）：用給的 request_id，沒收到回應重送也是同一個', () async {
    final reqs = <http.Request>[];
    final client = MockClient((req) async {
      reqs.add(req);
      if (reqs.length == 1) throw http.ClientException('timeout');
      return http.Response(jsonEncode({'deleted': true}), 200);
    });
    final api = HttpGameApi(base: base, client: client, sleep: noSleep)..token = 'tok';
    await api.deleteRanch(requestId: '6f1c8e2a-3b4d-4e5f-8a9b-0c1d2e3f4a5b');
    expect(reqs, hasLength(2));
    for (final r in reqs) {
      expect(r.url.path, '/v1/account/delete');
      expect(r.headers['Authorization'], 'Bearer tok');
      expect(jsonDecode(r.body), {'request_id': '6f1c8e2a-3b4d-4e5f-8a9b-0c1d2e3f4a5b'});
    }
  });

  group('備份牧場（協定 5.1–5.4）', () {
    test('nonce：POST /v1/account/nonce，回 nonce', () async {
      late http.Request req;
      final client = MockClient((r) async {
        req = r;
        return http.Response(jsonEncode({'nonce': 'pX3v0Qm8', 'expires_at_real': 1790772011.2}), 200);
      });
      final api = HttpGameApi(base: base, client: client, sleep: noSleep)..token = 'tok';
      expect(await api.accountNonce(), 'pX3v0Qm8');
      expect(req.method, 'POST');
      expect(req.url.path, '/v1/account/nonce');
      expect(jsonDecode(req.body), <String, dynamic>{});
    });

    test('綁定：Apple 帶 authorization_code、Google 不帶；回 account.links', () async {
      final reqs = <http.Request>[];
      final client = MockClient((r) async {
        reqs.add(r);
        final provider = (jsonDecode(r.body) as Map)['provider'];
        return http.Response(
          jsonEncode({
            'linked': {'provider': provider, 'linked_at_real': 1790771411.2},
            'account': {
              'links': [
                {'provider': provider, 'linked_at_real': 1790771411.2},
              ],
            },
          }),
          200,
        );
      });
      final api = HttpGameApi(base: base, client: client, sleep: noSleep)..token = 'tok';
      final links = await api.linkAccount(
        provider: SignInProvider.apple,
        idToken: 'eyJ.apple',
        nonce: 'n1',
        authorizationCode: 'c1',
        requestId: 'r1',
      );
      expect(links.single.provider, 'apple');
      expect(links.single.linkedAtReal, 1790771411.2);
      await api.linkAccount(provider: SignInProvider.google, idToken: 'eyJ.google', nonce: 'n2', requestId: 'r2');
      expect(reqs.map((r) => r.url.path), ['/v1/account/link', '/v1/account/link']);
      expect(reqs.first.headers['Authorization'], 'Bearer tok');
      expect(jsonDecode(reqs[0].body), {
        'provider': 'apple',
        'id_token': 'eyJ.apple',
        'nonce': 'n1',
        'authorization_code': 'c1',
        'request_id': 'r1',
      });
      expect(jsonDecode(reqs[1].body), {
        'provider': 'google',
        'id_token': 'eyJ.google',
        'nonce': 'n2',
        'request_id': 'r2',
      });
    });

    test('帳號已經綁了別的牧場：409 account_in_use，detail 讀成那個牧場和 switch_ticket', () async {
      final client = MockClient(
        (r) async => _json({
          'error': {
            'code': 'account_in_use',
            'message': '這個帳號已經綁了別的牧場',
            'detail': {
              'provider': 'apple',
              'ranch': {'player_id': 17, 'name': '青草小丘農莊', 'name_words': null, 'is_bot': false, 'level': 5},
              'switch_ticket': 't9Qx',
              'ticket_expires_at_real': 1790772011.2,
            },
          },
        }, 409),
      );
      final api = HttpGameApi(base: base, client: client, sleep: noSleep)..token = 'tok';
      try {
        await api.linkAccount(provider: SignInProvider.apple, idToken: 'x', nonce: 'n', requestId: 'r');
        fail('應該丟 ApiException');
      } on ApiException catch (e) {
        expect(e.code, 'account_in_use');
        expect(e.token, 'tok', reason: '錯誤帶著送出時的 token');
        final c = LinkConflict.fromDetail(e.detail)!;
        expect(c.ticket, 't9Qx');
        expect(c.ranch.playerId, 17);
        expect(c.ranch.name, '青草小丘農莊');
        expect(c.ranch.level, 5);
      }
    });

    test('換回：帶 switch_ticket 和給的 request_id，沒收到回應重送也一樣；回新的 token 和那個牧場', () async {
      final reqs = <http.Request>[];
      final client = MockClient((r) async {
        reqs.add(r);
        if (reqs.length == 1) throw http.ClientException('timeout');
        return _json({
          'token': 'Zk1',
          'player_id': 17,
          'ranch_name': '青草小丘農莊',
          'created': false,
          'state': sampleStateJson(),
        });
      });
      final api = HttpGameApi(base: base, client: client, sleep: noSleep)..token = 'tok';
      final s = await api.switchAccount(ticket: 't9Qx', requestId: 'r9');
      expect(s.token, 'Zk1');
      expect(s.playerId, 17);
      expect(s.created, isFalse);
      expect(s.state, isNotNull);
      expect(reqs, hasLength(2));
      for (final r in reqs) {
        expect(r.url.path, '/v1/account/switch');
        expect(jsonDecode(r.body), {'switch_ticket': 't9Qx', 'request_id': 'r9'});
      }
    });

    test('解除：POST /v1/account/unlink，回剩下的綁定', () async {
      late http.Request req;
      final client = MockClient((r) async {
        req = r;
        return http.Response(
          jsonEncode({
            'account': {
              'links': [
                {'provider': 'google', 'linked_at_real': 1790771411.2},
              ],
            },
          }),
          200,
        );
      });
      final api = HttpGameApi(base: base, client: client, sleep: noSleep)..token = 'tok';
      final links = await api.unlinkAccount(SignInProvider.apple, requestId: 'r3');
      expect(links.map((l) => l.provider), ['google']);
      expect(req.url.path, '/v1/account/unlink');
      expect(jsonDecode(req.body), {'provider': 'apple', 'request_id': 'r3'});
    });
  });
}

/// UTF-8 的 JSON 回應（http.Response 的字串預設用 latin1，中文會出錯）。
http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
