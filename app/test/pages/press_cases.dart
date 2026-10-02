// 按下的樣子（G-11～G-13）的對照截圖：只拍截圖、不算頁面 ID（scope.md 還沒有 G-11～G-13）。
// 每種元件排「平常、按下、減少動態時按下」，按下用好幾根手指同時按住。
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/theme/tokens.dart';
import 'package:cowfarm/ui/kit/frame.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'page_case.dart';
import 's03_cases.dart';

/// 一列：說明（設計稿的橘色註解）加三個樣子。[make] 依 key 做出一個元件。
Widget _row(String caption, Widget Function(String key) make, String id) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      caption,
      style: AppText.style(12, weight: FontWeight.w900, color: const Color(0xFFC2541B)),
    ),
    const SizedBox(height: 6),
    Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        make('n-$id'),
        make('p-$id'),
        // 減少動態時按下
        Builder(
          builder: (context) =>
              MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: make('r-$id')),
        ),
      ],
    ),
  ],
);

final pressShotCases = <PageCase>[
  PageCase('press', '按下：平常、按下、減少動態時按下', (tester, lang) async {
    // 拉長畫面，整張表放得下（不用捲）
    tester.view.physicalSize = Size(tester.view.physicalSize.width, 1500 * tester.view.devicePixelRatio);
    final s = Strings.forLang(lang);
    final m = await ranchModel();
    await pumpSheet(tester, lang, [
      for (final (i, k) in [
        ButtonKind.normal,
        ButtonKind.primary,
        ButtonKind.blue,
        ButtonKind.green,
        ButtonKind.pink,
        ButtonKind.danger,
      ].indexed)
        _row('大按鈕 ${k.name}', (key) => AppButton(s.collect, key: Key(key), kind: k, onPressed: () {}), 'big$i'),
      _row('小按鈕', (key) => AppButton(s.retry, key: Key(key), small: true, icon: 'refresh', onPressed: () {}), 'small'),
      _row('停用（按了不變）', (key) => AppButton(s.collect, key: Key(key)), 'off'),
      _row(
        '整排寬',
        (key) => SizedBox(
          width: 300,
          child: AppButton(s.s03GoShop, key: Key(key), kind: ButtonKind.primary, block: true, onPressed: () {}),
        ),
        'block',
      ),
      _row(
        '分頁列',
        (key) => SizedBox(
          width: 360,
          height: 62,
          child: KeyedSubtree(
            key: Key(key),
            child: const AppTabBar(active: AppTab.ranch, bottomPadding: 0),
          ),
        ),
        'tab',
      ),
    ], model: m);
    // 按住「按下」和「減少動態」那兩欄（分頁列按第二個分頁）
    final targets = <Finder>[
      // 停用的不按：它沒有點擊判定，按下去會被捲動那邊接走，連帶取消其他按住的手指（停用的按了本來就不會變）
      for (final id in ['big0', 'big1', 'big2', 'big3', 'big4', 'big5', 'small', 'block']) ...[
        find.byKey(Key('p-$id')),
        find.byKey(Key('r-$id')),
      ],
      find.descendant(of: find.byKey(const Key('p-tab')), matching: find.byKey(const Key('tab-market'))),
      find.descendant(of: find.byKey(const Key('r-tab')), matching: find.byKey(const Key('tab-market'))),
    ];
    // 一根一根按：同時落下太多根手指時，捲動那邊的判定會讓點擊等不到；每根按住後等過點擊判定（100 毫秒）
    for (final (i, f) in targets.indexed) {
      await tester.startGesture(tester.getCenter(f), pointer: 100 + i);
      await tester.pump(const Duration(milliseconds: 150));
    }
  }, crop: find.byKey(const Key('sheet'))),
];
