// 清大便（v0.3 第 5 節；協定 2.6 的 POST /v1/clean）：點一下清一坨（A-14）、從大便上開始劃，劃過的都清掉（A-15）。
// 現在是兩個動畫的減少動態版：清到的大便直接消失，右上角的數字直接變少；先從畫面拿掉，再送出，失敗的話放回去。
// 右上角的大便數、場景裡的大便的畫面在 test/pages（S03-26、S03-27）。
import 'dart:async';

import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'pages/page_case.dart';
import 'pages/s03_cases.dart';

Finder _poop(int spot) => find.byKey(Key('poop-$spot'));

/// 設計稿的牧場，旁邊一共 [n] 坨大便（照牛的編號一頭一坨，排在第 0–(n − 1) 個位置）。
Future<(GameModel, FakeGameApi)> _showPoop(WidgetTester tester, int n, {bool connected = true}) async {
  Screen.w390.apply(tester);
  final api = FakeGameApi(
    state: ranchState(cows: poopCows(n)),
    market: ranchMarket(),
  );
  final m = await ranchModel(api: api, connected: connected);
  await pumpAppIn(tester, m, AppLang.zhHant, prefs: swipeHintSeen);
  return (m, api);
}

void main() {
  setUpAll(loadAppAssets);
  final zh = Strings.forLang(AppLang.zhHant);

  testWidgets('點一下清一坨（A-14 的減少動態版）：伺服器還沒回就不見了，數字少 1；回來以後換上伺服器的 state', (tester) async {
    final (m, api) = await _showPoop(tester, 4);
    final gate = api.cleanGate = Completer<void>();
    final spot1 = tester.getRect(_poop(1));
    await tester.tap(_poop(2));
    await tester.pump();
    expect(_poop(2), findsNothing, reason: '先從畫面拿掉');
    expect(dirtText(tester), '${zh.s03Poop} 3');
    expect(api.calls.last, 'clean:5x1', reason: '第 2 個位置是 #5 旁邊的（照牛的編號：#2、#3、#5、#7）');
    expect(tester.getRect(_poop(1)), spot1, reason: '其他的不跳位');
    expect(_poop(0), findsOneWidget);
    expect(_poop(3), findsOneWidget);
    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(m.state!.poop.total, 3, reason: '換上回應的 state');
    expect(_poop(2), findsNothing);
    expect(dirtText(tester), '${zh.s03Poop} 3');
    // 清光了：右上角的數字不見（有大便才出現）
    for (final i in [0, 1, 3]) {
      await tester.tap(_poop(i));
      await tester.pump();
      await tester.pump();
    }
    expect(find.byKey(const Key('dirt-pill')), findsNothing);
  });

  testWidgets('從大便上開始劃（A-15 的減少動態版）：劃過的 3 坨都不見，手指放開才一次送出；場景不動', (tester) async {
    final (m, api) = await _showPoop(tester, 9);
    final cow = ranchGame(tester).cowRect(3);
    // 第 3 個位置 → 第 8 個位置，中間經過第 4 個位置
    final from = tester.getCenter(_poop(3)), to = tester.getCenter(_poop(8));
    final g = await tester.startGesture(from);
    await g.moveBy(const Offset(20, 0));
    await tester.pump();
    await g.moveTo(to);
    await tester.pump();
    for (final i in [3, 4, 8]) {
      expect(_poop(i), findsNothing, reason: '第 $i 個位置劃過了');
    }
    expect(dirtText(tester), '${zh.s03Poop} 6');
    expect(api.calls.where((c) => c.startsWith('clean')), isEmpty, reason: '手指還沒放開');
    await g.up();
    await tester.pump();
    await tester.pump();
    final cleans = api.calls.where((c) => c.startsWith('clean')).toList();
    expect(cleans, hasLength(1));
    expect(cleans.single.split(':').last.split(',').toSet(), {'7x1', '8x1', '14x1'});
    expect(m.state!.poop.total, 6);
    expect(ranchGame(tester).cowRect(3), cow, reason: '劃過去清大便，場景沒有被拖動');
  });

  testWidgets('從草地上開始劃：照樣是拖動場景，大便不會被清掉', (tester) async {
    final (_, api) = await _showPoop(tester, 9);
    final cow = ranchGame(tester).cowRect(3)!;
    await tester.dragFrom(const Offset(300, 525), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(ranchGame(tester).cowRect(3)!.left, lessThan(cow.left), reason: '場景往右捲了');
    expect(api.calls.where((c) => c.startsWith('clean')), isEmpty);
    expect(dirtText(tester), '${zh.s03Poop} 9');
  });

  testWidgets('送出失敗（連不上）：大便放回去、數字變回來，跳一般的錯誤提示', (tester) async {
    final (_, api) = await _showPoop(tester, 4);
    api.cleanError = const NetworkException('offline');
    await tester.tap(_poop(1));
    await tester.pump();
    await tester.pump();
    expect(_poop(1), findsOneWidget, reason: '放回原來的位置');
    expect(dirtText(tester), '${zh.s03Poop} 4');
    expect(find.byKey(const Key('toast')), findsOneWidget);
  });

  testWidgets('斷線的時候點大便：不清（跟停用的按鈕一樣）', (tester) async {
    final (_, api) = await _showPoop(tester, 4, connected: false);
    await tester.tap(_poop(0));
    await tester.pump();
    expect(_poop(0), findsOneWidget);
    expect(api.calls.where((c) => c.startsWith('clean')), isEmpty);
  });

  testWidgets('大便比位置多（12 坨）：先畫 9 坨，右上角照樣寫 12；清掉一坨，下一坨補進空出來的位置', (tester) async {
    final (_, api) = await _showPoop(tester, 12);
    for (var i = 0; i < 9; i++) {
      expect(_poop(i), findsOneWidget);
    }
    expect(dirtText(tester), '${zh.s03Poop} 12');
    // #2、#3 各 2 坨（第 0–3 個位置），#5 到 #11 各 1 坨（第 4–8 個），#12、#14、#15 的還沒畫
    await tester.tap(_poop(4));
    await tester.pump();
    await tester.pump();
    expect(api.calls.last, 'clean:5x1');
    expect(dirtText(tester), '${zh.s03Poop} 11');
    expect(_poop(4), findsOneWidget, reason: '還沒畫的那坨補進第 4 個位置');
  });
}
