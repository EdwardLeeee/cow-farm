// S09 圖鑑（設計稿 boards/S09-圖鑑）的畫面狀態。假資料照 design/m2/src/js/fixtures.js 的 FOUND：已發現 10 種
// （荷斯坦、蓬蓬荷斯坦、娟珊、巧克力牛、草莓牛、台灣黃牛、高地牛、台灣水牛、安格斯、和牛）。
// 設計稿的「現在」是 2026-10-02 12:00（手機時區），每一種都是兩天前（9 月 30 日）第一次發現；
// 牧場裡的娟珊只留 #7 一頭（設計稿 S09-03「目前有 1 頭」）。S09-05（24 種全圖）不是 app 畫面（pages_test 的 notAppPageIds）。
import 'package:cowfarm/api/breeds.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
import 'page_case.dart';
import 's03_cases.dart';

/// 設計稿的「現在」：2026-10-02 12:00（手機時區）。
final _designNow = DateTime(2026, 10, 2, 12);

/// 設計稿已發現的 10 種（fixtures.js 的 FOUND）。
const designCodexFound = [
  'holstein',
  'fluffyHolstein',
  'jersey',
  'chocolate',
  'strawberry',
  'yellow',
  'highland',
  'buffalo',
  'angus',
  'wagyu',
];

/// 圖鑑頁的牧場：[found] 是已發現的品種（都是兩天前、9 月 30 日發現的）；economy 有品種詳細要的數字。
Map<String, dynamic> codexState({List<String> found = designCodexFound}) {
  final base = ranchState(
    cows: [
      for (final c in designCows())
        if (c['id'] != 14) c,
    ],
  );
  return {
    ...base,
    'real_time': _designNow.millisecondsSinceEpoch / 1000,
    'economy': {
      ...base['economy'] as Map<String, dynamic>,
      'dairy_milk_per_h': 14.0,
      'calf_grow_h': [1, 2, 4, 8],
      'peak_weight_kg': {'dairy': 250.0, 'dual': 450.0, 'beef': 800.0},
    },
    'codex': [
      for (final b in found) {'breed': b, 'found_at': t0 - 2 * 86400},
    ],
  };
}

/// 打開紀錄分頁的圖鑑；[breed] 給了就打開那個品種的詳細。[tall] 是長頁（整頁一張）。
Future<GameModel> showCodex(
  WidgetTester tester,
  AppLang lang, {
  List<String> found = designCodexFound,
  String? breed,
  bool tall = false,
}) async {
  final m = await ranchModel(state: codexState(found: found));
  m.selectTab(AppTab.records);
  if (breed != null) m.openCodex(breed);
  await pumpAppIn(tester, m, lang);
  await tester.pump();
  if (tall) await growToFit(tester, find.byKey(const Key('codex')));
  return m;
}

final _zh = Strings.forLang(AppLang.zhHant);

final s09Cases = [
  PageCase(
    'S09-01',
    '列表：24 格（長頁）',
    (tester, lang) => showCodex(tester, lang, tall: true).then((_) {}),
    check: (tester) {
      expect(find.text('10 / 24'), findsOneWidget);
      expect(find.text(_zh.s09Hint), findsOneWidget);
      for (final b in kCodexOrder) {
        expect(find.byKey(Key('codex-$b')), findsOneWidget, reason: b);
      }
      expect(find.text(_zh.gUnknownBreed), findsNWidgets(14));
      expect(find.text(_zh.breedName('jersey')), findsOneWidget);
    },
  ),
  PageCase(
    'S09-02',
    '全部發現',
    (tester, lang) => showCodex(tester, lang, found: kCodexOrder).then((_) {}),
    check: (tester) {
      expect(find.text('24 / 24'), findsOneWidget);
      expect(find.text(_zh.s09AllFound(n: 24)), findsOneWidget);
    },
  ),
  PageCase(
    'S09-03',
    '品種詳細（已發現）',
    (tester, lang) => showCodex(tester, lang, breed: 'jersey').then((_) {}),
    check: (tester) {
      expect(find.text(_zh.breedName('jersey')), findsOneWidget);
      expect(find.text('No.03'), findsOneWidget);
      expect(find.text(_zh.breedIntro('jersey')), findsOneWidget);
      expect(find.text('14 ${_zh.gPerHourMilk}'), findsOneWidget);
      expect(find.text('250 ${_zh.gKg}'), findsOneWidget);
      expect(find.text('×1.3'), findsOneWidget);
      expect(find.text('2 ${_zh.gHourUnit}'), findsOneWidget);
      expect(
        find.text(_zh.s09HowTraits(use: _zh.s09HowDairy, traits: _zh.traitName('B'))),
        findsOneWidget,
        reason: '娟珊是淡色（B）',
      );
      expect(find.text(_zh.s09FirstFound(date: _zh.dateMdOnly(m: 9, d: 30), n: 1)), findsOneWidget);
    },
  ),
  PageCase(
    'S09-04',
    '品種詳細（還沒發現）',
    (tester, lang) => showCodex(tester, lang, breed: 'goldenEar').then((_) {}),
    check: (tester) {
      expect(find.text(_zh.gUnknownBreed), findsOneWidget);
      expect(find.text('No.16'), findsOneWidget);
      expect(find.text(_zh.s09NotFoundYet), findsOneWidget);
      expect(find.text(_zh.s09UnknownTitle), findsOneWidget);
      expect(
        find.text(_zh.s09UnknownBody(use: _zh.useName(breedInfo('goldenEar')!.type), tier: _zh.tierName(3))),
        findsOneWidget,
      );
    },
  ),
];
