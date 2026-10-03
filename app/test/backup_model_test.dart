// 備份牧場（S13 B；協定 5.0–5.4）的流程：每次登入都拿新的 nonce、憑證原樣送給伺服器；取消、失敗不綁；
// 帳號已經綁了別的牧場回那個牧場和 ticket；換回時換掉 token、清掉舊牧場，沒收到回應再按原封不動重送；
// 換回以後舊牧場還在路上的 401 不算失效；解除綁定。畫面在 test/backup_page_test.dart、test/pages/s13_cases.dart。
import 'dart:async';

import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/auth/sign_in.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/storage/token_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  test('沒設 client ID 的建置（網頁版）：沒有登入，按了也不打伺服器', () async {
    final (m, api, _) = await loadedModel();
    expect(m.canSignIn, isFalse);
    final r = await m.bindAccount(SignInProvider.apple);
    expect(r.status, BindStatus.error);
    expect(api.calls.where((c) => c == 'nonce' || c.startsWith('link')), isEmpty);
  });

  test('綁定 Apple：先拿 nonce 交給登入畫面，憑證、nonce、authorization code 原樣送給伺服器', () async {
    final signIn = FakeSignIn();
    final (m, api, _) = await loadedModel(signIn: signIn);
    expect(m.accountLinks, isEmpty);
    final r = await m.bindAccount(SignInProvider.apple);
    expect(r.status, BindStatus.bound);
    expect(signIn.calls.single.nonce, 'nonce-1');
    final req = api.linkRequests.single;
    expect(req.provider, SignInProvider.apple);
    expect(req.idToken, 'id-apple-nonce-1');
    expect(req.nonce, 'nonce-1');
    expect(req.authorizationCode, 'code-nonce-1');
    expect(m.accountLinks.single.provider, 'apple');
    expect(m.busy, isFalse);
  });

  test('每次登入都換新的 nonce 和 request_id（nonce 只能用一次，不論成功失敗）', () async {
    final signIn = FakeSignIn(result: const SignInFailed());
    final (m, api, _) = await loadedModel(signIn: signIn);
    await m.bindAccount(SignInProvider.google);
    signIn.result = null;
    await m.bindAccount(SignInProvider.google);
    await m.bindAccount(SignInProvider.apple);
    expect(signIn.calls.map((c) => c.nonce), ['nonce-1', 'nonce-2', 'nonce-3']);
    expect(api.linkRequests.map((r) => r.nonce), ['nonce-2', 'nonce-3']);
    expect(api.linkRequests[0].authorizationCode, isNull, reason: 'Google 不送 authorization code');
    expect(api.linkRequests[0].requestId, isNot(api.linkRequests[1].requestId));
  });

  test('取消、登入畫面失敗：不打伺服器的綁定；伺服器說憑證不對（sign_in_failed）也算登入失敗', () async {
    final signIn = FakeSignIn(result: const SignInCancelled());
    final (m, api, _) = await loadedModel(signIn: signIn);
    expect((await m.bindAccount(SignInProvider.apple)).status, BindStatus.cancelled);
    signIn.result = const SignInFailed();
    expect((await m.bindAccount(SignInProvider.apple)).status, BindStatus.failed);
    expect(api.linkRequests, isEmpty);
    signIn.result = null;
    api.linkError = const ApiException(400, 'sign_in_failed', 'nonce', {'reason': 'nonce_invalid'});
    expect((await m.bindAccount(SignInProvider.apple)).status, BindStatus.failed);
    expect(m.accountLinks, isEmpty);
  });

  test('綁定中（S13-15）：登入畫面開著時不算，關掉以後等伺服器回覆才算', () async {
    final signIn = FakeSignIn()..gate = Completer<void>();
    final api = FakeGameApi()..linkGate = Completer<void>();
    final (m, _, _) = await loadedModel(api: api, signIn: signIn);
    final f = m.bindAccount(SignInProvider.google);
    await pumpEventQueue();
    expect(m.binding, isFalse, reason: '登入畫面還開著');
    expect(m.busy, isTrue);
    signIn.gate!.complete();
    await pumpEventQueue();
    expect(m.binding, isTrue);
    api.linkGate!.complete();
    await f;
    expect(m.binding, isFalse);
    expect(m.busy, isFalse);
  });

  test('連不上：一般的網路錯誤，沒有綁', () async {
    final (m, api, _) = await loadedModel(signIn: FakeSignIn());
    api.nonceError = const NetworkException('down');
    final r = await m.bindAccount(SignInProvider.apple);
    expect(r.status, BindStatus.error);
    expect(r.error, isA<NetworkActionError>());
    expect(api.linkRequests, isEmpty);
  });

  test('帳號已經綁了別的牧場（account_in_use）：回那個牧場和 ticket（S13-08）', () async {
    final (m, api, _) = await loadedModel(signIn: FakeSignIn());
    api.linkError = accountInUse();
    final r = await m.bindAccount(SignInProvider.apple);
    expect(r.status, BindStatus.conflict);
    expect(r.conflict!.ticket, 'ticket-1');
    expect(r.conflict!.ranch.playerId, 1234);
    expect(r.conflict!.ranch.level, 7);
    expect(m.accountLinks, isEmpty);
  });

  test('換回（S13-09）：換成那個牧場的 token 並存起來、用回應的 state、推播重連；舊牧場開著的頁面都清掉', () async {
    final tokens = MemoryTokenStore({TokenStore.tokenKey: 'tok', TokenStore.ranchKey: '晨光草原牧場'});
    final (m, api, push) = await loadedModel(signIn: FakeSignIn(), tokens: tokens);
    api.linkError = accountInUse();
    final conflict = (await m.bindAccount(SignInProvider.apple)).conflict!;
    m.tab = AppTab.breed;
    m.breedSireKey = '2';
    m.openSettings();
    m.openSettingsView(SettingsView.backup);
    final connects = push.connects;
    final r = await m.switchRanch(conflict);
    expect(r.ok, isTrue);
    expect(api.switchRequests.single.ticket, 'ticket-1');
    expect(api.token, 'tok-switched');
    expect(tokens.values[TokenStore.tokenKey], 'tok-switched');
    expect(tokens.values[TokenStore.ranchKey], '晨光河畔牧場');
    expect(m.ranchName, '晨光河畔牧場');
    expect(m.state!.playerId, 1234);
    expect(m.state!.level, 7);
    expect(m.accountLinks.single.provider, 'apple');
    expect(push.token, 'tok-switched');
    expect(push.connects, connects + 1);
    expect(m.settingsView, isNull);
    expect(m.tab, AppTab.ranch);
    expect(m.breedSireKey, isNull, reason: '牛的編號每個牧場都從 1 開始，選好的公牛不能留給新牧場');
    expect(m.needsRanch, isFalse);
    expect(m.authLost, isNull);
  });

  test('換回沒收到回應，再按：同一個 ticket、同一個 request_id 原封不動重送；ticket 換了才用新的', () async {
    final (m, api, _) = await loadedModel(signIn: FakeSignIn());
    api.switchError = const NetworkException('timeout');
    api.linkError = accountInUse(ticket: 'ticket-1');
    final conflict = (await m.bindAccount(SignInProvider.apple)).conflict!;
    final r1 = await m.switchRanch(conflict);
    expect(r1.error, isA<NetworkActionError>());
    expect(api.token, 'tok', reason: '沒換成功，token 不動');
    api.switchError = null;
    await m.switchRanch(conflict);
    expect(api.switchRequests, hasLength(2));
    expect(api.switchRequests[1].requestId, api.switchRequests[0].requestId);
    expect(api.switchRequests[1].ticket, 'ticket-1');

    // 之後又遇到另一個 ticket：新的 request_id
    api.linkError = accountInUse(ticket: 'ticket-2');
    final c2 = (await m.bindAccount(SignInProvider.google)).conflict!;
    api.switchError = const NetworkException('timeout');
    await m.switchRanch(c2);
    expect(api.switchRequests[2].requestId, isNot(api.switchRequests[0].requestId));
  });

  test('換回失敗（ticket 過期）：留在原本的牧場，下次換回用新的 request_id', () async {
    final (m, api, _) = await loadedModel(signIn: FakeSignIn());
    api.linkError = accountInUse();
    final conflict = (await m.bindAccount(SignInProvider.apple)).conflict!;
    api.switchError = const ApiException(400, 'sign_in_failed', 'ticket', {'reason': 'ticket_expired'});
    final r = await m.switchRanch(conflict);
    expect((r.error as ApiActionError).error.code, 'sign_in_failed');
    expect(api.token, 'tok');
    expect(m.authLost, isNull);
    api.switchError = null;
    await m.switchRanch(conflict);
    expect(api.switchRequests[1].requestId, isNot(api.switchRequests[0].requestId));
  });

  test('換回以後，舊牧場還在路上的請求回 401：不算這支手機的 token 失效；新 token 的 401 才算', () async {
    final (m, api, _) = await loadedModel(signIn: FakeSignIn());
    api.linkError = accountInUse();
    final conflict = (await m.bindAccount(SignInProvider.apple)).conflict!;
    await m.switchRanch(conflict);
    api.stateError = const ApiException(401, 'unauthorized', 'token', {}, 'tok');
    await m.refreshState();
    expect(m.authLost, isNull, reason: '舊牧場（tok）已經刪掉了，那是它的 401');
    api.stateError = const ApiException(401, 'unauthorized', 'token', {}, 'tok-switched');
    await m.refreshState();
    expect(m.authLost, 'unauthorized');
  });

  test('解除綁定（S13-13）：回剩下的綁定；伺服器說本來就沒綁（not_linked）也算解除了', () async {
    final (m, api, _) = await loadedModel(signIn: FakeSignIn());
    await m.bindAccount(SignInProvider.apple);
    await m.bindAccount(SignInProvider.google);
    expect(m.accountLinks.map((l) => l.provider), ['apple', 'google']);
    expect((await m.unlinkAccount(SignInProvider.apple)).ok, isTrue);
    expect(m.accountLinks.map((l) => l.provider), ['google']);
    api.unlinkError = const ApiException(400, 'not_linked', 'not linked');
    expect((await m.unlinkAccount(SignInProvider.google)).ok, isTrue);
    expect(m.accountLinks, isEmpty);
    expect(api.unlinkRequests.map((r) => r.provider), [SignInProvider.apple, SignInProvider.google]);
  });
}
