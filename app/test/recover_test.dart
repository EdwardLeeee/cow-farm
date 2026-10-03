// 找回牧場（S14；協定 5.5）：第一次打開先問開新牧場還是找回（只有設好登入的建置）；找回每次新的 nonce、request_id，
// 成功換成那個牧場的 token、顯示歡迎回來；帳號沒有備份過換成 S14-03；取消、失敗的提示；返回回到 S14-01。
// 每個狀態的畫面在 test/pages/s14_cases.dart。
import 'dart:async';

import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/auth/sign_in.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/storage/token_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'pages/page_case.dart';
import 'pages/s14_cases.dart';

final _zh = Strings.forLang(AppLang.zhHant);

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
  await tester.pump();
}

void main() {
  group('模型', () {
    test('第一次打開（沒有牧場）：設好登入的建置先問 S14-01；選了開新牧場、從 S13-04 或 S15-03 開新牧場就不再問', () async {
      final m = freshWithSignIn();
      expect(m.showsFirstOpen, isTrue);
      m.chooseNewRanch();
      expect(m.showsFirstOpen, isFalse);
      final m2 = freshWithSignIn()..ranchDeleted = true;
      expect(m2.showsFirstOpen, isFalse, reason: 'S13-04 先顯示');
      m2.startNewRanch();
      expect(m2.showsFirstOpen, isFalse, reason: 'S13-04 的「開新牧場」直接取名');
      final m3 = freshWithSignIn();
      await m3.startOver();
      expect(m3.showsFirstOpen, isFalse, reason: 'S15-03 的「開新牧場」直接取名');
    });

    test('沒設登入的建置（網頁試玩版）：沒有 S14-01，打不開找回', () {
      final m = freshWithSignIn()..needsRanch = true;
      final web = GameModel(api: FakeGameApi(), push: FakePush(), tokens: MemoryTokenStore(), uiTick: null)
        ..needsRanch = true;
      expect(m.showsFirstOpen, isTrue);
      expect(web.showsFirstOpen, isFalse);
      web.openRecover();
      expect(web.recoverOpen, isFalse);
    });

    test('找回：拿 nonce → 登入 → 找回；換成那個牧場的 token 並存起來，顯示歡迎回來', () async {
      final api = FakeGameApi();
      final tokens = MemoryTokenStore();
      final m = GameModel(
        api: api,
        push: FakePush(),
        tokens: tokens,
        now: FakeClock().call,
        uiTick: null,
        signInPlatform: SignInPlatform.iphone,
        signIn: FakeSignIn(),
      )..needsRanch = true;
      m.openRecover();
      final r = await m.recoverRanch(SignInProvider.apple);
      expect(r.status, RecoverStatus.recovered);
      final req = api.recoverRequests.single;
      expect(req.idToken, 'id-apple-nonce-1');
      expect(req.nonce, 'nonce-1');
      expect(api.token, 'tok-recovered');
      expect(tokens.values[TokenStore.tokenKey], 'tok-recovered');
      expect(tokens.values[TokenStore.ranchKey], '晨光河畔牧場');
      expect(m.needsRanch, isFalse);
      expect(m.recoverOpen, isFalse);
      expect(m.welcomeBack, isTrue);
      expect(m.state!.playerId, 1234);
      m.enterRecoveredRanch();
      expect(m.welcomeBack, isFalse);
    });

    test('每次找回都是新的 nonce 和 request_id（找回可以重來）', () async {
      final api = FakeGameApi()..recoverError = const NetworkException('timeout');
      final m = freshWithSignIn(api: api);
      final r1 = await m.recoverRanch(SignInProvider.google);
      expect(r1.error, isA<NetworkActionError>());
      api.recoverError = null;
      await m.recoverRanch(SignInProvider.google);
      expect(api.recoverRequests.map((r) => r.nonce), ['nonce-1', 'nonce-2']);
      expect(api.recoverRequests[1].requestId, isNot(api.recoverRequests[0].requestId));
    });

    test('帳號沒有備份過牧場（account_not_linked）：S14-03；換一個帳號回到登入按鈕', () async {
      final api = FakeGameApi()..recoverError = const ApiException(404, 'account_not_linked', 'not linked');
      final m = freshWithSignIn(api: api)..openRecover();
      final r = await m.recoverRanch(SignInProvider.apple);
      expect(r.status, RecoverStatus.none);
      expect(m.recoverNone, isTrue);
      expect(m.needsRanch, isTrue, reason: '還是沒有牧場');
      m.recoverAnother();
      expect(m.recoverNone, isFalse);
      expect(m.recoverOpen, isTrue);
    });

    test('取消、登入畫面失敗不打伺服器；sign_in_failed 也算登入失敗', () async {
      final signIn = FakeSignIn(result: const SignInCancelled());
      final api = FakeGameApi();
      final m = freshWithSignIn(api: api, signIn: signIn);
      expect((await m.recoverRanch(SignInProvider.apple)).status, RecoverStatus.cancelled);
      signIn.result = const SignInFailed();
      expect((await m.recoverRanch(SignInProvider.apple)).status, RecoverStatus.failed);
      expect(api.recoverRequests, isEmpty);
      signIn.result = null;
      api.recoverError = const ApiException(400, 'sign_in_failed', 'token', {'reason': 'token_expired'});
      expect((await m.recoverRanch(SignInProvider.apple)).status, RecoverStatus.failed);
      expect(m.needsRanch, isTrue);
    });

    test('登入中（S14-06）：登入畫面開著時不算，關掉以後等伺服器回覆才算；這時不能返回', () async {
      final signIn = FakeSignIn()..gate = Completer<void>();
      final api = FakeGameApi()..recoverGate = Completer<void>();
      final m = freshWithSignIn(api: api, signIn: signIn)..openRecover();
      final f = m.recoverRanch(SignInProvider.apple);
      await pumpEventQueue();
      expect(m.recovering, isFalse);
      signIn.gate!.complete();
      await pumpEventQueue();
      expect(m.recovering, isTrue);
      m.closeRecover();
      expect(m.recoverOpen, isTrue, reason: '找回中不能離開');
      api.recoverGate!.complete();
      await f;
      expect(m.recovering, isFalse);
    });
  });

  group('畫面', () {
    setUpAll(loadAppAssets);

    testWidgets('沒設登入的建置（網頁試玩版）：沒有牧場直接取名（S02），沒有 S14-01', (tester) async {
      Screen.w430.apply(tester);
      final m = GameModel(api: FakeGameApi(), push: FakePush(), tokens: MemoryTokenStore(), uiTick: null)
        ..needsRanch = true;
      await pumpAppIn(tester, m, AppLang.zhHant);
      expect(find.byKey(const Key('first-open')), findsNothing);
      expect(find.byKey(const Key('ranch-name')), findsOneWidget);
    });

    testWidgets('S14-01 開新牧場 → S02 取名', (tester) async {
      Screen.w430.apply(tester);
      await pumpAppIn(tester, freshWithSignIn(), AppLang.zhHant);
      expect(find.byKey(const Key('first-open')), findsOneWidget);
      await _tap(tester, 'first-new');
      expect(find.byKey(const Key('ranch-name')), findsOneWidget);
    });

    testWidgets('S14-01 找回我的牧場 → S14-02；返回鈕、手機的返回鍵都回到 S14-01', (tester) async {
      Screen.w430.apply(tester);
      final m = freshWithSignIn();
      await pumpAppIn(tester, m, AppLang.zhHant);
      await _tap(tester, 'first-recover');
      expect(find.byKey(const Key('recover')), findsOneWidget);
      await _tap(tester, 'btn-back');
      expect(find.byKey(const Key('first-open')), findsOneWidget);
      await _tap(tester, 'first-recover');
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byKey(const Key('first-open')), findsOneWidget);
      expect(m.recoverOpen, isFalse);
    });

    testWidgets('找回成功 → S14-04 歡迎回來 → 進牧場', (tester) async {
      Screen.w430.apply(tester);
      final api = FakeGameApi()..switchedStateJson = recoveredState();
      final m = await showRecover(tester, AppLang.zhHant, api: api);
      await _tap(tester, 'sso-google');
      expect(find.byKey(const Key('welcome-back')), findsOneWidget);
      expect(find.text(_zh.s14WelcomeHint), findsOneWidget);
      await _tap(tester, 'enter-recovered');
      expect(find.byKey(const Key('welcome-back')), findsNothing);
      expect(m.welcomeBack, isFalse);
      expect(m.tab, AppTab.ranch);
      expect(find.byKey(const Key('gear')), findsOneWidget, reason: '進到牧場');
    });

    testWidgets('帳號沒有備份過：S14-03；換一個帳號回到按鈕，開新牧場 → S02', (tester) async {
      Screen.w430.apply(tester);
      final api = FakeGameApi()..recoverError = const ApiException(404, 'account_not_linked', 'not linked');
      await showRecover(tester, AppLang.zhHant, api: api);
      await _tap(tester, 'sso-apple');
      expect(find.byKey(const Key('no-ranch')), findsOneWidget);
      await _tap(tester, 'recover-another');
      expect(find.byKey(const Key('sso-apple')), findsOneWidget);
      await _tap(tester, 'sso-apple');
      await _tap(tester, 'recover-new');
      expect(find.byKey(const Key('ranch-name')), findsOneWidget);
    });

    testWidgets('取消登入、登入失敗：各自的提示（S14-08），留在找回頁', (tester) async {
      Screen.w430.apply(tester);
      final signIn = FakeSignIn(result: const SignInCancelled());
      await showRecover(tester, AppLang.zhHant, signIn: signIn);
      await _tap(tester, 'sso-apple');
      expect(find.text(_zh.s13ToastCancelled), findsOneWidget);
      signIn.result = const SignInFailed();
      await _tap(tester, 'sso-apple');
      expect(find.text(_zh.s13ToastFailed), findsOneWidget);
      expect(find.byKey(const Key('recover')), findsOneWidget);
    });
  });

  group('S14-05、S15-03 的「找回我的牧場」', () {
    setUpAll(loadAppAssets);

    testWidgets('S14-05：找回我的牧場 → S14-02；返回鈕、返回鍵回到 S14-05；找回成功 → S14-04 → 進牧場', (tester) async {
      Screen.w430.apply(tester);
      final (m, api) = await showLost(tester, AppLang.zhHant);
      api.switchedStateJson = recoveredState();
      expect(find.byKey(const Key('elsewhere')), findsOneWidget);
      expect(find.text(_zh.s14ElsewhereLead(name: '晨光河畔牧場')), findsOneWidget);
      await _tap(tester, 'lost-recover');
      expect(find.byKey(const Key('recover')), findsOneWidget);
      await _tap(tester, 'btn-back');
      expect(find.byKey(const Key('elsewhere')), findsOneWidget);
      await _tap(tester, 'lost-recover');
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byKey(const Key('elsewhere')), findsOneWidget);
      expect(m.recoverOpen, isFalse);
      await _tap(tester, 'lost-recover');
      await _tap(tester, 'sso-google');
      expect(find.byKey(const Key('welcome-back')), findsOneWidget);
      expect(m.authLost, isNull);
      await _tap(tester, 'enter-recovered');
      expect(find.byKey(const Key('gear')), findsOneWidget, reason: '進到牧場');
    });

    testWidgets('S15-03 帳號失效：一樣可以找回', (tester) async {
      Screen.w430.apply(tester);
      final (_, api) = await showLost(tester, AppLang.zhHant, code: 'unauthorized');
      api.switchedStateJson = recoveredState();
      expect(find.byKey(const Key('auth-lost')), findsOneWidget);
      await _tap(tester, 'lost-recover');
      await _tap(tester, 'sso-apple');
      expect(find.byKey(const Key('welcome-back')), findsOneWidget);
    });

    testWidgets('沒設登入的建置（網頁試玩版）：S14-05、S15-03 都只有「開新牧場」；開新牧場 → S02 取名', (tester) async {
      Screen.w430.apply(tester);
      await showLost(tester, AppLang.zhHant, code: 'unauthorized', withSignIn: false);
      expect(find.byKey(const Key('auth-lost')), findsOneWidget);
      expect(find.byKey(const Key('lost-recover')), findsNothing);
      final (m, _) = await showLost(tester, AppLang.zhHant, withSignIn: false);
      expect(find.byKey(const Key('elsewhere')), findsOneWidget);
      expect(find.byKey(const Key('lost-recover')), findsNothing);
      await _tap(tester, 'start-over');
      await tester.pump();
      expect(m.authLost, isNull);
      expect(find.byKey(const Key('ranch-name')), findsOneWidget, reason: '直接取名，不經過 S14-01');
    });
  });
}
