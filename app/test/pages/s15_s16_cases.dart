// S15 連線與斷線、S16 維護與錯誤的頁面狀態（設計稿 s13.js 的 S15、S16）。
// 斷線、重連中（S15-01）在 s03_cases.dart。
import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:cowfarm/ui/widgets/action_button.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
import 'page_case.dart';
import 's03_cases.dart';
import 's14_cases.dart';

final _zh = Strings.forLang(AppLang.zhHant);

/// 設計稿的預計恢復時間：10 月 2 日（四）03:00。2025-10-02 是星期四；用手機的時區建，換回來還是同一個時間。
final designMaintEnds = DateTime(2025, 10, 2, 3).millisecondsSinceEpoch / 1000;

/// 維護中的牧場：伺服器最後給的現實時間在預計恢復之前（[late] 就是之後），預計恢復時間 [ends]。
/// 直接設好 maintenance 再放進 app（不經過推播，才不會開始每 30 秒問一次 /v1/status 的計時器）。
Future<GameModel> maintenanceModel({bool late = false}) async {
  final at = designMaintEnds + (late ? 3600 : -3600);
  final (m, _, _) = await loadedModel(api: FakeGameApi(state: {...ranchState(), 'real_time': at}));
  m.maintenance = Maintenance(endsAtReal: designMaintEnds, active: true);
  return m;
}

/// 收奶時伺服器出錯（500 internal，S16-02）。
class _InternalErrorApi extends FakeGameApi {
  _InternalErrorApi() : super(state: ranchState(), market: ranchMarket());

  @override
  Future<Map<String, dynamic>> collect() async {
    calls.add('collect');
    throw const ApiException(500, 'internal', 'boom');
  }
}

/// S16-03 錯誤文案總表（設計稿 s13.js 的 ERRORS，順序一樣）：錯誤碼和 detail。
const _errors = <(String, Map<String, dynamic>)>[
  ('not_enough_coins', {'need': 1210, 'have': 0}),
  ('not_enough_stock', {}),
  ('pen_full', {}),
  ('cow_not_found', {}),
  ('cow_not_adult', {}),
  ('already_bred', {}),
  ('cow_in_field', {}),
  ('cow_listed', {}),
  ('cow_not_in_field', {}),
  ('no_free_field', {}),
  ('field_occupied', {}),
  ('field_not_found', {}),
  ('listing_gone', {}),
  ('max_level', {}),
  ('not_yet_available', {}),
  ('internal', {}),
];

