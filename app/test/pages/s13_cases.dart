// S13 設定的頁面狀態（設計稿 s13.js）：設定主頁、語言、漲跌顏色、刪除牧場、刪除完成、備份牧場（S13-02、S13-07～16、
// S13-19）。設定主頁和備份牧場用設好 Apple／Google 登入的 iPhone 建置（設計稿畫的就是 iPhone）；Android 的狀態另外設。
// 沒設登入的建置（網頁試玩版）沒有「備份牧場」，在 settings_page_test、backup_page_test 檢查。
import 'dart:async';

import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/auth/sign_in.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:cowfarm/ui/settings/settings_page.dart';
import 'package:cowfarm/ui/settings/sso_button.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
import 'page_case.dart';
import 's03_cases.dart';

final _zh = Strings.forLang(AppLang.zhHant);

/// 設計稿的牧場（fixtures.js 的 RANCH）：晨光河畔牧場 #1234、Lv 4。[links] 是綁定的帳號（綁定日期是 2026/10/01）。
/// [newRanch] 是 S13-08、S13-09 的情境：在新手機先開的新牧場「青草小丘農莊 #5678」，Lv 1。
Map<String, dynamic> settingsState({List<String> links = const [], bool newRanch = false}) => {
  ...ranchState(),
  'player_id': newRanch ? 5678 : 1234,
  if (newRanch) ...{'ranch_name': '青草小丘農莊', 'level': 1},
  'account': {
    'links': [
      for (final p in links) {'provider': p, 'linked_at_real': t0},
    ],
  },
};

/// 在牧場按頂列的齒輪，打開設定。[signIn] 是 null 就是沒設登入的建置（網頁試玩版）。
Future<GameModel> showSettings(
  WidgetTester tester,
  AppLang lang, {
  List<String> links = const [],
  FakeGameApi? api,
  SignInService? signIn,
  SignInPlatform platform = SignInPlatform.iphone,
  bool newRanch = false,
}) async {
  final m = await ranchModel(
    state: settingsState(links: links, newRanch: newRanch),
    api: api,
    signIn: signIn,
    signInPlatform: platform,
  );
  await pumpAppIn(tester, m, lang, prefs: swipeHintSeen);
  await tester.tap(find.byKey(const Key('gear')));
  await tester.pump();
  await settleImages(tester);
  return m;
}

/// 設定主頁 → 備份牧場（設好登入的建置）。
Future<GameModel> showBackup(
  WidgetTester tester,
  AppLang lang, {
  List<String> links = const [],
  FakeGameApi? api,
  SignInService? signIn,
  SignInPlatform platform = SignInPlatform.iphone,
  bool newRanch = false,
}) async {
  final m = await showSettings(
    tester,
    lang,
    links: links,
    api: api,
    signIn: signIn ?? FakeSignIn(),
    platform: platform,
    newRanch: newRanch,
  );
  await tester.tap(find.byKey(const Key('set-backup')));
  await tester.pump();
  await tester.pump();
  expect(find.byKey(const Key('settings-backup')), findsOneWidget);
  await settleImages(tester);
  return m;
}

/// S13-08 的情境：在新手機開的新牧場（青草小丘農莊 #5678）按「使用 Apple 登入」，那個帳號已經備份了晨光河畔牧場 #1234。
Future<void> showOtherRanch(WidgetTester tester, AppLang lang) async {
  final api = FakeGameApi()..linkError = accountInUse(level: 4);
  await showBackup(tester, lang, api: api, newRanch: true);
  await tester.tap(find.byKey(const Key('sso-apple')));
  await tester.pump();
  await tester.pump();
  expect(find.byKey(const Key('other-ranch')), findsOneWidget);
  await settleImages(tester);
}

