// 開場畫面在英文、泰文、窄手機的版面規則（ceo 2026-10-02，#58 審查後）：
// - S01 遊戲名一行放不下就縮小，繁中不變；
// - S01 的版本號一律在框的下面，不被「重試」蓋到；
// - S02 鍵盤開著時，輸入框和整顆「就叫這個」都在鍵盤上面（m3-backlog）。
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/storage/token_store.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cowfarm/api/game_api.dart';

import 'fakes.dart';
import 'pages/page_case.dart';

final _zh = Strings.forLang(AppLang.zhHant);

GameModel _fresh({FakeGameApi? api}) => GameModel(
  api: api ?? FakeGameApi(),
  push: FakePush(),
  tokens: MemoryTokenStore(),
  now: FakeClock().call,
  uiTick: null,
);

void main() {
  setUpAll(loadAppAssets);

  // 錯誤提示的圖示照 S16-03（actionErrorKind）：連不上是警告，伺服器錯誤是錯誤
  for (final (error, kind) in [
    (const NetworkException('timeout') as Exception, ToastKind.warn),
    (const ApiException(500, 'internal', 'boom') as Exception, ToastKind.err),
  ]) {
    testWidgets('S02 開牧場失敗的提示：${kind.name}（$error）', (tester) async {
      Screen.w430.apply(tester);
      final api = FakeGameApi()..sessionError = error;
      await pumpAppIn(tester, _fresh(api: api)..needsRanch = true, AppLang.zhHant);
      await tester.enterText(find.byKey(const Key('ranch-name')), '小花牧場');
      await tester.pump();
      await tester.tap(find.byKey(const Key('confirm-name')));
      await tester.pump();
      await tester.pump();
      expect(tester.widget<ToastPill>(find.byKey(const Key('toast'))).kind, kind);
    });
  }

  // iPhone（加到主畫面開）回報「一點輸入框就跳掉」：鍵盤一開，S02 換成鍵盤的版面，名字卡（連同輸入框）被拆掉重做，
  // 焦點掉了、鍵盤收起來，版面又換回去，只能用「幫我想一個」。名字卡要在鍵盤開關時保持同一個（ceo 2026-10-03）
  testWidgets('S02：沒有鍵盤時點輸入框，鍵盤打開、版面換掉以後焦點還在，打得進字', (tester) async {
    Screen.w430.apply(tester);
    await pumpAppIn(tester, _fresh()..needsRanch = true, AppLang.zhHant);
    final input = find.byKey(const Key('ranch-name'));
    EditableText editable() =>
        tester.widget<EditableText>(find.descendant(of: input, matching: find.byType(EditableText)));
    await tester.tap(input);
    await tester.pump();
    expect(editable().focusNode.hasFocus, isTrue);
    expect(find.text(_zh.s02SameName), findsOneWidget, reason: '還沒有鍵盤：同名的說明還在');

    tester.view.viewInsets = FakeViewPadding(bottom: 336 * tester.view.devicePixelRatio);
    await tester.pump();
    await tester.pump();
    expect(find.text(_zh.s02SameName), findsNothing, reason: '換成鍵盤的版面（牛和說明收起來）');
    expect(editable().focusNode.hasFocus, isTrue, reason: '輸入框沒有被拆掉重做，焦點還在');
    expect(tester.testTextInput.hasAnyClients, isTrue, reason: '鍵盤還接著');
    tester.testTextInput.enterText('晨光牧場');
    await tester.pump();
    expect(editable().controller.text, '晨光牧場');
  });

  for (final lang in AppLang.values) {
    for (final screen in Screen.values) {
      testWidgets('S01 遊戲名一行放得下（${lang.code} ${screen.label}）', (tester) async {
        screen.apply(tester);
        await pumpAppIn(tester, _fresh(), lang);
        final title = find.byKey(const Key('game-title'));
        final rect = tester.getRect(title);
        expect(rect.width, lessThanOrEqualTo(screen.width + 0.5));
        expect(rect.height, lessThanOrEqualTo(56 + 5 + 1), reason: '一行（行高 56，影子往下 5）');
        if (lang == AppLang.zhHant) {
          expect(rect.width, closeTo(tester.getSize(title).width, 0.5), reason: '繁中放得下，不縮小');
        }
      });

      testWidgets('S01-04 版本號在卡片下面，不被蓋到（${lang.code} ${screen.label}）', (tester) async {
        screen.apply(tester);
        await pumpAppIn(tester, _fresh()..startError = const NetworkActionError(), lang);
        final card = tester.getRect(find.ancestor(of: find.byKey(const Key('retry')), matching: find.byType(AppCard)));
        final version = find.byKey(const Key('app-version'));
        // 卡片的陰影往下 4
        expect(tester.getRect(version).top, greaterThanOrEqualTo(card.bottom + 4));
        // 放不下時整頁可以捲：捲到底看得到版本號
        await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -400));
        await tester.pump();
        expect(tester.getRect(version).bottom, lessThanOrEqualTo(screen.height));
      });
    }

    testWidgets('S02 鍵盤開著（320×568、鍵盤 260）：輸入框和整顆「就叫這個」都在鍵盤上面（${lang.code}）', (tester) async {
      Screen.w320.apply(tester);
      const keyboard = 260.0;
      final dpr = tester.view.devicePixelRatio;
      tester.view
        ..viewInsets = const FakeViewPadding(bottom: keyboard * 3)
        ..padding = FakeViewPadding(top: Screen.w320.safeTop * dpr);
      await pumpAppIn(tester, _fresh()..needsRanch = true, lang);
      const keyboardTop = 568 - keyboard;

      Future<void> expectReachable(String name) async {
        await tester.enterText(find.byKey(const Key('ranch-name')), name);
        await tester.pump();
        await tester.pump(); // 捲動在畫完那一格之後
        final input = tester.getRect(find.byKey(const Key('ranch-name')));
        final confirm = tester.getRect(find.byKey(const Key('confirm-name')));
        expect(confirm.bottom + 4, lessThanOrEqualTo(keyboardTop + 0.5), reason: '$name：整顆按鈕（含陰影）在鍵盤上面');
        expect(input.top, greaterThanOrEqualTo(Screen.w320.safeTop), reason: '$name：輸入框沒有捲到狀態列底下');
        expect(input.bottom, lessThanOrEqualTo(keyboardTop), reason: name);
      }

      await expectReachable('小花的快樂');
      // 名字太長：提示換成錯誤說明（英文、泰文變兩行），按鈕還是要整顆看得到
      await expectReachable('晨光河畔牧場的小木屋');
    });
  }
}
