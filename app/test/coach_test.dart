// S11-03 新手引導卡：什麼時候出（第一次擴建開放、開局的小公牛長大）、一次一張、哪些情況不出；牧場頁上的位置、
// 按 ×、按「去擴建」「去配種」，看過記在手機上（照牧場分開）。卡片本身的畫面在 test/pages/s11_cases.dart。
import 'package:cowfarm/app.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/state/settings.dart';
import 'package:cowfarm/ui/kit/app_icon.dart';
import 'package:cowfarm/ui/ranch/coach_card.dart';
import 'package:cowfarm/ui/ranch/dock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'pages/page_case.dart';
import 'pages/s03_cases.dart';

final _zh = Strings.forLang(AppLang.zhHant);

/// 剛建好的牧場（#31，倍率 1）：還沒擴建，第一次擴建在第 15 分鐘開放（280 幣）；#2 小公耕牛第 20 分鐘長大。
Map<String, dynamic> _fresh({int penLevel = 0, Map<String, dynamic> bull = const {}}) {
  final j = newRanchStateJson();
  final cows = [for (final c in j['cows'] as List) (c as Map).cast<String, dynamic>()];
  cows[1] = {...cows[1], ...bull};
  final upgrades = (j['upgrades'] as Map).cast<String, dynamic>();
  return {
    ...j,
    'cows': cows,
    'pen': {...(j['pen'] as Map), 'next_cost': 280, 'next_open_at': t0 + 15 * 60},
    'upgrades': {
      ...upgrades,
      'pen': {...(upgrades['pen'] as Map), 'level': penLevel, 'cost': 280, 'next_open_at': t0 + 15 * 60},
    },
  };
}

/// 還沒看過任何引導卡的偏好。
SettingsController _settings([Map<String, String> prefs = const {}]) => SettingsController(
  MemoryPrefsStore({SettingsController.swipeHintKey: '1', ...prefs}),
  deviceLocales: () => const [Locale('zh', 'TW')],
);