final s15s16Cases = [
  PageCase(
    'S15-02',
    '重新連上',
    (tester, lang) async {
      final (m, _, push) = await loadedModel(
        api: FakeGameApi(state: ranchState(), market: ranchMarket()),
      );
      await pumpAppIn(tester, m, lang, prefs: swipeHintSeen);
      await settleImages(tester);
      push.isConnected = false;
      await tester.pump();
      push.isConnected = true; // 連回來：補抓 state 和行情，抓完提示
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('reconnected')), findsOneWidget);
    },
    crop: find.byKey(const Key('reconnected')),
    check: (tester) => expect(find.text(_zh.s15Reconnected), findsOneWidget),
  ),
  PageCase(
    'S15-03',
    '帳號失效',
    // 設計稿畫的是設好登入的 iPhone：「找回我的牧場」「開新牧場」兩顆（沒設登入的建置只有「開新牧場」，在 recover_test）
    (tester, lang) async => showLost(tester, lang, code: 'unauthorized'),
    check: (tester) {
      expect(find.byKey(const Key('auth-lost')), findsOneWidget);
      expect(find.text(_zh.s15InvalidTitle), findsOneWidget);
      expect(find.text(_zh.s15InvalidBody), findsOneWidget);
      expect(find.byKey(const Key('lost-recover')), findsOneWidget);
      expect(find.byKey(const Key('start-over')), findsOneWidget);
    },
  ),
  PageCase(
    'S15-04',
    '斷線超過 60 秒：請檢查網路',
    (tester, lang) async {
      final clock = FakeClock();
      final (m, _, push) = await loadedModel(
        api: FakeGameApi(state: ranchState(), market: ranchMarket()),
        clock: clock,
      );
      await pumpAppIn(tester, m, lang, prefs: swipeHintSeen);
      await settleImages(tester);
      push.isConnected = false;
      clock.t += 61;
      await tester.pump();
      expect(find.byKey(const Key('long-offline')), findsOneWidget);
    },
    crop: find.byKey(const Key('long-offline')),
    check: (tester) {
      expect(find.text(_zh.s15LongOffTitle(n: 1)), findsOneWidget);
      expect(find.text(_zh.s15LongOffBody), findsOneWidget);
      expect(find.byKey(const Key('long-offline-retry')), findsOneWidget);
    },
  ),
  PageCase(
    'S16-01',
    '伺服器維護中',
    (tester, lang) async {
      await pumpAppIn(tester, await maintenanceModel(), lang, prefs: swipeHintSeen);
      await settleImages(tester);
    },
    check: (tester) {
      expect(find.byKey(const Key('maintenance')), findsOneWidget);
      expect(find.text(_zh.s16Title), findsWidgets, reason: '標題是描邊、影子、字三層');
      expect(find.text(_zh.s16Lead), findsOneWidget);
      expect(find.text(_zh.maintenanceEta(DateTime(2025, 10, 2, 3))), findsOneWidget);
      expect(find.text('預計 10 月 2 日（四）03:00 恢復'), findsOneWidget);
    },
  ),
  PageCase(
    'S16-02',
    '操作時伺服器錯誤（500）',
    (tester, lang) async {
      final (m, _, _) = await loadedModel(api: _InternalErrorApi());
      await pumpAppIn(tester, m, lang, prefs: swipeHintSeen);
      await settleImages(tester);
      await tester.tap(find.byKey(const Key('collect')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('toast')), findsOneWidget);
    },
    crop: find.byKey(const Key('toast')),
    check: (tester) => expect(find.text(_zh.errorText('internal')), findsOneWidget),
  ),
  PageCase(
    'S16-03',
    '錯誤文案總表（依錯誤碼）',
    (tester, lang) async {
      final s = Strings.forLang(lang);
      final m = await ranchModel();
      String text(String code, Map<String, dynamic> detail) => code == 'not_yet_available'
          ? s.errorText(
              code,
              detail: {'open_at': m.gameNow + 180 * m.timeScale},
              gameNow: m.gameNow,
              timeScale: m.timeScale,
            )
          : s.errorText(code, detail: detail);
      final toasts = [
        for (final (code, detail) in _errors)
          (actionErrorKind(ApiActionError(ApiException(400, code, '', detail))), text(code, detail)),
        (actionErrorKind(const NetworkActionError()), s.networkError),
        (actionErrorKind(const ApiActionError(ApiException(400, 'own_listing', ''))), s.unknownError),
      ];
      await pumpSheet(tester, lang, [
        for (final (kind, t) in toasts)
          Align(
            alignment: Alignment.centerLeft,
            child: ToastPill(t, kind: kind),
          ),
      ], model: m);
      await growToFit(tester, find.byType(SingleChildScrollView).first);
    },
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      final kinds = tester.widgetList<ToastPill>(find.byType(ToastPill)).map((t) => t.kind).toList();
      // 設計稿 s13.js 的 ERRORS：錯誤、錯誤、警告、錯誤、警告×4、錯誤、警告、錯誤×3、提示×2、錯誤、警告、錯誤
      expect(kinds, [
        ToastKind.err,
        ToastKind.err,
        ToastKind.warn,
        ToastKind.err,
        ToastKind.warn,
        ToastKind.warn,
        ToastKind.warn,
        ToastKind.warn,
        ToastKind.err,
        ToastKind.warn,
        ToastKind.err,
        ToastKind.err,
        ToastKind.err,
        ToastKind.info,
        ToastKind.info,
        ToastKind.err,
        ToastKind.warn,
        ToastKind.err,
      ]);
      expect(find.text(_zh.notEnoughCoins(n: '1,210')), findsOneWidget);
      expect(find.text(_zh.errNotYetAvailable(time: _zh.duration(m: 3))), findsOneWidget);
    },
  ),
  PageCase(
    'S16-04',
    '維護超過預計的時間',
    (tester, lang) async {
      await pumpAppIn(tester, await maintenanceModel(late: true), lang, prefs: swipeHintSeen);
      await settleImages(tester);
    },
    crop: find.byKey(const Key('maintenance-card')),
    check: (tester) => expect(find.text(_zh.s16Late), findsOneWidget),
  ),
  PageCase(
    'S16-05',
    '沒有預計恢復的時間',
    (tester, lang) async {
      final m = await maintenanceModel();
      m.maintenance = const Maintenance(active: true);
      await pumpAppIn(tester, m, lang, prefs: swipeHintSeen);
      await settleImages(tester);
    },
    crop: find.byKey(const Key('maintenance-card')),
    check: (tester) {
      expect(find.byKey(const Key('maintenance-eta')), findsNothing);
      expect(find.text(_zh.s16Body), findsOneWidget);
    },
  ),
];
