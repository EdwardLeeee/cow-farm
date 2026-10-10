// S01 啟動與載入、S02 自己取名的畫面狀態（design/m2/scope.md 第 4 節；設計稿 boards/S01-啟動與載入、S02-自己取名）。
import 'dart:math';

import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/storage/token_store.dart';
import 'package:cowfarm/theme/app_theme.dart';
import 'package:cowfarm/theme/tokens.dart';
import 'package:cowfarm/ui/kit/frame.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:cowfarm/ui/start/namer.dart';
import 'package:cowfarm/ui/start/start_flow.dart';
import 'package:cowfarm/util/ranch_name.dart';
import 'package:cowfarm/version.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../fakes.dart';
import 'page_case.dart';

/// 還沒有牧場的手機（沒有 token），時鐘固定。
GameModel _fresh({FakeGameApi? api}) => GameModel(
  api: api ?? FakeGameApi(),
  push: FakePush(),
  tokens: MemoryTokenStore(),
  now: FakeClock().call,
  uiTick: null,
);

final _zh = Strings.forLang(AppLang.zhHant);

/// 依序回傳固定數字的亂數（「幫我想一個」三組詞的編號）。
class _FixedRandom implements Random {
  _FixedRandom(this._values);
  final List<int> _values;
  var _i = 0;

