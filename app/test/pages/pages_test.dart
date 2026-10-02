// 每個頁面 ID 的畫面狀態（page_case.dart 的 pageCases）：
// - 430 繁中：擺出來、跑那個狀態自己的檢查；
// - 360、320（最小的兩種手機）× 繁中、英文、泰文：不能溢出（溢出在測試裡會丟例外）。用 app 內建的字型量，泰文照實際斷行。
// 另外檢查 design/m2/scope.md 的每個頁面 ID：不是有畫面狀態，就是還在待做清單。
import 'dart:io';

import 'package:cowfarm/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

import 'page_case.dart';

/// 還沒做的頁面 ID（第 4–6 步）。做好一個就加進 pageCases、從這裡拿掉：做好的還留在清單裡，測試會失敗。
/// 這份清單只會越來越短；要加回來，PR 裡要寫原因。
const pendingPageIds = {
  'G-05',
  'G-14',
  'S03-22',
  'S03-23',
  'S03-24',
  'S06-17',
  'S11-03',
  'S11-05',
  'S12-01',
  'S12-02',
  'S12-03',
  'S12-04',
  'S12-05',
  'S12-06',
  'S12-07',
  'S12-08',
  'S13-02',
  'S13-07',
  'S13-08',
  'S13-09',
  'S13-10',
  'S13-11',
  'S13-12',
  'S13-13',
  'S13-14',
  'S13-15',
  'S13-16',
  'S13-19',
  'S13-20',
  'S14-01',
  'S14-02',
  'S14-03',
  'S14-04',
  'S14-05',
  'S14-06',
  'S14-07',
  'S14-08',
  'S15-02',
  'S15-03',
  'S15-04',
  'S16-01',
  'S16-02',
  'S16-03',
  'S16-04',
  'S16-05',
  'A-01',
  'A-02',
  'A-03',
  'A-04',
  'A-05',
  'A-06',
  'A-07',
  'A-08',
  'A-09',
  'A-10',
  'A-11',
  'A-12',
};

/// scope.md 裡不是 app 畫面的頁面 ID：沒有畫面狀態，也不會做（ceo 2026-10-03）。
const notAppPageIds = {
  // 1320 寬的 24 種全圖，給使用者核准外型用；牛的外型已由 cow_assets_test 的雜湊防漂移
  'S09-05',
};

/// scope.md 表格裡的頁面 ID（每列第一欄）。
Set<String> scopePageIds() {
  final md = File('../design/m2/scope.md').readAsStringSync();
  return {for (final m in RegExp(r'^\| (S\d{2}-\d{2}|G-\d{2}|A-\d{2}) ', multiLine: true).allMatches(md)) m[1]!};
}

void main() {
  setUpAll(loadAppAssets);

  group('頁面 ID（design/m2/scope.md）', () {
    test('每個頁面 ID 不是有畫面狀態，就是在待做清單（或不是 app 畫面）；做好的要從清單拿掉', () {
      final scope = scopePageIds();
      expect(scope, hasLength(199), reason: 'scope.md 改了頁面 ID：待做清單和 pageCases 要跟著改');
      final done = {for (final c in pageCases) c.id};
      expect(pageCases, hasLength(done.length), reason: '同一個頁面 ID 只能有一個狀態');
      expect(done.intersection(pendingPageIds), isEmpty, reason: '做好的頁面 ID 要從待做清單拿掉');
      expect(done.difference(scope), isEmpty, reason: 'scope.md 沒有這些頁面 ID');
      expect(pendingPageIds.difference(scope), isEmpty, reason: '待做清單裡有 scope.md 沒有的頁面 ID');
      expect(done.intersection(notAppPageIds), isEmpty, reason: '不是 app 畫面的頁面 ID 不會有畫面狀態');
      expect(notAppPageIds.difference(scope), isEmpty, reason: '不是 app 畫面的清單裡有 scope.md 沒有的頁面 ID');
      expect(
        scope.difference(done).difference(pendingPageIds).difference(notAppPageIds),
        isEmpty,
        reason: '沒有畫面狀態、也不在待做清單',
      );
    });

    test('手機尺寸和安全區跟設計稿 kit.js 的 DEVICES 一樣', () {
      final js = File('../design/m2/src/js/kit.js').readAsStringSync();
      for (final s in Screen.values) {
        final m = RegExp('${s.label}: \\{ w: (\\d+), h: (\\d+), top: (\\d+), bottom: (\\d+)').firstMatch(js);
        expect(m, isNotNull, reason: 'kit.js 找不到 ${s.label}');
        expect([for (var i = 1; i <= 4; i++) double.parse(m![i]!)], [s.width, s.height, s.safeTop, s.safeBottom]);
      }
    });
  });

  for (final c in pageCases) {
    testWidgets('${c.id} ${c.name}：430 繁中', (tester) async {
      Screen.w430.apply(tester);
      await c.show(tester, AppLang.zhHant);
      c.check?.call(tester);
      expect(tester.takeException(), isNull);
    });
    for (final lang in AppLang.values) {
      for (final screen in [Screen.w360, Screen.w320]) {
        testWidgets('${c.id} ${c.name}：${screen.label} ${lang.code} 不溢出', (tester) async {
          screen.apply(tester);
          await c.show(tester, lang);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
