// S08 配種（設計稿 boards/S08-配種）的畫面狀態。假資料照 design/m2/src/js/fixtures.js 的 COWS、FOUND 和 s08.js 的 OUTCOME：
// 公牛 #14 娟珊、#5 安格斯（上架中）、#8 荷斯坦（老、配過種）、#2 黃牛（在田裡）；母牛 #3、#7、#12、#11、#9（在田裡）、#15（小牛）。
// 娟珊 #14 × 荷斯坦 #3：荷斯坦 50%、娟珊 25%、蓬蓬荷斯坦 12.5%，還沒發現的棉花奶油（稀有）、亮黑（優良）各 6.25%；公牛 50%。
import 'dart:async';

import 'package:cowfarm/api/breeds.dart';
import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/breed/breed_page.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:cowfarm/ui/kit/note_line.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
import 'page_case.dart';
import 's03_cases.dart';

/// 設計稿發現過的品種（fixtures.js 的 FOUND）。
const designFound = [
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

/// 設計稿的牧場，加上圖鑑（FOUND）和小牛長大要幾小時（一般 1、優良 2、稀有 4、傳說 8）。
Map<String, dynamic> breedState({List<Map<String, dynamic>>? cows, int penSlots = 12, int? penUsed}) {
  final base = ranchState(cows: cows, penSlots: penSlots, penUsed: penUsed);
  return {
    ...base,
    'economy': {
      ...base['economy'] as Map<String, dynamic>,
      'calf_grow_h': [1, 2, 4, 8],
    },
    'codex': [
      for (final b in designFound) {'breed': b, 'found_at': t0 - 36000},
    ],
  };
}

/// 一個品種的公母兩列（協定 3.7 的 distribution）。
List<Map<String, dynamic>> _odds(String breed, double p) {
  final info = breedInfo(breed)!;
  return [
    for (final bull in [true, false])
      {'breed': breed, 'type': info.type.wire, 'traits': info.traits, 'tier': info.tier, 'bull': bull, 'p': p / 2},
  ];
}

/// 娟珊 #14 × 荷斯坦 #3 的預覽（s08.js 的 OUTCOME）。[blockers] 有東西就不能配。
Map<String, dynamic> designPreviewJson({List<Map<String, dynamic>> blockers = const []}) => {
  'tier_probs': [0.5, 0.4375, 0.0625, 0],
  'type_probs': {'dairy': 1.0},
  'bull_prob': 0.5,
  'can_breed': blockers.isEmpty,
  'blockers': blockers,
  'distribution': [
    ..._odds('holstein', 0.5),
    ..._odds('jersey', 0.25),
    ..._odds('fluffyHolstein', 0.125),
    ..._odds('cottonCream', 0.0625),
    ..._odds('glossBlack', 0.0625),
  ],
};

/// 新小牛：娟珊 #16（優良、母），剛出生 2.4 分鐘，再 1 小時 57.6 分長大（進度 2%，設計稿 S08-09）。
Map<String, dynamic> designCalf() => {
  ...designCow(16, 'jersey', stage: 'calf'),
  'born_at': t0 - 144,
  'age_h': 0.04,
  'adult_at': t0 + 7056,
};

/// 配好以後的牧場：娟珊 #14、荷斯坦 #3 配過種了，多了小牛 #16。
Map<String, dynamic> bredState() => breedState(
  cows: [
    for (final c in designCows())
      if (c['id'] == 3 || c['id'] == 14) {...c, 'bred': true, 'can_breed': false} else c,
    designCalf(),
  ],
);

/// 配種頁的假伺服器：機率可以一直等、可以失敗、可以說不能配；配種之後換成 [after] 的 state。
class BreedApi extends FakeGameApi {
  BreedApi({Map<String, dynamic>? state}) : super(state: state ?? breedState(), market: ranchMarket());

  bool pending = false;
  bool fail = false;
  List<Map<String, dynamic>> blockers = [];
  Map<String, dynamic>? after;

  @override
  Future<BreedPreview> breedPreview(Object sire, Object dam) async {
    calls.add('preview:$sire:$dam');
    if (pending) return Completer<BreedPreview>().future;
    if (fail) throw const ApiException(500, 'internal', 'boom');
    return BreedPreview.fromJson(designPreviewJson(blockers: blockers));
  }

  @override
  Future<BreedResult> breed(Object sire, Object dam) async {
    calls.add('breed:$sire:$dam');
    if (after != null) stateJson = after!;
    return BreedResult.fromJson({'calf': designCalf()});
  }
}

/// 打開配種頁（自己配種），[sire]、[dam] 是先選好的牛；等機率回來。
Future<GameModel> showBreed(
  WidgetTester tester,
  AppLang lang, {
  BreedApi? api,
  String? sire,
  String? dam,
  bool connected = true,
}) async {
  final m = await ranchModel(api: api ?? BreedApi(), connected: connected);
  if (sire != null) m.setBreedSire(sire);
  if (dam != null) m.setBreedDam(dam);
  m.selectTab(AppTab.breed);
  await pumpAppIn(tester, m, lang, prefs: swipeHintSeen);
  await tester.pump();
  await tester.pump();
  return m;
}

/// 配種頁的捲動（ListView 只蓋看得到附近的東西：要先捲過去，下面的卡片、按鈕才找得到）。
Finder get breedScrollable =>
    find.descendant(of: find.byKey(const Key('breed')), matching: find.byType(Scrollable)).first;

/// 把配種頁捲到 [target] 的上緣在內容區上緣往下 [gap]（設計稿的 scrollTo，例 S08-06 的機率卡）。
Future<void> scrollBreedTo(WidgetTester tester, Finder target, {double gap = 6}) async {
  await tester.scrollUntilVisible(target, 200, scrollable: breedScrollable);
  final position = tester.state<ScrollableState>(breedScrollable).position;
  final box = tester.renderObject<RenderBox>(target);
  final top = RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset - gap;
  position.jumpTo(top.clamp(position.minScrollExtent, position.maxScrollExtent));
  await tester.pump();
}

/// 按「配種（免費）」，等配好、捲到新小牛（S08-09）。
Future<void> tapBreed(WidgetTester tester) async {
  final go = find.byKey(const Key('breed-go'));
  await tester.scrollUntilVisible(go, 200, scrollable: breedScrollable);
  await tester.pump();
  await tester.tap(go);
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

final _zh = Strings.forLang(AppLang.zhHant);

AppButton _btn(WidgetTester tester) => tester.widget<AppButton>(find.byKey(const Key('breed-go')));

/// 選牛列裡卡片的順序（key 去掉前綴）。
List<String> pickKeys(WidgetTester tester, String prefix) => [
  for (final e in find.descendant(of: find.byKey(Key('$prefix-row')), matching: find.byType(PickCard)).evaluate())
    (e.widget.key! as ValueKey<String>).value.substring(prefix.length + 1),
];

/// 局部狀態表的機率卡（有結果）：模型給圖鑑、小牛長大的時間。
Future<GameModel> _sheetModel() => ranchModel(api: BreedApi());

final s08Cases = <PageCase>[
  PageCase(
    'S08-01',
    '一般：還沒選',
    (tester, lang) => showBreed(tester, lang),
    check: (tester) {
      expect(find.text(_zh.s08Rule), findsOneWidget);
      expect(find.text(_zh.pickBoth), findsOneWidget);
      expect(find.text(_zh.breedFree), findsOneWidget);
      // 能選的在前；不能選的照上架中、已配種、工作中、小牛排在後面（s08.js 的 BULLS、DAMS）
      expect(pickKeys(tester, 'sire'), ['14', '5', '8', '2']);
      expect(pickKeys(tester, 'dam'), ['3', '7', '12', '11', '9', '15']);
      expect(_btn(tester).onPressed, isNull);
      expect(_btn(tester).label, _zh.s08BreedBtnFree);
    },
  ),
  PageCase(
    'S08-02',
    '沒有成年公牛或母牛',
    (tester, lang) async {
      final s = Strings.forLang(lang);
      await pumpSheet(tester, lang, [
        PickSection(
          title: s.pickSire,
          side: 0,
          child: PickEmpty(title: s.noSire, hint: s.s08NoSireHint, side: 0),
        ),
        PickSection(
          title: s.pickDam,
          side: 0,
          child: PickEmpty(title: s.noDam, hint: s.s08NoDamHint, side: 0),
        ),
      ]);
    },
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.text(_zh.noSire), findsOneWidget);
      expect(find.text(_zh.s08NoSireHint), findsOneWidget);
      expect(find.text(_zh.noDam), findsOneWidget);
      expect(find.text(_zh.s08NoDamHint), findsOneWidget);
    },
  ),
  PageCase(
    'S08-03',
    '有牛不能選：變灰加原因',
    (tester, lang) => showBreed(tester, lang, sire: '14'),
    crop: find.byKey(const Key('sire-row')),
    check: (tester) {
      PickCard card(String key) => tester.widget<PickCard>(find.byKey(Key('sire-$key')));
      expect(card('14').on, isTrue);
      expect(card('5').off, PickOff.listed);
      expect(card('8').off, PickOff.bred);
      expect(card('2').off, PickOff.working);
      final row = find.byKey(const Key('sire-row'));
      expect(find.descendant(of: row, matching: find.text(_zh.badgeListed)), findsOneWidget);
      expect(find.descendant(of: row, matching: find.text(_zh.badgeBred)), findsOneWidget);
      expect(find.descendant(of: row, matching: find.text(_zh.badgeWorking)), findsOneWidget);
    },
  ),
  PageCase(
    'S08-04',
    '機率計算中',
    (tester, lang) async {
      await showBreed(tester, lang, api: BreedApi()..pending = true, sire: '14', dam: '3');
      await scrollBreedTo(tester, find.byKey(const Key('outcome')));
    },
    crop: find.byKey(const Key('outcome')),
    check: (tester) {
      expect(find.text(_zh.s08Calculating), findsOneWidget);
      expect(find.byType(Spinner), findsOneWidget);
    },
  ),
  PageCase(
    'S08-05',
    '機率計算失敗（3 秒後自動再試）',
    (tester, lang) async {
      await showBreed(tester, lang, api: BreedApi()..fail = true, sire: '14', dam: '3');
      await scrollBreedTo(tester, find.byKey(const Key('outcome')));
    },
    crop: find.byKey(const Key('outcome')),
    check: (tester) {
      expect(find.textContaining(_zh.s08ProbFailedRetry(n: 3), findRichText: true), findsOneWidget);
    },
  ),
  PageCase(
    'S08-06',
    '可能生出的小牛與機率（沒發現過的顯示「？」）',
    (tester, lang) async {
      await showBreed(tester, lang, sire: '14', dam: '3');
      await scrollBreedTo(tester, find.byKey(const Key('outcome')));
    },
    check: (tester) {
      for (final b in ['holstein', 'jersey', 'fluffyHolstein', 'cottonCream', 'glossBlack']) {
        expect(find.byKey(Key('oc-$b')), findsOneWidget);
      }
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(find.text('12.5%'), findsOneWidget);
      expect(find.text('6.25%'), findsNWidgets(2));
      expect(find.text(_zh.gUnknownBreed), findsNWidgets(2));
      expect(find.text(_zh.s08NotFound), findsNWidgets(2));
      expect(find.text(_zh.bullProbLine(v: '50%'), findRichText: true), findsOneWidget);
      expect(find.text(_zh.s08GrowRange(v: _zh.s08HoursRange(a: 1, b: 4)), findRichText: true), findsOneWidget);
      expect(_btn(tester).onPressed, isNotNull);
    },
  ),
  PageCase(
    'S08-07',
    '伺服器說不能配：原因、按鈕停用',
    (tester, lang) async {
      final m = await _sheetModel();
      final s = Strings.forLang(lang);
      final p = BreedPreview.fromJson(
        designPreviewJson(
          blockers: [
            {'code': 'already_bred', 'cow_id': 3},
          ],
        ),
      );
      final cows = [m.state!.cowById('14')!, m.state!.cowById('3')!];
      await pumpSheet(tester, lang, model: m, [
        OutcomeCard(state: OutcomeState.ok, preview: p),
        for (final n in breedNotes(s, m, preview: p, pair: cows)) NoteLine(icon: 'warn', text: n, kind: NoteKind.warn),
        AppButton(s.s08BreedBtnFree, kind: ButtonKind.pink, block: true, icon: 'heart'),
      ]);
      // 窄手機放不下整塊：畫面拉高，截圖才拍得到下面的按鈕
      await growToFit(tester, find.byType(SingleChildScrollView));
    },
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.text(_zh.s08AlreadyBred(cow: _zh.cowName('holstein', 3))), findsOneWidget);
    },
  ),
  PageCase(
    'S08-08',
    '牛舍滿了',
    (tester, lang) async {
      final m = await ranchModel(api: BreedApi(state: breedState(penSlots: 10)));
      final s = Strings.forLang(lang);
      await pumpSheet(tester, lang, model: m, [
        for (final n in breedNotes(s, m, preview: null, pair: const []))
          NoteLine(icon: 'warn', text: n, kind: NoteKind.warn),
        AppButton(s.s08BreedBtnFree, kind: ButtonKind.pink, block: true, icon: 'heart'),
      ]);
    },
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.text(_zh.s08PenFull), findsOneWidget);
    },
  ),
  PageCase(
    'S08-09',
    '配種成功：小牛倒數',
    (tester, lang) async {
      await showBreed(tester, lang, api: BreedApi()..after = bredState(), sire: '14', dam: '3');
      await tapBreed(tester);
    },
    check: (tester) {
      final calf = _zh.cowName('jersey', 16);
      expect(find.text(_zh.breedDone(cow: calf)), findsOneWidget);
      expect(find.text(_zh.gNewCalf(cow: calf)), findsOneWidget);
      expect(find.text(_zh.growUp(v: _zh.duration(h: 1, m: 58)), findRichText: true), findsOneWidget);
      expect(_btn(tester).label, _zh.s08BredBtn);
      expect(_btn(tester).onPressed, isNull);
      // 剛配好的那一對照樣顯示成選好的、留在原來的位置
      expect(tester.widget<PickCard>(find.byKey(const Key('dam-3'))).on, isTrue);
      expect(pickKeys(tester, 'dam').first, '3');
    },
  ),
  PageCase(
    'S08-11',
    '斷線：機率卡顯示「連線中…」',
    (tester, lang) async {
      await showBreed(tester, lang, sire: '14', dam: '3', connected: false);
      // 「連線中…」膠囊在內容區最上面（高 34）：機率卡捲到它下面，截圖才不會蓋到
      await scrollBreedTo(tester, find.byKey(const Key('outcome')), gap: 50);
    },
    crop: find.byKey(const Key('outcome')),
    check: (tester) {
      expect(
        find.descendant(of: find.byKey(const Key('outcome')), matching: find.text(_zh.connecting)),
        findsOneWidget,
      );
    },
  ),
];
