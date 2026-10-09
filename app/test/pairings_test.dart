// 圖鑑的配種表（v0.3 第 13.2 節；#176）：代表配法（GET /v1/codex/pairings）照順序列出，state.pairings 裡配出過的亮起來，
// 表上沒有的加在最後面；爸爸、媽媽分開算。代表配法是固定資料，拿一次就記著；拿不到先不放配種表，下次打開再拿；
// 舊的伺服器沒有這個端點（404）就不放、也不再問。畫面在 test/pages（S09-03、S09-08）。
import 'package:cowfarm/api/breeds.dart';
import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/kit/cow_art.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:cowfarm/ui/records/pair_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'pages/page_case.dart';
import 'pages/s03_cases.dart';
import 'pages/s09_cases.dart';

final _zh = Strings.forLang(AppLang.zhHant);
final _table = find.byKey(const Key('pair-table'));

/// 打開紀錄分頁（圖鑑），[pairings] 是 state.pairings；[setup] 在打開以前改假伺服器（例：拿代表配法會失敗）。
Future<(GameModel, FakeGameApi)> _records(
  WidgetTester tester, {
  List<Map<String, dynamic>> pairings = const [],
  void Function(FakeGameApi api)? setup,
  Screen screen = Screen.w430,
  AppLang lang = AppLang.zhHant,
}) async {
  screen.apply(tester);
  final api = FakeGameApi();
  setup?.call(api);
  final m = await ranchModel(api: api, state: {...codexState(), 'pairings': pairings});
  m.selectTab(AppTab.records);
  await pumpAppIn(tester, m, lang);
  await tester.pump();
  return (m, api);
}

Future<void> _open(WidgetTester tester, GameModel m, String breed) async {
  m.closeCodex();
  m.openCodex(breed);
  await tester.pump();
  await tester.pump();
}

int _fetches(FakeGameApi api) => api.calls.where((c) => c == 'codexPairings').length;

String _rowText(WidgetTester tester, int i) => [
  for (final t in tester.widgetList<Text>(
    find.descendant(of: find.byKey(Key('pair-row-$i')), matching: find.byType(Text)),
  ))
    t.data ?? t.textSpan?.toPlainText(),
].join(' ');

