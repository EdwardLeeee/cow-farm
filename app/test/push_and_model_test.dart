import 'dart:async';
import 'dart:math';

import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/api/push.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/storage/token_store.dart';
import 'package:cowfarm/ui/kit/frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class _ExpiredTokenApi extends FakeGameApi {
  @override
  Future<GameState> getState() async {
    if (token == 'old') throw const ApiException(401, 'unauthorized', '請重新登入');
    return super.getState();
  }
}

/// 收奶、行情、試算可以切成「維護中」（503 maintenance）。
class _MaintenanceApi extends FakeGameApi {
  bool down = false;
  static const error = ApiException(503, 'maintenance', '維護中', {'ends_at_real': 1790784000.0});

  @override
  Future<MarketInfo> market() async {
    if (down) throw error;
    return super.market();
  }

  @override
  Future<SellQuote> sellQuote(Commodity commodity, double qty) async {
    if (down) throw error;
    return super.sellQuote(commodity, qty);
  }

  @override
  Future<Map<String, dynamic>> collect() async {
    if (down) throw error;
    return super.collect();
  }
}

/// 讓排在後面的 microtask（假 API 的回應、補抓）都跑完。
Future<void> _settle() => Future<void>.delayed(Duration.zero);

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
    test('沒有 token：停在「還沒有牧場」，取好名字才建立（協定 2.1，D23）', () async {
      final api = FakeGameApi();
      final push = FakePush();
      final store = MemoryTokenStore();
      final m = GameModel(api: api, push: push, tokens: store, uiTick: null);
      await m.start();
      expect(m.needsRanch, isTrue);
      expect(api.calls, isNot(contains(startsWith('session'))), reason: '不自動取名、不自動建立');
      expect(m.state, isNull);

      final r = await m.createRanch('小花的快樂牧場');
      expect(r.ok, isTrue);
      expect(api.calls, contains('session:小花的快樂牧場'));
      expect(store.values[TokenStore.tokenKey], 'tok-new');
      expect(api.token, 'tok-new');
      expect(push.token, 'tok-new');
      expect(m.needsRanch, isFalse);
      expect(m.ranchName, '小花的快樂牧場');
      expect(m.state, isNotNull, reason: '回應附 state（S02-02 的開局牛、金幣、奶桶）');
      await Future<void>.delayed(Duration.zero);
      expect(m.market, isNotNull);
      m.dispose();
    });

    test('名字伺服器不收（invalid_name）：不存 token，留在取名', () async {
      final api = FakeGameApi()
        ..sessionError = const ApiException(400, 'invalid_name', '名字不能用表情符號', {'reason': 'emoji', 'width': 10});
      final store = MemoryTokenStore();
      final m = GameModel(api: api, push: FakePush(), tokens: store, uiTick: null);
      await m.start();
      final r = await m.createRanch('小花牧場🐮');
      expect(r.ok, isFalse);
      expect((r.error! as ApiActionError).error.detail['reason'], 'emoji');
      expect(store.values, isEmpty);
      expect(m.needsRanch, isTrue);
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

    test('伺服器不認得 token（401）：不再默默開新牧場，停下來顯示 S15-03', () async {
      final api = _ExpiredTokenApi();
      final store = MemoryTokenStore({TokenStore.tokenKey: 'old'});
      final m = GameModel(api: api, push: FakePush(), tokens: store, uiTick: null);
      await m.start();
      expect(m.authLost, 'unauthorized');
      expect(api.calls, isNot(contains(startsWith('session'))));
      expect(store.values[TokenStore.tokenKey], 'old', reason: '玩家選「開新牧場」之前不清掉');
      // S15-03「開新牧場」：清掉 token，回到取名
      await m.startOver();
      expect(store.values, isEmpty);
      expect(m.authLost, isNull);
      expect(m.needsRanch, isTrue);
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

    test('WebSocket 4401：牧場在另一支手機找回了（signed_in_elsewhere），停下來顯示 S14-05', () async {
      final (m, api, push) = await loadedModel();
      push.emit(const PushAuthFailed('tok', 'signed_in_elsewhere'));
      await Future<void>.delayed(Duration.zero);
      expect(m.authLost, 'signed_in_elsewhere');
      expect(api.calls, isNot(contains(startsWith('session'))));
      // 停下來以後不再定時打伺服器
      api.calls.clear();
      await m.refreshState();
      expect(api.calls, isEmpty);
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
      push.emit(const NewsPush(NewsItem(id: 'x1', code: 'milk_up.1')));
      push.emit(const NewsPush(NewsItem(id: 'x1', code: 'milk_up.1')));
      await Future<void>.delayed(Duration.zero);
      expect(m.market!.news.length, n + 1);
      expect(m.market!.news.first.id, 'x1');
    });
  });

  group('維護（S16-01；協定第 6 節）', () {
    const active = Maintenance(startsAtReal: 1790780400, endsAtReal: 1790784000, active: true);

    test('開機先問 /v1/status：維護中停在 S16-01，不讀牧場、不連 WebSocket；維護結束才重新載入', () async {
      final api = FakeGameApi()..maintenance = active;
      final push = FakePush(connected: false);
      final m = GameModel(api: api, push: push, tokens: MemoryTokenStore({TokenStore.tokenKey: 'tok'}), uiTick: null);
      await m.start();
      expect(api.calls, ['status']);
      expect(m.maintenance?.endsAtReal, 1790784000);
      expect(push.connects, 0);
      expect(m.canAct, isFalse);

      // 還在維護：營運延長了，預計恢復時間跟著改
      api.maintenance = const Maintenance(startsAtReal: 1790780400, endsAtReal: 1790787600, active: true);
      await m.checkMaintenance();
      expect(m.maintenance?.endsAtReal, 1790787600);
      expect(api.calls, ['status', 'status']);

      // 維護結束（maintenance 變成 null）：重新載入
      api.maintenance = null;
      await m.checkMaintenance();
      expect(m.maintenance, isNull);
      expect(m.state, isNotNull);
      expect(api.calls.skip(2), containsAllInOrder(['status', 'state', 'market']));
      expect(push.token, 'tok');
      m.dispose();
    });

    test('還沒有牧場也先問：維護中顯示 S16-01；結束後營運排了下一次（active: false）也回到取名（S02）', () async {
      final api = FakeGameApi()..maintenance = active;
      final m = GameModel(api: api, push: FakePush(), tokens: MemoryTokenStore(), uiTick: null);
      await m.start();
      expect(m.maintenance, isNotNull);
      expect(m.needsRanch, isFalse);
      api.maintenance = const Maintenance(startsAtReal: 1790900000, endsAtReal: 1790903600);
      await m.checkMaintenance();
      expect(m.maintenance, isNull);
      expect(m.needsRanch, isTrue);
      m.dispose();
    });

    test('/v1/status 回別的錯誤不擋開機；連不上就顯示連線失敗', () async {
      final api = FakeGameApi()..statusError = const ApiException(404, 'not_found', 'Not Found');
      final m = GameModel(
        api: api,
        push: FakePush(),
        tokens: MemoryTokenStore({TokenStore.tokenKey: 'tok'}),
        uiTick: null,
      );
      await m.start();
      expect(m.state, isNotNull);
      expect(m.startError, isNull);
      m.dispose();

      final down = FakeGameApi()..statusError = const NetworkException('down');
      final m2 = GameModel(
        api: down,
        push: FakePush(),
        tokens: MemoryTokenStore({TokenStore.tokenKey: 'tok'}),
        uiTick: null,
      );
      await m2.start();
      expect(m2.startError, isA<NetworkActionError>());
      expect(m2.maintenance, isNull);
      m2.dispose();
    });

    test('部署時反向代理回 503 maintenance（/v1/status 也是）：用 detail 的預計恢復時間', () async {
      final api = FakeGameApi()..statusError = _MaintenanceApi.error;
      final m = GameModel(
        api: api,
        push: FakePush(),
        tokens: MemoryTokenStore({TokenStore.tokenKey: 'tok'}),
        uiTick: null,
      );
      await m.start();
      expect(m.maintenance?.active, isTrue);
      expect(m.maintenance?.endsAtReal, 1790784000.0);
      expect(api.calls, ['status']);
      m.dispose();
    });

    test('玩到一半遇到 503 maintenance：進 S16-01、按鈕停用、關掉 WebSocket，之後只打 /v1/status', () async {
      final (m, api, push) = await loadedModel();
      api.stateError = _MaintenanceApi.error;
      await m.refreshState();
      expect(m.maintenance?.endsAtReal, 1790784000.0);
      expect(m.canAct, isFalse);
      expect(push.closes, 1);
      expect(push.connected.value, isFalse, reason: '維護中不要重連');
      expect(m.offlineFor, isNull, reason: '維護中顯示 S16-01，不算斷線');

      api.calls.clear();
      await m.refreshState();
      await m.refreshMarket();
      final r = await m.collect();
      expect(r.ok, isFalse);
      expect(api.calls, isEmpty);
      m.dispose();
    });

    test('行情、試算、操作遇到 503 maintenance 也進 S16-01', () async {
      final triggers = <String, Future<void> Function(GameModel)>{
        'market': (m) => m.refreshMarket(),
        'quote': (m) => m.quote(Commodity.milk, 1),
        'collect': (m) => m.collect(),
      };
      for (final MapEntry(:key, :value) in triggers.entries) {
        final api = _MaintenanceApi();
        final (m, _, _) = await loadedModel(api: api);
        api.down = true;
        await value(m);
        expect(m.maintenance?.endsAtReal, 1790784000.0, reason: key);
        m.dispose();
      }
    });

    test('WebSocket 說開始維護（active）才進 S16-01；安排、取消維護照常玩', () async {
      final (m, _, push) = await loadedModel();
      push.emit(const MaintenancePush(Maintenance(startsAtReal: 1790900000, endsAtReal: 1790903600)));
      push.emit(const MaintenancePush(null));
      await _settle();
      expect(m.maintenance, isNull);
      expect(m.canAct, isTrue);
      push.emit(const MaintenancePush(active));
      await _settle();
      expect(m.maintenance?.endsAtReal, 1790784000);
      expect(m.canAct, isFalse);
      m.dispose();
    });

    test('每隔一段時間問一次（正式 30 秒，測試縮短）；連不上、反向代理的 503 都留在維護畫面', () async {
      final api = FakeGameApi()..maintenance = active;
      final m = GameModel(
        api: api,
        push: FakePush(),
        tokens: MemoryTokenStore({TokenStore.tokenKey: 'tok'}),
        uiTick: null,
        maintenanceCheckEvery: const Duration(milliseconds: 20),
      );
      await m.start();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(api.calls.where((c) => c == 'status').length, greaterThanOrEqualTo(3));
      expect(api.calls, everyElement('status'));

      api.statusError = const NetworkException('down');
      await m.checkMaintenance();
      expect(m.maintenance?.endsAtReal, 1790784000);
      api.statusError = const ApiException(503, 'maintenance', '維護中', {'ends_at_real': 1790790000.0});
      await m.checkMaintenance();
      expect(m.maintenance?.endsAtReal, 1790790000.0);
      m.dispose();
    });
  });

  group('斷線與重新連上（S15；協定第 7 節）', () {
    test('連續斷線 60 秒以上才算斷線很久（S15-04），{n} 是分鐘數', () async {
      final clock = FakeClock();
      final (m, _, push) = await loadedModel(clock: clock);
      expect(m.offlineFor, isNull);
      push.isConnected = false;
      expect(m.canAct, isFalse, reason: 'S15-01：斷線時按鈕停用');
      expect(m.offlineFor, Duration.zero);
      clock.t += 59;
      expect(m.longOffline, isFalse);
      clock.t += 2;
      expect(m.longOffline, isTrue);
      expect(m.offlineMinutes, 1);
      clock.t += 120;
      expect(m.offlineMinutes, 3);
      m.dispose();
    });

    test('重新連上：先補抓 state 和行情，都抓完才提示一次「已重新連線」（S15-02）', () async {
      final clock = FakeClock();
      final (m, api, push) = await loadedModel(clock: clock);
      final notices = <GameNotice>[];
      m.notices.listen(notices.add);
      push.isConnected = false;
      clock.t += 90;
      api.calls.clear();
      final gate = api.marketGate = Completer<void>();
      push.isConnected = true;
      await _settle();
      expect(api.calls, containsAll(['state', 'market']));
      expect(notices, isEmpty, reason: '行情還沒抓完');
      gate.complete();
      await _settle();
      expect(notices.whereType<ReconnectedNotice>(), hasLength(1));
      expect(m.offlineFor, isNull);
      expect(m.longOffline, isFalse);
      m.dispose();
    });

    test('第一次連上不算重新連上；補抓失敗不提示、繼續算斷線', () async {
      final clock = FakeClock();
      final (m, api, push) = await loadedModel(connected: false, clock: clock);
      final notices = <GameNotice>[];
      m.notices.listen(notices.add);
      expect(m.offlineFor, Duration.zero, reason: '還沒連上 WebSocket 也算連不上');
      push.isConnected = true;
      await _settle();
      expect(notices, isEmpty);

      // WebSocket 連回來了，但 HTTP 還是連不上：不提示，按鈕繼續停用、繼續算斷線
      push.isConnected = false;
      api.stateError = const NetworkException('down');
      api.marketError = const NetworkException('down');
      push.isConnected = true;
      await _settle();
      expect(notices, isEmpty);
      expect(m.canAct, isFalse);
      clock.t += 61;
      expect(m.longOffline, isTrue);
      m.dispose();
    });

    test('WebSocket 一直連著、HTTP 先斷後好：定時校正成功後補抓行情，再提示', () async {
      final (m, api, _) = await loadedModel();
      final notices = <GameNotice>[];
      m.notices.listen(notices.add);
      api.stateError = const NetworkException('down');
      await m.refreshState();
      expect(m.canAct, isFalse);
      api.stateError = null;
      api.calls.clear();
      await m.refreshState();
      await _settle();
      expect(api.calls, contains('market'));
      expect(notices.whereType<ReconnectedNotice>(), hasLength(1));
      m.dispose();
    });

    test('S15-04 的「重試」：叫 WebSocket 重連，並馬上補抓', () async {
      final (m, api, push) = await loadedModel();
      push.isConnected = false;
      api.calls.clear();
      final before = push.connects;
      await m.retryConnection();
      expect(push.connects, before + 1);
      expect(api.calls, containsAll(['state', 'market']));
      m.dispose();
    });

    testWidgets('原型外框：斷線很久在上方提示 S15-04；維護中整個換成 S16-01，沒有分頁', (tester) async {
      final zh = Strings.forLang(AppLang.zhHant);
      final clock = FakeClock();
      final (m, _, push) = await loadedModel(clock: clock);
      await pumpApp(tester, m);
      expect(find.byKey(const Key('long-offline')), findsNothing);
      push.isConnected = false;
      clock.t += 61;
      await tester.pump();
      expect(find.text(zh.s15LongOffTitle(n: 1)), findsOneWidget);

      push.emit(const MaintenancePush(Maintenance(endsAtReal: 1790784000, active: true)));
      await tester.pump(Duration.zero);
      expect(find.byKey(const Key('maintenance')), findsOneWidget);
      expect(find.text(zh.s16Title), findsOneWidget);
      expect(find.byType(AppTabBar), findsNothing);
      expect(find.byKey(const Key('long-offline')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      m.dispose(); // 停掉維護的定時查詢
    });

    testWidgets('玩到一半 token 失效：換成 S15-03，不留在牧場畫面', (tester) async {
      final zh = Strings.forLang(AppLang.zhHant);
      final (m, _, push) = await loadedModel();
      await pumpApp(tester, m);
      expect(find.byType(AppTabBar), findsOneWidget);
      push.emit(const PushAuthFailed('tok'));
      await tester.pump(Duration.zero); // 推播是非同步送到的：先送到，再畫下一格
      expect(find.text(zh.s15InvalidTitle), findsOneWidget);
      expect(find.byType(AppTabBar), findsNothing);
    });
  });

  group('models', () {
    test('協定欄位解析', () {
      final s = GameState.fromJson(sampleStateJson());
      expect(s.cows, hasLength(5));
      expect(s.cows[1].bull, isTrue);
      expect(s.cows[2].stage, CowStage.calf);
      expect(s.upgrades[UpgradeKind.fresh]!.cost, isNull);
      expect(s.upgrades[UpgradeKind.bucket]!.cost, 200);
      expect(s.upgrades[UpgradeKind.bucket]!.next, 36);
      // v2：圖鑑是品種代號和第一次發現的時間（協定 2.3）
      expect(s.codex.keys, unorderedEquals(['holstein', 'highland']));
      expect(s.codex['holstein'], t0 - 36000);
      expect(s.playerId, 31);
      expect(s.levelProgress.fraction, closeTo((2400 - 1500) / (3500 - 1500), 1e-9));
      expect(s.cows.first.breed, 'holstein');
      expect(s.cowById('2')!.studFee?.price, 220, reason: '成年、沒配過種的公牛才有借種費');
      expect(s.cowById('1')!.studFee, isNull);
      expect(s.accountLinks, isEmpty);
      expect(s.maintenance, isNull);
      expect(s.warehouse.milkTotal, 150.5);
      expect(s.warehouse.worstFreshness, 0.8);
    });

    test('v0.2 欄位解析：田地、稻米、商店等級、借種、牛的狀態', () {
      final s = GameState.fromJson(sampleStateJson(bullListed: true));
      expect(s.warehouse.riceTotal, 20);
      expect(s.warehouse.total(Commodity.rice), 20);
      expect(s.fields, hasLength(2));
      expect(s.fields[0].cowId, 4);
      expect(s.fields[1].empty, isTrue);
      expect(s.rice.stock, 20);
      expect(s.shopGrades.map((g) => g.grade), ['A', 'B', 'C']);
      expect(s.gradePrice('B'), 1700);
      final mine = s.stud.listings.single;
      expect(mine.isMine, isTrue);
      expect(mine.price, 550, reason: '借種費看 fee.price（D26）');
      expect(mine.owner?.name, '晨光草原牧場');
      expect(mine.breed, 'highland');
      expect(s.upgrades[UpgradeKind.field]!.maxLevel, 12);
      final ox = s.cowById('4')!;
      expect(ox.working, isTrue);
      expect(ox.fieldIndex, 0);
      expect(ox.canShipAt(t0), isFalse);
      expect(ox.canBreedAt(t0), isFalse);
      expect(s.cowById('5')!.bred, isTrue);
      expect(s.cowById('2')!.listed, isTrue);
      expect(s.cowById('1')!.gradeProbs!['A'], closeTo(0.137323, 1e-9));
      expect(s.cowById('1')!.milker, isTrue);
      expect(s.cowById('2')!.milker, isFalse);
    });

    test('出貨、商店、借種的回應', () {
      final ship = ShipResult.fromJson({
        'cow_id': 1,
        'grade': 'C',
        'grade_probs': {'A': 0.15, 'B': 0.49, 'C': 0.36},
        'beef': {'qty': 40.4, 'grade': 'C', 'value_estimate': 375},
      });
      expect(ship.grade, 'C');
      expect(ship.valueEstimate, 375);
      final prev = ShipPreview.fromJson({
        'grade_probs': {'A': 0.1, 'B': 0.5, 'C': 0.4},
        'value_by_grade': {'A': 625, 'B': 500, 'C': 375},
        'expected_value': 475,
        'can_ship': false,
        'blockers': [
          {'code': 'cow_in_field', 'message': '牛在田裡工作'},
        ],
      });
      expect(prev.valueByGrade['B'], 500);
      expect(prev.canShip, isFalse);
      expect(prev.blockers.map((b) => b.code), ['cow_in_field'], reason: 'v2：用代碼查字串表，不顯示 message');
      final stud = BreedPreview.fromJson({
        'fee': {'price': 800, 'per_kg': 2.75, 'kg': 290.9, 'at_max': false},
        'tier_probs': [1.0, 0, 0, 0],
        'type_probs': {'dairy': 0.5, 'dual': 0.5, 'beef': 0.0},
        'bull_prob': 0.5,
        'can_borrow': false,
        'blockers': [
          {'code': 'not_enough_coins', 'message': '金幣不夠', 'need': 1000, 'have': 414},
        ],
      });
      expect(stud.fee!.price, 800);
      expect(stud.blockers.single.detail, {'need': 1000, 'have': 414});
      expect(stud.canBreed, isFalse);
      expect(stud.typeProbs[CowType.dual], 0.5);
      final push = PushMessage.fromJson({
        'type': 'stud',
        'event': 'borrowed',
        'listing_id': 4,
        'cow': {'id': 2, 'breed': 'yellow'},
        'price': 60,
        'borrower': {
          'player_id': 12,
          'name': null,
          'name_words': [0, 1, 0],
          'is_bot': true,
          'level': 4,
        },
      });
      expect(push, isA<StudPush>());
      final borrowed = push as StudPush;
      expect(borrowed.price, 60);
      expect(borrowed.cowId, 2);
      expect(borrowed.breed, 'yellow');
      expect(borrowed.borrower!.nameWords, [0, 1, 0]);
      // v2 的其他訊息
      expect(PushMessage.fromJson({'type': 'hello', 'protocol': 2}), isA<HelloPush>());
      expect(
        PushMessage.fromJson({
          'type': 'maintenance',
          'maintenance': {'starts_at_real': 1.0, 'ends_at_real': 2.0, 'active': true},
        }),
        isA<MaintenancePush>().having((m) => m.maintenance!.active, 'active', isTrue),
      );
      expect(
        PushMessage.fromJson({
          'type': 'error',
          'error': {'code': 'signed_in_elsewhere'},
        }),
        isA<ServerErrorPush>().having((e) => e.code, 'code', 'signed_in_elsewhere'),
      );
      expect(PushMessage.fromJson({'type': 'something_new'}), isNull, reason: '不認得的 type 要忽略');
    });

    test('協定 v2 文件的範例（docs/protocol.md 2.3、1.6、4.1）', () {
      final s = GameState.fromJson({
        'server_time': 1791141900.0,
        'real_time': 1790771411.05,
        'time_scale': 144.0,
        'player_id': 31,
        'ranch_name': '小花的快樂牧場',
        'coins': 3300,
        'level': 2,
        'level_progress': {'earned': 594, 'level_at': 500, 'next_at': 1500},
        'cows': [
          {
            'id': 2, 'type': 'dual', 'bull': true, 'tier': 0, 'breed': 'yellow', 'stage': 'adult', //
            'born_at': 1791129600.0, 'adult_at': 1791130800.0, 'age_h': 3.42, 'milk_per_h': 0.0, 'milk_frac': 1.0,
            'weight_kg': 52.78, 'beef_quality': 1.0, 'ship_value': 614, 'bred': false, 'working': true, 'field': 0,
            'listed': null, 'can_breed': false, 'can_ship': false, 'can_work': false, 'rice_per_h': 11.0,
            'grade_probs': {'A': 0.137323, 'B': 0.492535, 'C': 0.370142}, 'origin': 'start',
            'stud_fee': {'price': 60, 'per_kg': 1.1, 'kg': 52.78, 'at_max': false},
          },
        ],
        'bucket': {
          'qty': 0.0, 'by_tier': [0.0, 0.0, 0.0, 0.0], 'capacity': 28.0, 'per_hour': 70.0, //
          'boost': {'mult': 5.0, 'until': 1791133200.0},
        },
        'warehouse': {'capacity': 150.0, 'used': 0.0, 'milk_total': 0.0, 'beef_total': 0.0, 'rice_total': 33.0},
        'pen': {'slots': 6, 'used': 3, 'next_cost': 280, 'next_open_at': null, 'max_slots': 40},
        'codex': [
          {'breed': 'holstein', 'found_at': 1791129600.0},
          {'breed': 'yellow', 'found_at': 1791129600.0},
        ],
        'stud': {
          'listings': [
            {
              'id': 4, 'breed': 'yellow', 'type': 'dual', 'tier': 0, //
              'owner': {'player_id': 31, 'name': '小花的快樂牧場', 'name_words': null, 'is_bot': false, 'level': 2},
              'is_mine': true, 'cow_id': 2, 'listed_at': 1791141900.0,
              'fee': {'price': 60, 'per_kg': 1.1, 'kg': 52.78, 'at_max': false},
            },
          ],
          'income': 0,
        },
        'account': {
          'links': [
            {'provider': 'apple', 'linked_at_real': 1790736000.0},
          ],
        },
        'maintenance': {'starts_at_real': 1790780400.0, 'ends_at_real': 1790784000.0, 'active': false},
      });
      final ox = s.cows.single;
      expect(ox.breed, 'yellow');
      expect(ox.studFee!.price, 60);
      expect(ox.studFee!.atMax, isFalse);
      expect(s.levelProgress.fraction, closeTo(94 / 1000, 1e-9));
      expect(s.bucket.boostMult, 5);
      expect(s.codex.keys, ['holstein', 'yellow']);
      final listing = s.stud.listings.single;
      expect(listing.owner!.playerId, 31);
      expect(listing.owner!.isBot, isFalse);
      expect(listing.fee.kg, 52.78);
      expect(s.accountLinks.single.provider, 'apple');
      expect(s.maintenance!.active, isFalse);
      expect(s.maintenance!.endsAtReal, 1790784000.0);

      final bot = RanchRef.fromJson({
        'player_id': 4,
        'name': null,
        'name_words': [8, 0, 5],
        'is_bot': true,
        'level': 6,
      })!;
      expect(bot.nameWords, [8, 0, 5]);
      expect(bot.isBot, isTrue);
      final station = RanchRef.fromJson({
        'player_id': null, 'name': null, 'name_words': [3, 5, 0], 'is_bot': true, 'level': null, //
      })!;
      expect(station.playerId, isNull);
      expect(station.level, isNull);
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
      expect(PushMessage.fromJson({'type': 'hello', 'protocol': 2}), isA<HelloPush>());
      expect(PushMessage.fromJson({'type': 'not_a_type'}), isNull);
      // 伺服器的新聞推播是攤平的
      final news = PushMessage.fromJson({
        'type': 'news',
        'id': 7,
        'code': 'beef_up.1',
        'params': {},
        'pct': 0.12,
        'commodity': 'beef',
        'targets': ['beef'],
        'direction': 'up',
        'time': 9,
        'state': 'upcoming',
      });
      expect(news, isA<NewsPush>());
      final item = (news as NewsPush).item;
      expect(item.id, '7');
      expect(item.code, 'beef_up.1');
      expect(item.pct, 0.12);
      expect(item.commodity, Commodity.beef);
      expect(item.up, isTrue);
      expect(item.upcoming, isTrue);
    });
  });
}