void main() {
  group('什麼時候出', () {
    test('第 15 分鐘前沒有；第一次擴建開放以後出「牛舍可以擴建了」', () async {
      final clock = FakeClock();
      final (m, _, _) = await loadedModel(
        api: FakeGameApi(state: _fresh()),
        clock: clock,
      );
      final s = _settings();
      expect(coachToShow(m, s), isNull);
      clock.t += 15 * 60;
      expect(coachToShow(m, s), CoachKind.pen);
    });

    test('一次一張：兩張都到時間先出擴建；擴建那張看過以後才出「小公牛長大了」', () async {
      final clock = FakeClock();
      final (m, _, _) = await loadedModel(
        api: FakeGameApi(state: _fresh()),
        clock: clock,
      );
      final s = _settings();
      clock.t += 25 * 60;
      expect(coachToShow(m, s), CoachKind.pen);
      await s.markCoachSeen('pen', 31);
      expect(coachToShow(m, s), CoachKind.bull);
      await s.markCoachSeen('bull', 31);
      expect(coachToShow(m, s), isNull);
    });

    test('小公牛第 20 分鐘才長大：擴建看過了、還沒長大就沒有卡', () async {
      final clock = FakeClock();
      final (m, _, _) = await loadedModel(
        api: FakeGameApi(state: _fresh()),
        clock: clock,
      );
      final s = _settings({SettingsController.coachSeenKey: 'pen@31'});
      await s.load();
      clock.t += 15 * 60;
      expect(coachToShow(m, s), isNull);
      clock.t += 5 * 60;
      expect(coachToShow(m, s), CoachKind.bull);
    });

    test('已經擴建過不出擴建卡；小公牛已經配過種、下田、上架不出', () async {
      final clock = FakeClock();
      final (m, _, _) = await loadedModel(
        api: FakeGameApi(state: _fresh(penLevel: 1)),
        clock: clock,
      );
      clock.t += 30 * 60;
      expect(coachToShow(m, _settings()), CoachKind.bull, reason: '擴建過了，直接看小公牛');
      for (final bull in <Map<String, dynamic>>[
        {'bred': true},
        {'field': 0, 'working': true},
        {'listed': 7},
      ]) {
        final c2 = FakeClock();
        final (m2, _, _) = await loadedModel(
          api: FakeGameApi(state: _fresh(penLevel: 1, bull: bull)),
          clock: c2,
        );
        c2.t += 30 * 60;
        expect(coachToShow(m2, _settings()), isNull, reason: '$bull');
      }
    });

    test('看過記在手機上、照牧場分開：別的牧場（另一個編號）會再出一次', () async {
      final store = MemoryPrefsStore();
      final s = SettingsController(store, deviceLocales: () => const [Locale('zh', 'TW')]);
      await s.markCoachSeen('pen', 31);
      expect(store.values[SettingsController.coachSeenKey], 'pen@31');
      final again = SettingsController(store, deviceLocales: () => const [Locale('zh', 'TW')]);
      await again.load();
      expect(again.coachSeen('pen', 31), isTrue);
      expect(again.coachSeen('pen', 32), isFalse);
    });
  });

  group('牧場頁', () {
    setUpAll(loadAppAssets);

    Future<GameModel> show(
      WidgetTester tester, {
      Map<String, dynamic>? market,
      SettingsController? settings,
      Screen screen = Screen.w430,
    }) async {
      screen.apply(tester);
      final clock = FakeClock();
      final api = FakeGameApi(state: _fresh(), market: market ?? ranchMarket());
      final (m, _, _) = await loadedModel(api: api, clock: clock);
      clock.t += 30 * 60;
      final s = settings ?? _settings();
      await s.load();
      await tester.pumpWidget(CowFarmApp(model: m, settings: s));
      await tester.pump();
      return m;
    }

    testWidgets('擴建卡在跑馬燈下面 12、左右各 12，寫擴建的價格；按 × 收起來，記在手機上', (tester) async {
      final store = MemoryPrefsStore({SettingsController.swipeHintKey: '1'});
      final s = SettingsController(store, deviceLocales: () => const [Locale('zh', 'TW')]);
      await show(tester, settings: s);
      final card = find.byKey(const Key('coach-pen'));
      expect(card, findsOneWidget);
      expect(find.text(_zh.s11CoachPenBody(price: '280')), findsOneWidget);
      final ticker = tester.getRect(find.byKey(const Key('ticker')));
      final rect = tester.getRect(card);
      expect(rect.top, ticker.bottom + 12);
      expect(rect.left, 12);
      expect(rect.right, 430 - 12);
      await tester.tap(find.byKey(const Key('coach-close-pen')));
      await tester.pump();
      expect(card, findsNothing);
      expect(store.values[SettingsController.coachSeenKey], 'pen@31');
      expect(find.byKey(const Key('coach-bull')), findsOneWidget, reason: '關掉擴建那張才出下一張');
    });

    testWidgets('「去擴建」到商店的設施（S10）、「去配種」到自己配種（S08）；按了都算看過', (tester) async {
      final s = _settings();
      final m = await show(tester, settings: s);
      await tester.tap(find.byKey(const Key('coach-go-pen')));
      await tester.pump();
      expect(m.tab, AppTab.shop);
      expect(m.shopFacility, isTrue);
      expect(s.coachSeen('pen', 31), isTrue);
      m.selectTab(AppTab.ranch);
      await tester.pump();
      await tester.tap(find.byKey(const Key('coach-go-bull')));
      await tester.pump();
      expect(m.tab, AppTab.breed);
      expect(m.breedStud, isFalse);
      expect(s.coachSeen('bull', 31), isTrue);
      m.selectTab(AppTab.ranch);
      await tester.pump();
      expect(find.byType(CoachCard), findsNothing);
    });

    testWidgets('× 點得到的範圍 44 × 44：四個角都點得到、不超出螢幕、不碰到按鈕；圓章在卡片右上角；讀螢幕讀「關閉」', (tester) async {
      final handle = tester.ensureSemantics();
      await show(tester);
      final close = find.byKey(const Key('coach-close-pen'));
      final hit = tester.getRect(close);
      expect(hit.size, const Size(44, 44));
      // 範圍大半在卡片外面：元件的範圍沒包到的地方 Flutter 點不到
      final target = tester.renderObject(close);
      for (final p in [
        hit.topLeft + const Offset(0.5, 0.5),
        hit.topRight + const Offset(-0.5, 0.5),
        hit.bottomLeft + const Offset(0.5, -0.5),
        hit.bottomRight + const Offset(-0.5, -0.5),
      ]) {
        expect(tester.hitTestOnBinding(p).path.any((e) => e.target == target), isTrue, reason: '$p');
      }
      expect(hit.right, lessThanOrEqualTo(430));
      final go = tester.getRect(find.byKey(const Key('coach-go-pen')));
      expect(hit.intersect(go).isEmpty, isTrue, reason: '$hit 和按鈕 $go 重疊');
      final card = tester.getRect(find.byKey(const Key('coach-pen')));
      expect(tester.getCenter(find.descendant(of: close, matching: find.byType(AppIcon))), card.topRight);
      expect(tester.getSemantics(close), isSemantics(label: _zh.gClose, isButton: true, hasTapAction: true));
      handle.dispose();
    });

    testWidgets('很矮的手機（320 × 568 英文）：卡片在面板上面，「去擴建」和 × 都點得到', (tester) async {
      final s = _settings({SettingsController.langKey: 'en'});
      final m = await show(tester, settings: s, screen: Screen.w320);
      for (final key in ['coach-go-pen', 'coach-close-pen']) {
        final f = find.byKey(Key(key));
        final target = tester.renderObject(f);
        final hit = tester.hitTestOnBinding(tester.getCenter(f));
        expect(hit.path.any((e) => e.target == target), isTrue, reason: '$key 被蓋住了');
      }
      expect(
        tester.getRect(find.byKey(const Key('coach-pen'))).bottom,
        greaterThan(tester.getRect(find.byType(Dock)).top),
        reason: '這個情況卡片真的疊到面板',
      );
      await tester.tap(find.byKey(const Key('coach-go-pen')));
      await tester.pump();
      expect(m.tab, AppTab.shop);
    });

    testWidgets('大新聞（S03-15）開著時先不出，關掉以後才出', (tester) async {
      await show(
        tester,
        market: ranchMarket(
          beef: 15.0,
          news: [
            {
              'id': 202,
              'code': 'beef_up.1',
              'params': {},
              'pct': 0.25,
              'commodity': 'beef',
              'targets': ['beef'],
              'direction': 'up',
              'big': false,
              'time': t0 - 60,
              'announce_at': t0 - 60,
              'start_at': t0 - 60,
              'end_at': t0 + 7200,
              'state': 'active',
            },
          ],
        ),
      );
      expect(find.byKey(const Key('big-news')), findsOneWidget);
      expect(find.byType(CoachCard), findsNothing);
      await tester.tap(find.byKey(const Key('big-news-close')));
      await tester.pump();
      expect(find.byKey(const Key('coach-pen')), findsOneWidget);
    });
  });
}
