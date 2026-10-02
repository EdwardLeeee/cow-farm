// S13 設定的頁面狀態（設計稿 s13.js）：設定主頁、語言、漲跌顏色、刪除牧場、刪除完成。
// 備份牧場（S13-02、S13-07～09、S13-11～16、S13-19）下一個 PR 做，還在待做清單。
import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:cowfarm/ui/settings/settings_page.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
import 'page_case.dart';
import 's03_cases.dart';

final _zh = Strings.forLang(AppLang.zhHant);

/// 設計稿的牧場（fixtures.js 的 RANCH）：晨光河畔牧場 #1234、Lv 4。[links] 是綁定的帳號。
Map<String, dynamic> settingsState({List<String> links = const []}) => {
  ...ranchState(),
  'player_id': 1234,
  'account': {
    'links': [
      for (final p in links) {'provider': p, 'linked_at_real': 1790771411.2},
    ],
  },
};

/// 在牧場按頂列的齒輪，打開設定。
Future<GameModel> showSettings(
  WidgetTester tester,
  AppLang lang, {
  List<String> links = const [],
  FakeGameApi? api,
}) async {
  final m = await ranchModel(
    state: settingsState(links: links),
    api: api,
  );
  await pumpAppIn(tester, m, lang, prefs: swipeHintSeen);
  await tester.tap(find.byKey(const Key('gear')));
  await tester.pump();
  await settleImages(tester);
  return m;
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

final s13Cases = [
  PageCase(
    'S13-01',
    '設定主頁（還沒備份）',
    (tester, lang) => showSettings(tester, lang),
    check: (tester) {
      expect(find.byKey(const Key('settings')), findsOneWidget);
      expect(find.text('晨光河畔牧場'), findsOneWidget);
      expect(find.text('#1234${_zh.gSep}${_zh.level(lv: 4)}'), findsOneWidget);
      expect(find.text(_zh.s13NotBacked), findsOneWidget);
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
    'S13-10',
    '設定主頁：已備份',
    (tester, lang) => showSettings(tester, lang, links: ['apple']),
    crop: find.byKey(const Key('set-account')),
    check: (tester) {
      expect(find.text(_zh.s13Backed), findsOneWidget);
      expect(find.text(_zh.s13NotBacked), findsNothing);
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
