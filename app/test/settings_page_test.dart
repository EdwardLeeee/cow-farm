// S13 設定頁的行為：頂列齒輪打開、返回；音效、語言、漲跌顏色記在手機上；刪除牧場（打「刪除」才能按、成功清掉 token
// 換成 S13-04、失敗再按用同一個 request_id、401 當成刪掉了、刪掉以後舊牧場的回應不算）。畫面本身在 test/pages/s13_cases.dart。
import 'dart:async';

import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/app.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/state/settings.dart';
import 'package:cowfarm/storage/token_store.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:cowfarm/ui/settings/settings_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'pages/page_case.dart';
import 'pages/s03_cases.dart';
import 'pages/s13_cases.dart';

final _zh = Strings.forLang(AppLang.zhHant);
final _en = Strings.forLang(AppLang.en);

/// 放進 app，偏好設定存在 [store]（測試看有沒有記住）。
Future<SettingsController> _pump(WidgetTester tester, GameModel m, MemoryPrefsStore store, {AppLang? lang}) async {
  final settings = SettingsController(store, deviceLocales: () => [(lang ?? AppLang.zhHant).locale]);
  await settings.load();
  await tester.pumpWidget(CowFarmApp(model: m, settings: settings));
  await tester.pump();
  return settings;
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
}

VoidCallback? _confirm(WidgetTester tester) =>
    tester.widget<AppButton>(find.byKey(const Key('delete-confirm'))).onPressed;

/// /v1/state 等到 [gate] 才回；設了 [lateError] 就在那時候丟（刪掉牧場以後才回來的舊請求）。
class _SlowStateApi extends FakeGameApi {
  _SlowStateApi() : super(state: settingsState());
  Completer<void>? gate;
  Exception? lateError;

  @override
  Future<GameState> getState() async {
    final g = gate;
    if (g != null) {
      await g.future;
      if (lateError case final e?) throw e;
    }
    return super.getState();
  }
}