  @override
  int nextInt(int max) => _values[_i++ % _values.length] % max;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

/// 系統鍵盤的高度（設計稿 s02.js 的 KB_H）。
const _keyboardHeight = {430: 300.0, 390: 292.0, 360: 280.0, 320: 254.0};

/// S02-05 的四個例子：太短、太長、表情符號、不能用的字（私用區 U+F8FF；iPhone 會顯示成 Apple 標誌，其他是方塊）。
const nameErrorSamples = ['A', '晨光河畔牧場的小木屋', '小花牧場🐮', '小花牧場'];

AppButton _button(WidgetTester tester, String key) => tester.widget<AppButton>(find.byKey(Key(key)));

final startCases = <PageCase>[
  PageCase(
    'S01-01',
    '啟動畫面',
    (tester, lang) => pumpAppIn(tester, _fresh(), lang),
    check: (tester) {
      expect(find.text(_zh.appTitle), findsWidgets);
      expect(find.text(_zh.s01Version(v: appVersion)), findsOneWidget);
      expect(find.byType(Spinner), findsNothing);
    },
  ),
  PageCase(
    'S01-02',
    '載入中',
    (tester, lang) => pumpAppIn(tester, _fresh()..starting = true, lang),
    check: (tester) {
      expect(find.text(_zh.loadingFarm), findsOneWidget);
      expect(find.byType(Spinner), findsOneWidget);
    },
  ),
  PageCase(
    'S01-03',
    '第一次打開：建立牧場中',
    (tester, lang) => pumpAppIn(
      tester,
      _fresh()
        ..needsRanch = true
        ..creating = true,
      lang,
    ),
    check: (tester) {
      expect(find.text(_zh.s01Creating), findsOneWidget);
      expect(find.text(_zh.s01FirstTime), findsOneWidget);
    },
  ),
  PageCase(
    'S01-04',
    '載入失敗',
    (tester, lang) => pumpAppIn(tester, _fresh()..startError = const NetworkActionError(), lang),
    check: (tester) {
      expect(find.text(_zh.s01FailTitle), findsOneWidget);
      // 每 5 秒自動重試：跟 GameModel 的定時校正一樣
      expect(find.text('${_zh.s01FailCheck}\n${_zh.s01FailAuto(n: 5)}'), findsOneWidget);
      expect(_button(tester, 'retry').onPressed, isNotNull);
    },
  ),
  PageCase(
    'S02-01',
    '還沒輸入',
    (tester, lang) => pumpAppIn(tester, _fresh()..needsRanch = true, lang),
    check: (tester) {
      expect(find.text(_zh.s02Title), findsOneWidget);
      expect(find.text(_zh.s02WidthRule), findsOneWidget);
      expect(find.text('0 / 16'), findsOneWidget);
      expect(_button(tester, 'confirm-name').onPressed, isNull, reason: '還沒輸入：就叫這個停用');
    },
  ),
  PageCase(
    'S02-02',
    '取好名字：歡迎卡與開局的牛',
    (tester, lang) async {
      final m = _fresh(api: FakeGameApi(state: newRanchStateJson()))..needsRanch = true;
      await pumpAppIn(tester, m, lang);
      await tester.enterText(find.byKey(const Key('ranch-name')), '小花的快樂牧場');
      await tester.pump();
      await tester.tap(find.byKey(const Key('confirm-name')));
      await tester.pump();
      await tester.pump();
    },
    check: (tester) {
      // 名字後面加 #編號（player_id 補零到 4 位）；牛、金幣、奶桶都照伺服器的 state
      expect(find.text(_zh.s02Welcome(name: '小花的快樂牧場 #0031')), findsOneWidget);
      expect(find.text(_zh.cowName('holstein', 1)), findsOneWidget);
      expect(find.text(_zh.calfName(CowType.dual, 2)), findsOneWidget, reason: '開局送的小牛也還不知道品種（#151）');
      expect(find.text('${_zh.cow}${_zh.gSep}${_zh.s02GiftMilk}'), findsOneWidget);
      expect(find.text('${_zh.bull}${_zh.gSep}${_zh.gGrowsIn(time: _zh.minutes(m: 20))}'), findsOneWidget);
      expect(find.text(_zh.s02Boost(h: 1, x: '5')), findsOneWidget);
      expect(find.byKey(const Key('enter-ranch')), findsOneWidget);
    },
  ),
  PageCase(
    'S02-03',
    '打字中（系統鍵盤開著）',
    (tester, lang) async {
      final dpr = tester.view.devicePixelRatio;
      final width = (tester.view.physicalSize.width / dpr).round();
      // 鍵盤蓋住 Home 指示條：下面的安全區變 0，鍵盤高度放在 viewInsets（跟 iPhone 回報的一樣）
      tester.view
        ..viewInsets = FakeViewPadding(bottom: _keyboardHeight[width]! * dpr)
        ..padding = FakeViewPadding(top: tester.view.padding.top);
      await pumpAppIn(tester, _fresh()..needsRanch = true, lang);
      await tester.enterText(find.byKey(const Key('ranch-name')), '小花的快樂');
      await tester.pump();
      await tester.pump(); // 鍵盤開著時，捲到整顆「就叫這個」看得到（畫完那一格之後才捲）
    },
    check: (tester) {
      expect(find.text(_zh.s02Sub), findsNothing, reason: '鍵盤開著：標題縮小、牛和說明收起來');
      expect(find.text(_zh.s02SameName), findsNothing);
      expect(find.text('10 / 16'), findsOneWidget);
      expect(_button(tester, 'confirm-name').onPressed, isNotNull);
    },
  ),
  PageCase(
    'S02-04',
    '按了「幫我想一個」：從詞庫填一個，可以再改',
    (tester, lang) async {
      StartFlow.debugRandom = _FixedRandom([0, 1, 0]); // 晨光、河畔、牧場
      addTearDown(() => StartFlow.debugRandom = null);
      await pumpAppIn(tester, _fresh()..needsRanch = true, lang);
      await tester.tap(find.byKey(const Key('suggest')));
      await tester.pump();
    },
    check: (tester) {
      expect(tester.widget<TextField>(find.byKey(const Key('ranch-name'))).controller!.text, '晨光河畔牧場');
      expect(find.text(_zh.s02Filled), findsOneWidget);
      expect(find.text('12 / 16'), findsOneWidget);
    },
  ),
  PageCase(
    'S02-05',
    '名字不能用的提示：太短、太長、表情符號、不能用的字',
    (tester, lang) async {
      final s = Strings.forLang(lang);
      await tester.pumpWidget(
        Provider<Strings>.value(
          value: s,
          child: MaterialApp(
            theme: appTheme(),
            locale: lang.locale,
            supportedLocales: [for (final l in AppLang.values) l.locale],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(
              backgroundColor: AppColors.cream,
              body: Stack(
                children: [
                  Positioned.fill(
                    child: PageBackground(safeTop: tester.view.padding.top / tester.view.devicePixelRatio),
                  ),
                  SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 4 + 8, 12, 16 + 8),
                      child: Column(
                        key: const Key('name-errs'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (i, v) in nameErrorSamples.indexed) ...[
                            if (i > 0) const SizedBox(height: 10),
                            NameCard(
                              field: Text(
                                v,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.clip,
                                style: nameInputStyle(),
                              ),
                              width: nameWidth(v),
                              error: nameProblemText(s, checkRanchName(v).problem!),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    },
    crop: find.byKey(const Key('name-errs')),
    check: (tester) {
      for (final t in [_zh.s02ErrShort, _zh.s02ErrLong, _zh.s02ErrEmoji, _zh.s02ErrChar]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text('20 / 16'), findsOneWidget);
    },
  ),
];
