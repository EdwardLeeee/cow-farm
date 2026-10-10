// 清大便（v0.3 第 5 節；協定 2.6 的 POST /v1/clean）：點一下清一坨（A-14）、從大便上開始劃，劃過的都清掉（A-15）。
// 這裡沒開動畫，是兩個動畫的減少動態版：清到的大便直接消失，右上角的數字直接變少；先從畫面拿掉，再送出，失敗的話放回去。
// 開著動畫的 A-14 在 poop_anim_test。
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

  testWidgets('同一格畫面裡手指經過同一坨兩次（畫面還沒重畫）：只算一次，旁邊那坨不會跟著不見', (tester) async {
    // 12 坨：#3 有 2 坨（第 2、3 個位置）
    final (_, api) = await _showPoop(tester, 12);
    final g = await tester.startGesture(tester.getCenter(_poop(3)));
    await g.moveBy(const Offset(20, 0));
    await g.moveBy(const Offset(2, 0)); // 中間沒有重畫：場景裡第 3 個位置的大便還在
    await g.up();
    await tester.pump();
    await tester.pump();
    expect(api.calls.where((c) => c.startsWith('clean')).toList(), ['clean:3x1']);
    expect(dirtText(tester), '${zh.s03Poop} 11');
    expect(_poop(2), findsOneWidget, reason: '#3 的另一坨沒有被劃到（空出來的第 3 個位置補上還沒畫的那坨）');
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

  testWidgets('第 10 坨以後（12 坨）：放到右半邊，cow-ui 排的位置（往右滑才看得到）', (tester) async {
    await _showPoop(tester, 12);
    for (var i = 0; i < 12; i++) {
      expect(_poop(i), findsOneWidget, reason: '第 $i 個位置');
    }
    expect(_poop(12), findsNothing);
    expect(dirtText(tester), '${zh.s03Poop} 12');
    // 跟左半邊一樣的算法：底部中間對準場景座標（390 寬、還沒往右滑：螢幕 x = 場景 x，在畫面右邊外面）
    for (final (i, spot) in [(9, const Offset(544, 398)), (10, const Offset(700, 360)), (11, const Offset(430, 404))]) {
      final r = tester.getRect(_poop(i)), l = tester.getRect(_poop(0));
      expect(r.width, closeTo(l.width, 0.001));
      expect(r.center.dx - l.center.dx, closeTo(spot.dx - 236, 0.01), reason: '第 $i 個');
      expect(r.bottom - l.bottom, closeTo(spot.dy - 398, 0.01), reason: '第 $i 個');
    }
  });

  testWidgets('大便比位置多（20 坨）：最多畫 18 坨，右上角照樣寫 20；清掉一坨，還沒畫的補進空出來的位置', (tester) async {
    final (_, api) = await _showPoop(tester, 20);
    for (var i = 0; i < 18; i++) {
      expect(_poop(i), findsOneWidget, reason: '第 $i 個位置');
    }
    expect(find.byKey(const Key('poop-18')), findsNothing);
    expect(dirtText(tester), '${zh.s03Poop} 20');
    // 每頭牛 2 坨，照編號排：#2 是第 0、1 個位置，#3 是第 2、3 個，#5 是第 4、5 個……#14 是第 16、17 個，#15 的 2 坨還沒畫
    await tester.tap(_poop(4));
    await tester.pump();
    await tester.pump();
    expect(api.calls.last, 'clean:5x1');
    expect(dirtText(tester), '${zh.s03Poop} 19');
    expect(_poop(4), findsOneWidget, reason: '還沒畫的那坨補進第 4 個位置');
  });
}
