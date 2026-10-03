// 備份牧場（S13 B）的畫面流程：沒設登入的建置（網頁試玩版）沒有任何入口；齒輪小點（G-10）；綁定的提示（S13-12）；
// 帳號已經綁了別的牧場 → 換回（S13-08、S13-09）；解除綁定（S13-13）；斷線時登入按鈕停用。
// 每個狀態的畫面在 test/pages/s13_cases.dart，流程的邏輯在 test/backup_model_test.dart。
import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/app.dart';
import 'package:cowfarm/auth/sign_in.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/state/settings.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:cowfarm/ui/settings/sso_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'pages/page_case.dart';
import 'pages/s03_cases.dart';
import 'pages/s13_cases.dart';

final _zh = Strings.forLang(AppLang.zhHant);

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
  await tester.pump();
}

Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('btn-back')));
  await tester.pump();
}

void main() {
  setUpAll(loadAppAssets);

  testWidgets('沒設登入的建置（網頁試玩版）：設定沒有「備份牧場」，齒輪沒有小點', (tester) async {
    Screen.w430.apply(tester);
    await showSettings(tester, AppLang.zhHant);
    expect(find.byKey(const Key('set-backup')), findsNothing);
    expect(find.byKey(const Key('set-delete')), findsOneWidget);
    await _back(tester);
    expect(find.byKey(const Key('gear-dot')), findsNothing);
  });

  testWidgets('齒輪小點（G-10）：還沒備份、沒打開過備份牧場頁才有；打開過一次就不再出現', (tester) async {
    Screen.w430.apply(tester);
    final m = await ranchModel(state: settingsState(), signIn: FakeSignIn());
    final store = MemoryPrefsStore(swipeHintSeen);
    final settings = SettingsController(store, deviceLocales: () => [AppLang.zhHant.locale]);
    await settings.load();
    await tester.pumpWidget(CowFarmApp(model: m, settings: settings));
    await tester.pump();
    expect(find.byKey(const Key('gear-dot')), findsOneWidget);
    await tester.tap(find.byKey(const Key('gear')));
    await tester.pump();
    await _tap(tester, 'set-backup');
    expect(settings.backupSeen, isTrue);
    expect(store.values[SettingsController.backupSeenKey], '1', reason: '記在手機上');
    await _back(tester);
    await _back(tester);
    expect(find.byKey(const Key('gear-dot')), findsNothing, reason: '打開過了，沒備份也不再出現');
  });

  testWidgets('齒輪小點：已經綁了帳號就沒有', (tester) async {
    Screen.w430.apply(tester);
    await showSettings(tester, AppLang.zhHant, links: ['google'], signIn: FakeSignIn());
    await _back(tester);
    expect(find.byKey(const Key('gear-dot')), findsNothing);
  });

  testWidgets('綁定 Apple：備份好了的提示，牧場卡換成「已備份」，多一列 Apple 帳號，只剩 Google 的按鈕', (tester) async {
    Screen.w430.apply(tester);
    final m = await showBackup(tester, AppLang.zhHant);
    await _tap(tester, 'sso-apple');
    expect(find.text(_zh.s13ToastBound(name: 'Apple')), findsOneWidget);
    expect(find.text(_zh.s13Backed), findsOneWidget);
    expect(find.byKey(const Key('bind-apple')), findsOneWidget);
    expect(find.byKey(const Key('sso-apple')), findsNothing);
    expect(find.byKey(const Key('sso-google')), findsOneWidget);
    expect(m.accountLinks.single.provider, 'apple');
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const Key('toast')), findsNothing, reason: '提示 2.5 秒後收起來');
  });

  testWidgets('取消登入、登入失敗：各自的提示，沒有綁', (tester) async {
    Screen.w430.apply(tester);
    final signIn = FakeSignIn(result: const SignInCancelled());
    await showBackup(tester, AppLang.zhHant, signIn: signIn);
    await _tap(tester, 'sso-google');
    expect(find.text(_zh.s13ToastCancelled), findsOneWidget);
    signIn.result = const SignInFailed();
    await _tap(tester, 'sso-google');
    expect(find.text(_zh.s13ToastFailed), findsOneWidget);
    expect(find.text(_zh.s13NotBacked), findsOneWidget);
  });

  testWidgets('帳號已經綁了別的牧場 → 換回那個牧場 → 再確認 → 換成那個牧場，回到牧場分頁', (tester) async {
    Screen.w430.apply(tester);
    final api = FakeGameApi()..linkError = accountInUse(level: 4);
    final m = await showBackup(tester, AppLang.zhHant, api: api, newRanch: true);
    await _tap(tester, 'sso-apple');
    expect(find.text(_zh.s13OtherTitle), findsOneWidget);
    await _tap(tester, 'switch-go');
    expect(find.text(_zh.s13SwitchTitle), findsOneWidget);
    await _tap(tester, 'switch-confirm');
    await settleImages(tester);
    expect(m.settingsView, isNull, reason: '設定頁關掉');
    expect(m.tab, AppTab.ranch);
    expect(m.ranchName, '晨光河畔牧場');
    expect(api.token, 'tok-switched');
    expect(find.text('晨光河畔牧場'), findsWidgets, reason: '頂列換成那個牧場');
  });

  testWidgets('換回：取消就關掉，什麼都不做；再確認那一步取消也一樣', (tester) async {
    Screen.w430.apply(tester);
    final api = FakeGameApi()..linkError = accountInUse();
    await showBackup(tester, AppLang.zhHant, api: api, newRanch: true);
    await _tap(tester, 'sso-apple');
    await _tap(tester, 'switch-cancel');
    expect(find.byKey(const Key('dialog')), findsNothing);
    await _tap(tester, 'sso-apple');
    await _tap(tester, 'switch-go');
    await _tap(tester, 'switch-cancel');
    expect(find.byKey(const Key('dialog')), findsNothing);
    expect(api.switchRequests, isEmpty);
  });

  testWidgets('換回沒收到回應：留著再確認的對話框、跳提示，再按一次就換好', (tester) async {
    Screen.w430.apply(tester);
    final api = FakeGameApi()..linkError = accountInUse();
    final m = await showBackup(tester, AppLang.zhHant, api: api, newRanch: true);
    await _tap(tester, 'sso-apple');
    await _tap(tester, 'switch-go');
    api.switchError = const NetworkException('timeout');
    await _tap(tester, 'switch-confirm');
    expect(find.byKey(const Key('switch-confirm')), findsOneWidget, reason: '對話框還在');
    expect(find.byKey(const Key('toast')), findsOneWidget);
    api.switchError = null;
    await _tap(tester, 'switch-confirm');
    expect(m.ranchName, '晨光河畔牧場');
    expect(api.switchRequests[1].requestId, api.switchRequests[0].requestId, reason: '原封不動重送');
  });

  testWidgets('解除綁定：確認以後提示「已解除」，那一列不見、登入按鈕回來；取消就不解除', (tester) async {
    Screen.w430.apply(tester);
    final m = await showBackup(tester, AppLang.zhHant, links: ['apple', 'google']);
    await _tap(tester, 'unbind-google');
    expect(find.text(_zh.s13UnbindTitle(name: 'Google')), findsOneWidget);
    expect(find.byKey(const Key('unbind-last')), findsNothing, reason: '還有 Apple，不是唯一的');
    await _tap(tester, 'unbind-cancel');
    expect(find.byKey(const Key('dialog')), findsNothing);
    await _tap(tester, 'unbind-google');
    await _tap(tester, 'unbind-confirm');
    expect(find.text(_zh.s13ToastUnbound(name: 'Google')), findsOneWidget);
    expect(find.byKey(const Key('bind-google')), findsNothing);
    expect(find.byKey(const Key('sso-google')), findsOneWidget);
    expect(m.accountLinks.map((l) => l.provider), ['apple']);
    await _tap(tester, 'unbind-apple');
    expect(find.byKey(const Key('unbind-last')), findsOneWidget, reason: '唯一綁定的帳號多一句');
  });

  testWidgets('斷線：登入按鈕和「解除」停用，按了不打伺服器', (tester) async {
    Screen.w430.apply(tester);
    final api = FakeGameApi();
    final m = await showBackup(tester, AppLang.zhHant, api: api, links: ['apple']);
    (m.push as FakePush).isConnected = false;
    await tester.pump();
    expect(tester.widget<SsoButton>(find.byKey(const Key('sso-google'))).onTap, isNull);
    expect(tester.widget<AppButton>(find.byKey(const Key('unbind-apple'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('sso-google')), warnIfMissed: false);
    await tester.pump();
    expect(api.calls.where((c) => c == 'nonce'), isEmpty);
  });

  testWidgets('讀螢幕：登入按鈕讀「使用 Apple 登入」、點得到', (tester) async {
    Screen.w430.apply(tester);
    final handle = tester.ensureSemantics();
    final api = FakeGameApi();
    await showBackup(tester, AppLang.zhHant, api: api);
    expect(
      tester.getSemantics(find.byKey(const Key('sso-apple'))),
      isSemantics(label: _zh.s13SsoSignIn(name: 'Apple'), isButton: true, hasTapAction: true),
    );
    tester.semantics.tap(find.semantics.byLabel(_zh.s13SsoSignIn(name: 'Apple')));
    await tester.pump();
    await tester.pump();
    expect(api.linkRequests.single.provider, SignInProvider.apple);
    handle.dispose();
  });
}
