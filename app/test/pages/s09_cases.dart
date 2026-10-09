// S09 圖鑑（設計稿 boards/S09-圖鑑）的畫面狀態。假資料照 design/m2/src/js/fixtures.js 的 FOUND：已發現 10 種
// （荷斯坦、蓬蓬荷斯坦、娟珊、巧克力牛、草莓牛、台灣黃牛、高地牛、台灣水牛、安格斯、和牛）。
// 設計稿的「現在」是 2026-10-02 12:00（手機時區），每一種都是兩天前（9 月 30 日）第一次發現；
// 牧場裡的娟珊只留 #7 一頭（設計稿 S09-03「目前有 1 頭」）。S09-05（24 種全圖）不是 app 畫面（pages_test 的 notAppPageIds）。
import 'package:cowfarm/api/breeds.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/kit/cow_bits.dart';
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
      'calf_grow_h': [3, 3, 3, 3], // v0.3：所有小牛長大的時間一樣（#151、協定 2.3）
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
  Map<String, dynamic>? state,
}) async {
  final m = await ranchModel(state: state ?? codexState(found: found));
  m.selectTab(AppTab.records);
  if (breed != null) m.openCodex(breed);
  await pumpAppIn(tester, m, lang);
  await tester.pump();
  if (tall) await growToFit(tester, find.byKey(const Key('codex')));
  return m;
}

final _zh = Strings.forLang(AppLang.zhHant);

/// S09-06 的牧場：圖鑑多一筆雜種牛（10 月 3 日），牧場裡有一頭雜種牛。
Map<String, dynamic> _hybridCodexState() {
  final st = codexState();
  return {
    ...st,
    'cows': [
      ...(st['cows'] as List),
      {...designCow(20, 'holstein', milk: 14, kg: 206, value: 1466), 'breed': 'hybrid', 'tier': 2, 'hybrid': true},
    ],
    'codex': [
      ...(st['codex'] as List),
      {'breed': kHybrid, 'found_at': t0 + 86400},
    ],
  };
}

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
      // 14 種沒發現，加上最下面「其他」的雜種牛那一格（還沒長出過，#157）
      expect(find.text(_zh.gUnknownBreed), findsNWidgets(15));
      expect(find.text(_zh.breedName('jersey')), findsOneWidget);
      expect(find.text(_zh.s09Other), findsOneWidget);
      expect(find.text(_zh.s09OtherHint(n: 24)), findsOneWidget);
      expect(find.byKey(const Key('codex-hybrid')), findsOneWidget);
    },
  ),
  PageCase(
    'S09-02',
    '全部發現',
    // 設計稿：雜種牛那一格也是發現了的樣子（不算在 24 種裡）
    (tester, lang) => showCodex(tester, lang, found: [...kCodexOrder, kHybrid]).then((_) {}),
    check: (tester) {
      expect(find.text('24 / 24'), findsOneWidget, reason: '雜種牛不算在 24 種裡');
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
      expect(find.text(_zh.s09CalfGrow), findsNothing, reason: '「小牛長大」那一格 v0.3 拿掉了（#151）');
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
  PageCase(
    'S09-06',
    '雜種牛的詳細（已發現）',
    // 設計稿：10 月 3 日第一次長出雜種牛、牧場裡有 1 頭（雜種牛 #20）
    (tester, lang) => showCodex(tester, lang, breed: kHybrid, state: _hybridCodexState()).then((_) {}),
    check: (tester) {
      expect(find.text(_zh.breedName(kHybrid)), findsOneWidget);
      expect(find.byType(MixStarChip), findsOneWidget);
      expect(find.text(_zh.badgeMix), findsOneWidget);
      expect(find.text(_zh.byKey('breed.mix.intro')), findsOneWidget);
      // 產奶照舊（14），耕田、賣價乘 0.6（11 × 0.6 = 6.6）
      expect(find.text('6.6 ${_zh.gPerHourRice}'), findsOneWidget);
      expect(find.text('×0.6'), findsOneWidget);
      expect(find.text(_zh.s09MixHowTitle), findsOneWidget);
      // 第一次發現的日期、牧場裡現在有幾頭雜種牛
      expect(find.text(_zh.s09FirstFound(date: _zh.dateMdOnly(m: 10, d: 3), n: 1)), findsOneWidget);
    },
  ),
  PageCase(
    'S09-07',
    '雜種牛的詳細（還沒發現）',
    (tester, lang) => showCodex(tester, lang, breed: kHybrid).then((_) {}),
    check: (tester) {
      expect(find.text(_zh.gUnknownBreed), findsOneWidget);
      expect(find.text(_zh.s09NotFoundYet), findsOneWidget);
      expect(find.text(_zh.s09UnknownTitle), findsOneWidget);
      expect(find.text(_zh.s09MixHow), findsOneWidget);
      expect(find.byKey(const Key('codex-first')), findsNothing);
    },
  ),
];
