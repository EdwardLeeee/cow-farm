// S14 找回牧場的頁面狀態（設計稿 s13.js 的 firstOpen、recoverPage、S14-04）：設好 Apple／Google 登入的建置（設計稿畫的是
// iPhone；S14-07 是 Android）。S14-05（舊手機）等 #123 的正式畫面合併以後再做，還在待做清單。
// 沒設登入的建置（網頁試玩版）沒有 S14-01，照原本直接 S02：在 recover_flow_test 檢查。
import 'dart:async';

import 'package:cowfarm/api/breeds.dart';
import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/auth/sign_in.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/storage/token_store.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:cowfarm/ui/settings/sso_button.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
import 'page_case.dart';
import 's03_cases.dart';

final _zh = Strings.forLang(AppLang.zhHant);

/// 還沒有牧場的手機（沒有 token），設好 Apple／Google 登入的建置。
GameModel freshWithSignIn({FakeGameApi? api, SignInService? signIn, SignInPlatform platform = SignInPlatform.iphone}) =>
    GameModel(
      api: api ?? FakeGameApi(),
      push: FakePush(),
      tokens: MemoryTokenStore(),
      now: FakeClock().call,
      uiTick: null,
      signInPlatform: platform,
      signIn: signIn ?? FakeSignIn(),
    )..needsRanch = true;

/// 找回來的牧場（設計稿 S14-04 的 RANCH）：晨光河畔牧場 #1234、Lv 4、12,480 幣、10 頭牛、圖鑑 10 / 24。
Map<String, dynamic> recoveredState() => {
  ...ranchState(cows: herdOf(10)),
  'player_id': 1234,
  'codex': [
    for (final b in kCodexOrder.take(10)) {'breed': b, 'found_at': t0},
  ],
};

/// S14-01 → 按「找回我的牧場」→ S14-02。
Future<GameModel> showRecover(
  WidgetTester tester,
  AppLang lang, {
  FakeGameApi? api,
  SignInService? signIn,
  SignInPlatform platform = SignInPlatform.iphone,
}) async {
  final m = freshWithSignIn(api: api, signIn: signIn, platform: platform);
  await pumpAppIn(tester, m, lang);
  await tester.tap(find.byKey(const Key('first-recover')));
  await tester.pump();
  expect(find.byKey(const Key('recover')), findsOneWidget);
  await settleImages(tester);
  return m;
}

/// 一張提示（.g-toast：高 50，提示靠左上）。
Widget _toastSlot(ToastKind kind, String text) => SizedBox(
  height: 50,
  child: Align(
    alignment: Alignment.topLeft,
    child: ToastPill(text, kind: kind),
  ),
);

final s14Cases = [
  PageCase(
    'S14-01',
    '第一次打開：開新牧場或找回我的牧場',
    (tester, lang) async {
      await pumpAppIn(tester, freshWithSignIn(), lang);
      await settleImages(tester);
    },
    check: (tester) {
      expect(find.byKey(const Key('first-open')), findsOneWidget);
      expect(find.text(_zh.s14NewRanch), findsOneWidget);
      expect(find.text(_zh.s14Recover), findsOneWidget);
      expect(find.byKey(const Key('app-version')), findsNothing, reason: '設計稿 S14-01 沒有版本號');
    },
  ),
  PageCase(
    'S14-02',
    '找回我的牧場（iPhone）',
    (tester, lang) => showRecover(tester, lang),
    check: (tester) {
      expect(find.text(_zh.s14Lead), findsOneWidget);
      expect(find.text(_zh.s14LeadHint), findsOneWidget);
      expect(find.byType(SsoButton), findsNWidgets(2));
      expect(find.text(_zh.s13Privacy), findsOneWidget);
      expect(find.byKey(const Key('sso-hint')), findsNothing);
    },
  ),
  PageCase(
    'S14-03',
    '這個帳號沒有備份過牧場',
    (tester, lang) async {
      final api = FakeGameApi()..recoverError = const ApiException(404, 'account_not_linked', 'not linked');
      await showRecover(tester, lang, api: api);
      await tester.tap(find.byKey(const Key('sso-apple')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('no-ranch')), findsOneWidget);
    },
    crop: find.byKey(const Key('no-ranch')),
    check: (tester) {
      expect(find.text(_zh.s14NoneTitle), findsOneWidget);
      expect(find.text(_zh.s14NoneBody), findsOneWidget);
      expect(find.byKey(const Key('recover-another')), findsOneWidget);
      expect(find.byKey(const Key('recover-new')), findsOneWidget);
      expect(find.byType(SsoButton), findsNothing);
    },
  ),
  PageCase(
    'S14-04',
    '找回成功：歡迎回來',
    (tester, lang) async {
      final api = FakeGameApi()..switchedStateJson = recoveredState();
      final m = await showRecover(tester, lang, api: api);
      await tester.tap(find.byKey(const Key('sso-apple')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('welcome-back')), findsOneWidget);
      // 換成那個牧場時推播重新連線；設計稿畫的是連上以後（連上之前標題下面會有「連線中…」）
      (m.push as FakePush).isConnected = true;
      await tester.pump();
      expect(find.byKey(const Key('offline-pill')), findsNothing);
      await settleImages(tester);
    },
    check: (tester) {
      expect(find.text(_zh.s14Welcome), findsOneWidget);
      expect(find.text('晨光河畔牧場'), findsOneWidget);
      expect(find.text('#1234'), findsOneWidget);
      expect(find.text(_zh.level(lv: 4)), findsOneWidget);
      expect(find.text('12,480'), findsOneWidget);
      expect(find.text(_zh.s14WelcomeHint), findsOneWidget);
      expect(find.byKey(const Key('btn-back')), findsNothing, reason: '沒有返回鈕');
    },
  ),
  PageCase(
    'S14-06',
    '登入中…（登入視窗關掉後，等伺服器回覆）',
    (tester, lang) async {
      final api = FakeGameApi()..recoverGate = Completer<void>();
      await showRecover(tester, lang, api: api);
      await tester.tap(find.byKey(const Key('sso-apple')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('sso-busy')), findsOneWidget);
    },
    crop: find.byKey(const Key('sso-busy')),
    check: (tester) {
      expect(find.text(_zh.s14SigningIn), findsOneWidget);
      expect(find.byType(SsoButton), findsNothing);
    },
  ),
  PageCase(
    'S14-07',
    'Android 版：只有 Google 一顆，多一句提醒',
    (tester, lang) => showRecover(tester, lang, platform: SignInPlatform.android),
    crop: find.byKey(const Key('sso-area')),
    check: (tester) {
      expect(find.byKey(const Key('sso-apple')), findsNothing);
      expect(find.byKey(const Key('sso-google')), findsOneWidget);
      expect(find.text(_zh.s14AndroidHint), findsOneWidget);
    },
  ),
  PageCase(
    'S14-08',
    '提示：取消登入、登入失敗',
    (tester, lang) {
      final s = Strings.forLang(lang);
      return pumpSheet(tester, lang, [
        _toastSlot(ToastKind.info, s.s13ToastCancelled),
        _toastSlot(ToastKind.err, s.s13ToastFailed),
      ]);
    },
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.byType(ToastPill), findsNWidgets(2));
    },
  ),
];