void main() {
  setUpAll(loadAppAssets);

  test('pairRows：代表配法照順序；只算生出這個品種的；爸爸媽媽反過來是另一列；表上沒有的照先後加在最後', () {
    const table = [
      (sire: 'jersey', dam: 'jersey'),
      (sire: 'holstein', dam: 'jersey'),
      (sire: 'jersey', dam: 'holstein'),
    ];
    const done = [
      PairingRecord(sire: 'holstein', dam: 'holstein', child: 'holstein', count: 5),
      PairingRecord(sire: 'jersey', dam: 'holstein', child: 'jersey'),
      PairingRecord(sire: 'hybrid', dam: 'jersey', child: 'jersey'),
      PairingRecord(sire: 'glossBlack', dam: 'jersey', child: 'jersey', count: 2),
    ];
    expect(pairRows('jersey', table, done), [
      (sire: 'jersey', dam: 'jersey', count: 0, extra: false),
      // 反過來的「荷斯坦♂ × 娟珊♀」沒配過，不會跟著亮
      (sire: 'holstein', dam: 'jersey', count: 0, extra: false),
      (sire: 'jersey', dam: 'holstein', count: 1, extra: false),
      (sire: 'hybrid', dam: 'jersey', count: 1, extra: true),
      (sire: 'glossBlack', dam: 'jersey', count: 2, extra: true),
    ]);
    expect(pairRows('angus', const [(sire: 'angus', dam: 'angus')], done), [
      (sire: 'angus', dam: 'angus', count: 0, extra: false),
    ], reason: '生出別的品種的不算');
  });

  test('state.pairings、GET /v1/codex/pairings 的解析：少了品種的那一筆不要；舊的伺服器沒有 pairings 是空的', () {
    final st = GameState.fromJson({
      ...codexState(),
      'pairings': [
        {'sire': 'jersey', 'dam': 'holstein', 'child': 'jersey', 'count': 3, 'found_at': t0},
        {'sire': 'jersey', 'child': 'jersey', 'count': 1},
      ],
    });
    expect(st.pairings, hasLength(1));
    expect((st.pairings.single.sire, st.pairings.single.dam, st.pairings.single.count), ('jersey', 'holstein', 3));
    expect(GameState.fromJson(codexState()).pairings, isEmpty);
    final table = codexPairingsFromJson({
      'pairings': {
        'jersey': [
          {'sire': 'jersey', 'dam': 'jersey'},
          {'sire': 'jersey'},
        ],
      },
    });
    expect(table, {
      'jersey': [(sire: 'jersey', dam: 'jersey')],
    });
  });

  testWidgets('代表配法拿一次就記著：打開紀錄分頁先拿，點進品種詳細、換別的品種都不再拿', (tester) async {
    final (m, api) = await _records(tester);
    expect(_fetches(api), 1, reason: '打開紀錄分頁就先拿');
    await _open(tester, m, 'jersey');
    expect(_table, findsOneWidget);
    expect(find.text(_zh.s09PairUnlocked(n: 0, total: 4)), findsOneWidget);
    await _open(tester, m, 'holstein');
    expect(find.text(_zh.s09PairUnlocked(n: 0, total: 1)), findsOneWidget, reason: '假伺服器的荷斯坦只有 1 組');
    expect(_fetches(api), 1);
  });

  testWidgets('拿不到代表配法（連不上）：先不放配種表；下次打開品種詳細再拿，拿到就放', (tester) async {
    final (m, api) = await _records(tester, setup: (api) => api.pairingsError = const NetworkException('offline'));
    await _open(tester, m, 'jersey');
    expect(_table, findsNothing);
    expect(find.byKey(const Key('codex-first')), findsOneWidget, reason: '品種詳細其他的照樣顯示');
    api.pairingsError = null;
    await _open(tester, m, 'jersey');
    expect(_table, findsOneWidget);
    expect(_fetches(api), 3);
  });

  testWidgets('舊的伺服器沒有這個端點（404）：不放配種表，也不再問', (tester) async {
    final (m, api) = await _records(
      tester,
      setup: (api) => api.pairingsError = const ApiException(404, 'not_found', 'not found'),
    );
    await _open(tester, m, 'jersey');
    expect(_table, findsNothing);
    await _open(tester, m, 'holstein');
    expect(_fetches(api), 1);
  });

  testWidgets('長大揭曉以後 state 更新：配出來的那一列亮起來，解鎖數跟著變', (tester) async {
    final (m, api) = await _records(tester);
    await _open(tester, m, 'jersey');
    expect(_rowText(tester, 0), '× ♂ ${_zh.gUnknownBreed} ♀ ${_zh.gUnknownBreed} ${_zh.s09PairNone}');
    api.stateJson = {
      ...api.stateJson,
      'pairings': [
        {'sire': 'jersey', 'dam': 'jersey', 'child': 'jersey', 'count': 1, 'found_at': t0},
      ],
    };
    await m.refreshState();
    await tester.pump();
    final jersey = _zh.breedName('jersey');
    expect(_rowText(tester, 0), '× ♂ $jersey ♀ $jersey ${_zh.s09PairCount(n: 1)}');
    expect(find.text(_zh.s09PairUnlocked(n: 1, total: 4)), findsOneWidget);
  });

  testWidgets('爸爸是公牛、媽媽是母牛的圖；雜種牛當爸媽畫乳牛體型的雜種牛、寫「雜種牛」（表上沒有的配法）', (tester) async {
    final (m, _) = await _records(
      tester,
      pairings: [
        ...designJerseyPairings,
        {'sire': kHybrid, 'dam': 'jersey', 'child': 'jersey', 'count': 1, 'found_at': t0},
      ],
    );
    await _open(tester, m, 'jersey');
    List<CowPicture> pics(int i) => tester
        .widgetList<CowPicture>(find.descendant(of: find.byKey(Key('pair-row-$i')), matching: find.byType(CowPicture)))
        .toList();
    expect([for (final p in pics(0)) (p.breed, p.bull)], [('jersey', true), ('jersey', false)]);
    // 還沒配出過：深色影子（爸爸是公牛的影子）
    final sil = tester
        .widgetList<CowSilhouette>(
          find.descendant(of: find.byKey(const Key('pair-row-1')), matching: find.byType(CowSilhouette)),
        )
        .toList();
    expect([for (final p in sil) (p.breed, p.bull, p.dark)], [('holstein', true, true), ('jersey', false, true)]);
    expect([for (final p in pics(5)) (p.breed, p.bull)], [('mixDairy', true), ('jersey', false)]);
    expect(
      _rowText(tester, 5),
      '× ♂ ${_zh.breedName(kHybrid)} ♀ ${_zh.breedName('jersey')} '
      '${_zh.s09PairCount(n: 1)}${_zh.gSep}${_zh.s09PairExtra}',
    );
    expect(find.text(_zh.s09PairUnlocked(n: 4, total: 6)), findsOneWidget);
  });

  testWidgets('放不下的品種名換行、不截短：320 寬英文的「Glossy Black Dairy」兩行，♂ 在兩行的中間（設計稿 raw/en/S09-03__320）', (tester) async {
    final (m, _) = await _records(tester, pairings: designJerseyPairings, screen: Screen.w320, lang: AppLang.en);
    await _open(tester, m, 'jersey');
    // 整頁拉長（矮手機的最後一列還沒捲到就還沒排）
    await growToFit(tester, find.byKey(const Key('codex-detail')));
    final en = Strings.forLang(AppLang.en);
    final name = find.text(en.breedName('glossBlack'));
    expect(name, findsOneWidget);
    expect(tester.getSize(name).height, 38, reason: '兩行，行高 19');
    // ♂ 那一行（CssLine，19 高）的中間對齊兩行字的中間
    final sex = find.ancestor(
      of: find.descendant(of: find.byKey(const Key('pair-row-4')), matching: find.text('♂')),
      matching: find.byType(CssLine),
    );
    expect(tester.getCenter(sex).dy, closeTo(tester.getCenter(name).dy, 0.5));
  });
}
