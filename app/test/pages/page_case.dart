// 頁面 ID（design/m2/scope.md 的 Sxx-yy、G-yy、A-yy）的畫面狀態：每個狀態怎麼擺出來、擺好後檢查什麼。
// pages_test.dart 用它跑 430 繁中的檢查、360 和 320 三種語言的溢出；shots_test.dart 用它拍 430、390 的截圖。
import 'dart:ui' as ui;

import 'package:cowfarm/app.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/state/settings.dart';
import 'package:cowfarm/theme/tokens.dart';
import 'package:cowfarm/ui/kit/cow_art.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 's01_s02_cases.dart';
import 's03_cases.dart';
import 's04_cases.dart';
import 's05_cases.dart';
import 's06_cases.dart';
import 's08_cases.dart';
import 's18_cases.dart';
import 's19_cases.dart';

/// 手機的尺寸與安全區，跟設計稿 design/m2/src/js/kit.js 的 DEVICES 一樣（pages_test 會比對）。
enum Screen {
  w430(430, 932, 59, 34),
  w390(390, 844, 47, 34),
  w360(360, 800, 28, 24),
  w320(320, 568, 20, 0);

  const Screen(this.width, this.height, this.safeTop, this.safeBottom);
  final double width;
  final double height;
  final double safeTop;
  final double safeBottom;

  String get label => '${width.toInt()}';

  /// 把測試的畫面設成這支手機（每點 [dpr] 個像素），測試結束自動還原。
  void apply(WidgetTester tester, {double dpr = 3}) {
    final pad = FakeViewPadding(top: safeTop * dpr, bottom: safeBottom * dpr);
    tester.view
      ..physicalSize = Size(width * dpr, height * dpr)
      ..devicePixelRatio = dpr
      ..padding = pad
      ..viewPadding = pad;
    addTearDown(tester.view.reset);
  }
}

/// 一個頁面 ID 的狀態。
class PageCase {
  PageCase(this.id, this.name, this.show, {this.check, this.crop});

  /// 頁面 ID，例 S03-02。
  final String id;

  /// 狀態名（照 scope.md，給人看）。
  final String name;

  /// 擺出這個狀態：建假資料、用 [lang] 放進 app（[pumpAppIn]）、點到這個畫面。畫面尺寸由呼叫的人先設好。
  final Future<void> Function(WidgetTester tester, AppLang lang) show;

  /// 擺好後的檢查（只在 430 繁中跑一次）。
  final void Function(WidgetTester tester)? check;

  /// 局部狀態：截圖只拍這一塊（設計稿的局部狀態表也只畫這一塊）。
  final Finder? crop;
}

/// 全部的頁面狀態。第 4 步每做好一組畫面，就把它的狀態加進來，並從 pages_test.dart 的待做清單拿掉。
final List<PageCase> pageCases = [
  ...startCases,
  ...s03Cases,
  ...s04Cases,
  ...s05Cases,
  ...s06Cases,
  ...s07Cases,
  ...s08Cases,
  ...s18Cases,
  ...s19Cases,
  ...s20Cases,
];

/// 載入 app 內建的字型和牛的圖的量測（cows.json）。測試環境預設不載字型，字會畫成方塊，量不準寬度，也看不出泰文怎麼斷行。
Future<void> loadAppAssets() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await (FontLoader(AppText.family)..addFont(rootBundle.load('assets/fonts/NotoSansTC-VF.ttf'))).load();
  await (FontLoader(AppText.fallback.first)..addFont(rootBundle.load('assets/fonts/NotoSansThai-VF.ttf'))).load();
  await CowArt.load();
}

/// 手機語言是 [lang] 的設定（第一次打開跟著手機語言）；[prefs] 是先存好的偏好（例：面板收起來了）。
SettingsController settingsFor(AppLang lang, [Map<String, String> prefs = const {}]) =>
    SettingsController(MemoryPrefsStore({...prefs}), deviceLocales: () => [lang.locale]);

/// 牧場的滑動提示已經看過（S03-14 以外的牧場狀態都是這樣）。
const swipeHintSeen = {SettingsController.swipeHintKey: '1'};

/// 把 app 放進目前設好的畫面，用 [lang] 的語言。
Future<void> pumpAppIn(WidgetTester tester, GameModel m, AppLang lang, {Map<String, String> prefs = const {}}) async {
  final settings = settingsFor(lang, prefs);
  await settings.load();
  await tester.pumpWidget(CowFarmApp(model: m, settings: settings));
  await tester.pump();
}

/// 長頁（設計稿的 tall，例 S03-07 牛舍清單）：把畫面拉高到 [scrollable] 不用捲就放得下，整頁一張拍下來。
/// 頂列在最上面、分頁列在最下面，跟設計稿的長頁一樣。
/// ListView 還沒排到的子項，捲動長度只是估計：先一直捲到底，直到長度不再變，才是真的長度。
Future<void> growToFit(WidgetTester tester, Finder scrollable) async {
  ScrollPosition position() =>
      tester.state<ScrollableState>(find.descendant(of: scrollable, matching: find.byType(Scrollable)).first).position;
  var extent = -1.0;
  for (var i = 0; i < 10 && position().maxScrollExtent != extent; i++) {
    extent = position().maxScrollExtent;
    position().jumpTo(extent);
    await tester.pump();
  }
  position().jumpTo(0);
  await tester.pump();
  if (extent <= 0) return;
  final view = tester.view;
  view.physicalSize = Size(view.physicalSize.width, view.physicalSize.height + extent * view.devicePixelRatio);
  await tester.pump();
}

/// 等圖片（牛的 SVG、圖示）真的載進來：讀檔是真的非同步，要離開測試的假時鐘等一下再重畫。
Future<void> settleImages(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
}

/// 拍下整個畫面（實際像素），有 [crop] 就只留那一塊。回傳 PNG。
Future<List<int>> capturePng(WidgetTester tester, {Finder? crop}) async {
  final root = find.byType(WidgetsApp).evaluate().first;
  final dpr = tester.view.devicePixelRatio;
  final rect = crop == null ? null : tester.getRect(crop.first);
  final bytes = await tester.runAsync(() async {
    var image = await captureImage(root);
    if (rect != null) {
      final src = Rect.fromLTRB(rect.left * dpr, rect.top * dpr, rect.right * dpr, rect.bottom * dpr);
      final rec = ui.PictureRecorder();
      ui.Canvas(rec).drawImageRect(image, src, Offset.zero & src.size, ui.Paint());
      image = await rec.endRecording().toImage(src.width.round(), src.height.round());
    }
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  return bytes!;
}
