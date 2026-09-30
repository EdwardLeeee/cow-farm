import 'dart:math';

import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/api/push.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/storage/token_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class _ExpiredTokenApi extends FakeGameApi {
  @override
  Future<GameState> getState() async {
    if (token == 'old') throw const ApiException(401, 'unauthorized', '請重新登入');
    return super.getState();
  }
}

void main() {
  group('斷線重連的等待時間', () {
    test('指數增加、加隨機（full jitter），最多 5 秒', () {
      final b = Backoff(random: Random(1));
      for (var i = 0; i < 40; i++) {
        final d = b.delay(i);
        expect(d, lessThanOrEqualTo(const Duration(seconds: 5)));
        expect(d, greaterThanOrEqualTo(const Duration(milliseconds: 50)));
      }
      // 第 n 次在 random(0, min(5, 0.5 × 2^n)) 秒
      var max0 = 0, max3 = 0, max10 = 0;
      for (var s = 0; s < 200; s++) {
        final r = Backoff(random: Random(s));
        max0 = max(max0, r.delay(0).inMilliseconds);
        max3 = max(max3, r.delay(3).inMilliseconds);
        max10 = max(max10, r.delay(10).inMilliseconds);
      }
      expect(max0, inInclusiveRange(400, 500));
      expect(max3, inInclusiveRange(3500, 4000));
      expect(max10, inInclusiveRange(4500, 5000));
    });

    test('隨機的部分讓每支手機不同', () {
      final a = Backoff(random: Random(1)).delay(6);
      final b = Backoff(random: Random(2)).delay(6);
      expect(a, isNot(b));
    });
  });

  group('GameModel', () {
    test('沒有 token 就建立訪客帳號並存起來，然後連 WebSocket', () async {
      final api = FakeGameApi();
      final push = FakePush();
      final store = MemoryTokenStore();
      final m = GameModel(api: api, push: push, tokens: store, uiTick: null);
      await m.start();
      expect(api.calls.first, 'session');
      expect(store.values[TokenStore.tokenKey], 'tok-new');
      expect(api.token, 'tok-new');
      expect(push.token, 'tok-new');
      expect(m.ranchName, '晨光草原牧場');
      expect(m.state, isNotNull);
      expect(m.market, isNotNull);
      m.dispose();
    });

    test('已有 token 就沿用，不再建立帳號', () async {
      final api = FakeGameApi();
      final m = GameModel(
        api: api,
        push: FakePush(),
        tokens: MemoryTokenStore({TokenStore.tokenKey: 'saved'}),
        uiTick: null,
      );
      await m.start();
      expect(api.calls, isNot(contains('session')));
      expect(api.token, 'saved');
      m.dispose();
    });

    test('伺服器不認得 token（401）就重新建立帳號', () async {
      final api = _ExpiredTokenApi();
      final store = MemoryTokenStore({TokenStore.tokenKey: 'old'});
      final m = GameModel(api: api, push: FakePush(), tokens: store, uiTick: null);
      await m.start();
      expect(api.calls, contains('session'));
      expect(store.values[TokenStore.tokenKey], 'tok-new');
      expect(m.state, isNotNull);
      m.dispose();
    });

    test('遊戲時間用單調時鐘推算，不看手機的日期時間', () async {
      final clock = FakeClock();
      final (m, _, _) = await loadedModel(clock: clock);
      expect(m.gameNow, t0);
      clock.t += 25; // 現實 25 秒 × 144 = 遊戲 1 小時
      expect(m.gameNow, t0 + 3600);
      expect(m.bucketNow, closeTo(6 + 12, 1e-9));
      // 重新拿 state 後以伺服器為準
      await m.refreshState();
      expect(m.gameNow, t0);
    });

    test('WebSocket token 無效（4401）就重新建立帳號並用新 token 重連', () async {
      final (m, api, push) = await loadedModel();
      push.emit(const PushAuthFailed('tok'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(api.calls, contains('session'));
      expect(api.token, 'tok-new');
      expect(push.token, 'tok-new');
      m.dispose();
    });

    test('奶桶跨過新手期結束時改用一般產量', () async {
      final api = FakeGameApi();
      api.stateJson['bucket'] = {
        'qty': 0.0,
        'capacity': 100.0,
        'per_hour': 50.0,
        'boost': {'mult': 5.0, 'until': t0 + 1800},
      };
      final clock = FakeClock();
      final (m, _, _) = await loadedModel(api: api, clock: clock);
      clock.t += 25; // 遊戲 1 小時：前半小時 50/時，後半小時 10/時
      expect(m.bucketNow, closeTo(25 + 5, 1e-9));
    });

    test('斷線時操作不送出', () async {
      final (m, api, _) = await loadedModel(connected: false);
      final r = await m.collect();
      expect(r.ok, isFalse);
      expect(api.calls, isNot(contains('collect')));
    });

    test('推播新聞不重複', () async {
      final (m, _, push) = await loadedModel();
      final n = m.market!.news.length;
      push.emit(const NewsPush(NewsItem(id: 'x1', title: 'a')));
      push.emit(const NewsPush(NewsItem(id: 'x1', title: 'a')));
      await Future<void>.delayed(Duration.zero);
      expect(m.market!.news.length, n + 1);
      expect(m.market!.news.first.id, 'x1');
    });
  });

  group('models', () {
    test('協定欄位解析', () {
      final s = GameState.fromJson(sampleStateJson());
      expect(s.cows, hasLength(3));
      expect(s.cows[1].bull, isTrue);
      expect(s.cows[2].stage, CowStage.calf);
      expect(s.upgrades[UpgradeKind.fresh]!.cost, isNull);
      expect(s.upgrades[UpgradeKind.bucket]!.cost, 200);
      expect(s.calfPrice(CowType.beef), 1000);
      expect(s.upgrades[UpgradeKind.bucket]!.next, 36);
      expect(s.codex, {(type: CowType.dairy, tier: 0), (type: CowType.dual, tier: 1)});
      expect(s.warehouse.milkTotal, 150.5);
      expect(s.warehouse.worstFreshness, 0.8);
    });

    test('另一種寫法也讀得懂（規格表的簡寫）', () {
      final s = GameState.fromJson({
        'server_time': 100,
        'time_scale': 144,
        'coins': 5,
        'cows': [
          {'id': 'a', 'type': 1, 'sex': 'M', 'tier': 2, 'stage': 'calf', 'breed_cooldown_s': 60},
        ],
        'bucket': {'amount': 3, 'capacity': 10, 'rate_per_h': 2},
        'warehouse': {
          'milk': [{'qty': 4}],
          'beef': [],
          'capacity': 50,
        },
        'pen': {'slots': 2, 'used': 1, 'next_cost': 280, 'next_open_at': 500},
        'upgrades': {'bucket': 200, 'fresh': null},
        'codex': {'dairy': [0, 3]},
        'calf_price': 900,
      });
      expect(s.cows.single.type, CowType.dual);
      expect(s.cows.single.bull, isTrue);
      expect(s.cows.single.readyAt, 160);
      expect(s.bucket.amount, 3);
      expect(s.bucket.perHour, 2);
      expect(s.warehouse.milkTotal, 4);
      expect(s.upgrades[UpgradeKind.pen]!.openAt, 500);
      expect(s.upgrades[UpgradeKind.bucket]!.cost, 200);
      expect(s.calfPrice(CowType.dairy), 900);
      expect(s.codex, {(type: CowType.dairy, tier: 0), (type: CowType.dairy, tier: 3)});
    });

    test('WS 行情訊息', () {
      final msg = PushMessage.fromJson({
        'type': 'market',
        'server_time': 5,
        'milk': {'price': 10.1, 'change_24h': 0.2},
        'beef': {'price': 12.3, 'change_24h': -0.1},
      });
      expect(msg, isA<MarketPush>());
      final mp = msg as MarketPush;
      expect(mp.quotes[Commodity.beef]!.price, 12.3);
      expect(PushMessage.fromJson({'type': 'hello'}), isNull);
      // 伺服器的新聞推播是攤平的
      final news = PushMessage.fromJson({'type': 'news', 'id': 7, 'title': '烤肉季開跑', 'commodity': 'beef', 'direction': 'up', 'time': 9, 'state': 'upcoming'});
      expect(news, isA<NewsPush>());
      final item = (news as NewsPush).item;
      expect(item.id, '7');
      expect(item.commodity, Commodity.beef);
      expect(item.up, isTrue);
      expect(item.upcoming, isTrue);
    });
  });
}