void main() {
  setUpAll(loadAppAssets);

  testWidgets('頂列的齒輪打開設定；返回回到原本那一頁（市場），手機的返回鍵一層一層退', (tester) async {
    Screen.w390.apply(tester);
    final m = await ranchModel(state: settingsState());
    m.selectTab(AppTab.market);
    await _pump(tester, m, MemoryPrefsStore({...swipeHintSeen}));
    await _tap(tester, 'gear');
    expect(find.byKey(const Key('settings')), findsOneWidget);
    expect(m.settingsView, SettingsView.home);

    await _tap(tester, 'btn-back');
    expect(m.settingsView, isNull);
    expect(m.tab, AppTab.market, reason: '回到原本那一頁');

    // 語言頁 → 返回鍵 → 設定主頁 → 返回鍵 → 關掉設定
    await _tap(tester, 'gear');
    await _tap(tester, 'set-lang');
    expect(m.settingsView, SettingsView.language);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(m.settingsView, SettingsView.home);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(m.settingsView, isNull);
  });

  testWidgets('讀螢幕也按得到：每一列的無障礙節點有名字、有點擊動作（網頁版走查就是照這個點）', (tester) async {
    Screen.w390.apply(tester);
    final handle = tester.ensureSemantics();
    final m = await ranchModel(state: settingsState());
    await _pump(tester, m, MemoryPrefsStore({...swipeHintSeen}));
    await _tap(tester, 'gear');
    for (final (key, label) in [
      ('set-sound', _zh.s13Sound),
      ('set-lang', '${_zh.s13Language} 繁體中文'),
      ('set-updown', '${_zh.s13Updown} ${_zh.s13RedUp}'),
      ('set-delete', _zh.s13Delete),
    ]) {
      expect(tester.getSemantics(find.byKey(Key(key))), isSemantics(label: label, hasTapAction: true), reason: key);
    }
    expect(find.byKey(const Key('set-backup')), findsNothing, reason: '備份牧場下一個 PR 做');
    handle.dispose();
  });

  testWidgets('音效開關：點一下關掉，記在手機上', (tester) async {
    Screen.w390.apply(tester);
    final store = MemoryPrefsStore({...swipeHintSeen});
    final m = await ranchModel(state: settingsState());
    final settings = await _pump(tester, m, store);
    expect(settings.soundOn, isTrue, reason: '預設開');
    await _tap(tester, 'gear');
    await _tap(tester, 'set-sound');
    expect(settings.soundOn, isFalse);
    expect(store.values[SettingsController.soundKey], '0');
    expect(tester.widget<SetToggle>(find.byType(SetToggle)).on, isFalse);
  });

  testWidgets('語言：選 English 馬上換，留在語言頁；設定主頁顯示 English', (tester) async {
    Screen.w390.apply(tester);
    final store = MemoryPrefsStore({...swipeHintSeen});
    final m = await ranchModel(state: settingsState());
    await _pump(tester, m, store);
    await _tap(tester, 'gear');
    await _tap(tester, 'set-lang');
    await _tap(tester, 'lang-en');
    expect(store.values[SettingsController.langKey], 'en');
    expect(find.text(_en.s13Language), findsOneWidget, reason: '標題換成英文，還在語言頁');
    await _tap(tester, 'btn-back');
    expect(find.text(_en.s13Title), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('漲跌顏色：選綠漲紅跌，面板收起來，記在手機上', (tester) async {
    Screen.w390.apply(tester);
    final store = MemoryPrefsStore({...swipeHintSeen});
    final m = await ranchModel(state: settingsState());
    final settings = await _pump(tester, m, store);
    expect(settings.upIsRed, isTrue, reason: '繁中預設漲紅跌綠');
    await _tap(tester, 'gear');
    await _tap(tester, 'set-updown');
    expect(find.byKey(const Key('sheet')), findsOneWidget);
    await _tap(tester, 'ud-green');
    expect(find.byKey(const Key('sheet')), findsNothing);
    expect(settings.upIsRed, isFalse);
    expect(store.values[SettingsController.upColorKey], 'green');
  });

  testWidgets('刪除牧場：打「刪除」才能按；刪掉以後清掉 token，換成 S13-04，按「開新牧場」到取名', (tester) async {
    Screen.w390.apply(tester);
    final api = FakeGameApi(state: settingsState());
    final (m, _, push) = await loadedModel(api: api);
    final tokens = m.tokens as MemoryTokenStore;
    await _pump(tester, m, MemoryPrefsStore({...swipeHintSeen}));
    await _tap(tester, 'gear');
    await _tap(tester, 'set-delete');
    expect(_confirm(tester), isNull);
    await tester.enterText(find.byKey(const Key('delete-word')), '刪');
    await tester.pump();
    expect(_confirm(tester), isNull, reason: '只打一個字不能按');
    await tester.enterText(find.byKey(const Key('delete-word')), _zh.s13DelWord);
    await tester.pump();
    expect(_confirm(tester), isNotNull);

    await _tap(tester, 'delete-confirm');
    await tester.pump();
    expect(api.calls, contains('delete'));
    expect(tokens.values[TokenStore.tokenKey], isNull);
    expect(api.token, isNull);
    expect(push.closes, greaterThan(0), reason: '關掉推播');
    expect(find.byKey(const Key('ranch-deleted')), findsOneWidget);

    // 計時器之類的再拿 state：沒有 token 就不打，也不會變成「帳號失效」
    expect(await m.refreshState(), isFalse);
    expect(m.authLost, isNull);
    expect(find.byKey(const Key('ranch-deleted')), findsOneWidget);

    await _tap(tester, 'new-ranch');
    expect(find.byKey(const Key('ranch-name')), findsOneWidget, reason: 'S02 取名');
    expect(m.tab, AppTab.ranch);
    expect(m.settingsView, isNull);
  });

  testWidgets('刪除失敗（連不上）：跳 S13-05、留在這一頁；再按一次用同一個 request_id', (tester) async {
    Screen.w390.apply(tester);
    final api = FakeGameApi(state: settingsState())..deleteError = const NetworkException('offline');
    final (m, _, _) = await loadedModel(api: api);
    await _pump(tester, m, MemoryPrefsStore({...swipeHintSeen}));
    await _tap(tester, 'gear');
    await _tap(tester, 'set-delete');
    await tester.enterText(find.byKey(const Key('delete-word')), _zh.s13DelWord);
    await tester.pump();
    await _tap(tester, 'delete-confirm');
    await tester.pump();
    expect(find.text(_zh.s13DelFailed), findsOneWidget);
    expect(find.byKey(const Key('delete-card')), findsOneWidget);
    expect(m.ranchDeleted, isFalse);

    api.deleteError = null;
    await _tap(tester, 'delete-confirm');
    await tester.pump();
    expect(api.deleteRequestIds, hasLength(2));
    expect(api.deleteRequestIds[1], api.deleteRequestIds[0], reason: '前一次可能其實刪掉了，伺服器回第一次的回應');
    expect(find.byKey(const Key('ranch-deleted')), findsOneWidget);
  });

  testWidgets('英文：打 delete（小寫）也可以按', (tester) async {
    Screen.w390.apply(tester);
    final m = await ranchModel(state: settingsState());
    await _pump(tester, m, MemoryPrefsStore({...swipeHintSeen}), lang: AppLang.en);
    await _tap(tester, 'gear');
    await _tap(tester, 'set-delete');
    await tester.enterText(find.byKey(const Key('delete-word')), 'delete');
    await tester.pump();
    expect(_confirm(tester), isNotNull);
  });

  test('刪除時伺服器回 401 unauthorized：當成已經刪掉了（前一次刪掉了、回應沒收到）', () async {
    final api = FakeGameApi()..deleteError = const ApiException(401, 'unauthorized', 'token');
    final (m, _, _) = await loadedModel(api: api);
    final r = await m.deleteRanch();
    expect(r.ok, isTrue);
    expect(m.ranchDeleted, isTrue);
    expect(m.needsRanch, isTrue);
    expect(m.authLost, isNull);
  });

  test('刪除時牧場已經在別的手機（signed_in_elsewhere）：顯示 S14-05，不算刪掉', () async {
    final api = FakeGameApi()..deleteError = const ApiException(401, 'signed_in_elsewhere', 'elsewhere');
    final (m, _, _) = await loadedModel(api: api);
    final r = await m.deleteRanch();
    expect(r.ok, isFalse);
    expect(m.ranchDeleted, isFalse);
    expect(m.authLost, 'signed_in_elsewhere');
  });

  test('刪掉以後才回來的舊請求：舊牧場的 state 不放回來，401 也不算帳號失效', () async {
    final api = _SlowStateApi();
    final (m, _, _) = await loadedModel(api: api);
    api.gate = Completer<void>();
    final pending = m.refreshState();
    expect((await m.deleteRanch()).ok, isTrue);
    api.gate!.complete();
    await pending;
    expect(m.state, isNull, reason: '舊牧場的 state 丟掉');

    final api2 = _SlowStateApi();
    final (m2, _, _) = await loadedModel(api: api2);
    api2
      ..gate = Completer<void>()
      ..lateError = const ApiException(401, 'unauthorized', 'gone');
    final pending2 = m2.refreshState();
    expect((await m2.deleteRanch()).ok, isTrue);
    api2.gate!.complete();
    await pending2;
    expect(m2.authLost, isNull, reason: '舊請求的 401 不算帳號失效');
    expect(m2.ranchDeleted, isTrue);
  });
}