/// 設定主頁 → 刪除我的牧場；[typed] 就在輸入框打「刪除」。
Future<GameModel> showDelete(WidgetTester tester, AppLang lang, {bool typed = false, FakeGameApi? api}) async {
  final m = await showSettings(tester, lang, api: api);
  await tester.ensureVisible(find.byKey(const Key('set-delete')));
  await tester.tap(find.byKey(const Key('set-delete')));
  await tester.pump();
  expect(find.byKey(const Key('delete-card')), findsOneWidget);
  await settleImages(tester);
  if (typed) {
    await tester.enterText(find.byKey(const Key('delete-word')), Strings.forLang(lang).s13DelWord);
    await tester.pump();
  }
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

final s13Cases = [
  PageCase(
    'S13-01',
    '設定主頁（還沒備份）',
    (tester, lang) => showSettings(tester, lang, signIn: FakeSignIn()),
    check: (tester) {
      expect(find.byKey(const Key('settings')), findsOneWidget);
      expect(find.text('晨光河畔牧場'), findsOneWidget);
      expect(find.text('#1234${_zh.gSep}${_zh.level(lv: 4)}'), findsOneWidget);
      expect(find.byKey(const Key('set-backup')), findsOneWidget, reason: '設好登入的建置才有（ceo 2026-10-03）');
      expect(find.text(_zh.s13NotBacked), findsOneWidget);
      expect(find.byKey(const Key('set-privacy')), findsNothing, reason: '隱私權政策的網址 M5 才有');
      expect(find.text(langName(AppLang.zhHant)), findsOneWidget);
      expect(find.text(_zh.s13Footer(game: _zh.appTitle)), findsOneWidget);
    },
  ),
  PageCase(
    'S13-03',
    '刪除牧場：說明後果、還沒輸入',
    (tester, lang) => showDelete(tester, lang),
    check: (tester) {
      expect(find.byKey(const Key('delete-card')), findsOneWidget);
      expect(find.text(_zh.s13DelItem1(name: '晨光河畔牧場')), findsOneWidget);
      expect(find.text(_zh.s13DelItem3), findsOneWidget);
      expect(find.text(_zh.s13DelPrompt(word: _zh.s13DelWord)), findsOneWidget);
      expect(
        tester.widget<AppButton>(find.byKey(const Key('delete-confirm'))).onPressed,
        isNull,
        reason: '還沒輸入「刪除」不能按',
      );
    },
  ),
  PageCase(
    'S13-04',
    '刪除完成',
    (tester, lang) async {
      await showDelete(tester, lang, typed: true);
      await tester.ensureVisible(find.byKey(const Key('delete-confirm')));
      await tester.tap(find.byKey(const Key('delete-confirm')));
      await tester.pump();
      await tester.pump();
      await settleImages(tester);
      expect(find.byKey(const Key('ranch-deleted')), findsOneWidget);
    },
    check: (tester) {
      expect(find.byKey(const Key('ranch-deleted')), findsOneWidget);
      expect(find.text(_zh.s13Deleted), findsOneWidget);
      expect(find.text(_zh.s13Thanks), findsOneWidget);
      expect(find.byKey(const Key('new-ranch')), findsOneWidget);
    },
  ),
  PageCase(
    'S13-05',
    '刪除失敗',
    (tester, lang) async {
      final api = FakeGameApi()..deleteError = const NetworkException('offline');
      await showDelete(tester, lang, typed: true, api: api);
      await tester.ensureVisible(find.byKey(const Key('delete-confirm')));
      await tester.tap(find.byKey(const Key('delete-confirm')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('toast')), findsOneWidget);
    },
    crop: find.byKey(const Key('toast')),
    check: (tester) {
      expect(find.text(_zh.s13DelFailed), findsOneWidget);
      expect(find.byKey(const Key('delete-card')), findsOneWidget, reason: '留在刪除牧場那一頁');
    },
  ),
  PageCase(
    'S13-06',
    '刪除牧場：輸入「刪除」後按鈕才能按',
    (tester, lang) => showDelete(tester, lang, typed: true),
    crop: find.byKey(const Key('delete-form')),
    check: (tester) {
      expect(tester.widget<AppButton>(find.byKey(const Key('delete-confirm'))).onPressed, isNotNull);
    },
  ),
  PageCase(
    'S13-02',
    '備份牧場：還沒綁定（iPhone）',
    (tester, lang) => showBackup(tester, lang),
    check: (tester) {
      expect(find.text(_zh.s13BackupLead), findsOneWidget);
      expect(find.text(_zh.s13BackupWarn), findsOneWidget);
      expect(find.byType(SsoButton), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.byKey(const Key('sso-apple'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('sso-google'))).dy),
        reason: 'Apple 在上',
      );
      expect(
        tester.getSize(find.byKey(const Key('sso-apple'))),
        tester.getSize(find.byKey(const Key('sso-google'))),
        reason: '兩顆一樣大',
      );
      expect(find.text(_zh.s13Privacy), findsOneWidget);
      expect(find.byKey(const Key('backup-before')), findsOneWidget);
      expect(find.text(_zh.s13NotBacked), findsOneWidget);
    },
  ),
  PageCase(
    'S13-07',
    '備份牧場：已經綁定（iPhone，只綁了 Apple）',
    (tester, lang) => showBackup(tester, lang, links: ['apple']),
    check: (tester) {
      expect(find.text(_zh.s13BackupDone), findsOneWidget);
      expect(find.byKey(const Key('bind-apple')), findsOneWidget);
      expect(find.text(_zh.s13BackupBoundOn(date: '2026/10/01')), findsOneWidget);
      expect(find.byKey(const Key('backup-more')), findsOneWidget);
      expect(find.text(_zh.s13BackupAddGoogle), findsOneWidget);
      expect(find.byKey(const Key('sso-apple')), findsNothing);
      expect(find.byKey(const Key('sso-google')), findsOneWidget);
      expect(find.byKey(const Key('backup-before')), findsNothing);
      expect(find.text(_zh.s13Backed), findsOneWidget);
    },
  ),
  PageCase(
    'S13-08',
    '這個帳號已經備份了另一個牧場',
    showOtherRanch,
    check: (tester) {
      expect(find.text(_zh.s13OtherTitle), findsOneWidget);
      expect(find.text('晨光河畔牧場 #1234'), findsOneWidget);
      expect(find.text(_zh.level(lv: 4)), findsOneWidget);
      expect(find.text('青草小丘農莊'), findsOneWidget, reason: '後面是這支手機現在的牧場');
      expect(find.byKey(const Key('switch-go')), findsOneWidget);
    },
  ),
  PageCase(
    'S13-09',
    '換回前再確認：現在的牧場會刪除',
    (tester, lang) async {
      await showOtherRanch(tester, lang);
      await tester.tap(find.byKey(const Key('switch-go')));
      await tester.pump();
    },
    check: (tester) {
      expect(find.text(_zh.s13SwitchTitle), findsOneWidget);
      expect(find.text(_zh.s13SwitchWarn(name: '青草小丘農莊 #5678')), findsOneWidget);
      expect(find.text(_zh.s13SwitchAfter(name: '晨光河畔牧場 #1234')), findsOneWidget);
      expect(find.byKey(const Key('switch-confirm')), findsOneWidget);
    },
  ),
  PageCase(
    'S13-10',
    '設定主頁：已備份',
    (tester, lang) => showSettings(tester, lang, links: ['apple'], signIn: FakeSignIn()),
    crop: find.byKey(const Key('set-account')),
    check: (tester) {
      expect(find.text(_zh.s13Backed), findsOneWidget);
    },
  ),
  PageCase(
    'S13-11',
    'Android 版：只有 Google 一顆（還沒綁定）',
    (tester, lang) => showBackup(tester, lang, platform: SignInPlatform.android),
    crop: find.byKey(const Key('sso-area')),
    check: (tester) {
      expect(find.byKey(const Key('sso-apple')), findsNothing);
      expect(find.byKey(const Key('sso-google')), findsOneWidget);
    },
  ),
  PageCase(
    'S13-12',
    '提示：綁定成功、取消登入、登入失敗、已解除',
    (tester, lang) {
      final s = Strings.forLang(lang);
      return pumpSheet(tester, lang, [
        _toastSlot(ToastKind.ok, s.s13ToastBound(name: 'Apple')),
        _toastSlot(ToastKind.info, s.s13ToastCancelled),
        _toastSlot(ToastKind.err, s.s13ToastFailed),
        _toastSlot(ToastKind.ok, s.s13ToastUnbound(name: 'Apple')),
      ]);
    },
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.byType(ToastPill), findsNWidgets(4));
    },
  ),
  PageCase(
    'S13-13',
    '解除綁定的確認（唯一綁定的帳號多一句提醒）',
    (tester, lang) async {
      await showBackup(tester, lang, links: ['apple']);
      await tester.tap(find.byKey(const Key('unbind-apple')));
      await tester.pump();
    },
    crop: find.byKey(const Key('dialog')),
    check: (tester) {
      expect(find.text(_zh.s13UnbindTitle(name: 'Apple')), findsOneWidget);
      expect(find.text(_zh.s13UnbindLast), findsOneWidget);
    },
  ),
  PageCase(
    'S13-14',
    '兩種帳號都綁了：各一列，沒有登入按鈕',
    (tester, lang) => showBackup(tester, lang, links: ['apple', 'google']),
    crop: find.byKey(const Key('bk-body')),
    check: (tester) {
      expect(find.byKey(const Key('bind-apple')), findsOneWidget);
      expect(find.byKey(const Key('bind-google')), findsOneWidget);
      expect(find.byType(SsoButton), findsNothing);
      expect(find.byKey(const Key('backup-more')), findsNothing);
    },
  ),
  PageCase(
    'S13-15',
    '綁定中…（登入視窗關掉後，等伺服器回覆）',
    (tester, lang) async {
      final api = FakeGameApi()..linkGate = Completer<void>();
      await showBackup(tester, lang, api: api);
      await tester.tap(find.byKey(const Key('sso-apple')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('sso-busy')), findsOneWidget);
    },
    crop: find.byKey(const Key('sso-busy')),
    check: (tester) {
      expect(find.text(_zh.s13Binding), findsOneWidget);
      expect(find.byType(SsoButton), findsNothing);
      expect(find.byKey(const Key('backup-before')), findsNothing);
    },
  ),
  PageCase(
    'S13-16',
    'Android 版：只綁了 Google 時，沒有 Apple 那一列也沒有 Apple 登入按鈕',
    (tester, lang) => showBackup(tester, lang, links: ['google'], platform: SignInPlatform.android),
    crop: find.byKey(const Key('bk-body')),
    check: (tester) {
      expect(find.byKey(const Key('bind-google')), findsOneWidget);
      expect(find.byKey(const Key('bind-apple')), findsNothing);
      expect(find.byType(SsoButton), findsNothing);
    },
  ),
  PageCase(
    'S13-19',
    'Android 版：只綁了 Apple，提醒再綁 Google',
    (tester, lang) => showBackup(tester, lang, links: ['apple'], platform: SignInPlatform.android),
    crop: find.byKey(const Key('bk-body')),
    check: (tester) {
      expect(find.byKey(const Key('bind-apple')), findsOneWidget);
      expect(find.text(_zh.s13BackupAddGoogleAndroid), findsOneWidget);
      expect(find.byKey(const Key('sso-google')), findsOneWidget);
      expect(find.byKey(const Key('sso-apple')), findsNothing);
    },
  ),
  PageCase(
    'S13-20',
    '設定頁斷線：「連線中…」放在標題那一列',
    (tester, lang) async {
      final m = await showSettings(tester, lang, signIn: FakeSignIn());
      (m.push as FakePush).isConnected = false;
      await tester.pump();
    },
    check: (tester) {
      final pill = find.byKey(const Key('offline-pill'));
      expect(pill, findsOneWidget, reason: '只有標題列那一顆，頂列下面的不畫');
      final back = tester.getRect(find.byKey(const Key('btn-back')));
      expect(tester.getCenter(pill).dy, closeTo(back.center.dy, 1), reason: '跟返回鈕同一列');
      expect(tester.getRect(pill).right, greaterThan(tester.getRect(find.byKey(const Key('me-card'))).right - 2));
      expect(find.text(_zh.s13Title), findsOneWidget);
    },
  ),
  PageCase(
    'S13-21',
    '備份牧場斷線：登入鈕變淡、不能按',
    (tester, lang) async {
      final m = await showBackup(tester, lang);
      (m.push as FakePush).isConnected = false;
      await tester.pump();
    },
    crop: find.byKey(const Key('sso-area')),
    check: (tester) {
      for (final p in ['apple', 'google']) {
        expect(tester.widget<SsoButton>(find.byKey(Key('sso-$p'))).onTap, isNull, reason: p);
      }
      expect(find.text(_zh.s13SsoOffline), findsOneWidget);
      expect(find.text(_zh.s13Privacy), findsNothing, reason: '隱私那一句換成要連上網路');
      expect(find.byKey(const Key('offline-pill')), findsOneWidget);
    },
  ),
  PageCase(
    'S13-17',
    '語言：繁體中文、English、ไทย',
    (tester, lang) async {
      await showSettings(tester, lang);
      await tester.tap(find.byKey(const Key('set-lang')));
      await tester.pump();
    },
    check: (tester) {
      expect(find.byKey(const Key('settings-lang')), findsOneWidget);
      for (final l in AppLang.values) {
        expect(find.text(langName(l)), findsOneWidget);
      }
      expect(find.text(_zh.s13LangHint), findsOneWidget);
    },
  ),
  PageCase(
    'S13-18',
    '漲跌顏色：漲紅跌綠（繁中預設）或綠漲紅跌（英文、泰文預設）',
    (tester, lang) async {
      await showSettings(tester, lang);
      await tester.tap(find.byKey(const Key('set-updown')));
      await tester.pump();
    },
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.text(_zh.s13RedUp), findsOneWidget);
      expect(find.text(_zh.s13GreenUp), findsOneWidget);
      expect(find.text(_zh.s13UdNote), findsOneWidget);
    },
  ),
];
