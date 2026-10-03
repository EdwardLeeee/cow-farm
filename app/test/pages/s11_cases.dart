// S11 升級慶祝與提示的頁面狀態（設計稿 s10.js 的 S11）。
// S11-03 新手引導卡：卡片本身照局部表；什麼時候出、放哪裡、右上角的 × 在 coach_test。
// S11-05（備份提醒，「現在備份」要開 S13）等備份牧場（#127）合併，還在待做清單。
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/ui/kit/frame.dart';
import 'package:cowfarm/ui/ranch/coach_card.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'page_case.dart';
import 's03_cases.dart';

final _zh = Strings.forLang(AppLang.zhHant);

final s11Cases = [
  PageCase(
    'S11-01',
    '場主升級慶祝',
    (tester, lang) async {
      // 剛升到 Lv5：累積收入 7,500（這一級的門檻），經驗條是空的
      final m = await ranchModel(
        state: ranchState(level: 5, levelProgress: {'earned': 7500, 'level_at': 7500, 'next_at': 15500}),
      );
      m.levelUp = (level: 5, levelAt: 7500);
      await pumpAppIn(tester, m, lang, prefs: swipeHintSeen);
      await tester.pump();
    },
    check: (tester) {
      expect(find.byKey(const Key('level-card')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('level-up-lv'))).data, '5');
      expect(find.text(_zh.s11Earned(v: '7,500')), findsOneWidget);
      expect(find.text(_zh.s11Ribbon), findsOneWidget);
      expect(find.byKey(const Key('level-up-ok')), findsOneWidget);
    },
  ),
  PageCase(
    'S11-03',
    '新手引導提示（第 15 分鐘、第 20 分鐘）',
    (tester, lang) => pumpSheet(tester, lang, [
      CoachCard(kind: CoachKind.pen, penPrice: 280, onGo: () {}),
      CoachCard(kind: CoachKind.bull, onGo: () {}),
    ]),
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.text(_zh.s11CoachPenTitle), findsOneWidget);
      expect(find.text(_zh.s11CoachPenBody(price: '280')), findsOneWidget);
      expect(find.text(_zh.s11CoachBullTitle), findsOneWidget);
      expect(find.text(_zh.s11CoachPenGo), findsOneWidget);
      expect(find.text(_zh.s11CoachBullGo), findsOneWidget);
    },
  ),
  PageCase(
    'S11-04',
    '頂列經驗條：快升級、剛升級',
    (tester, lang) => pumpSheet(tester, lang, [
      hudRow(const HudData(name: '晨光河畔牧場', level: 4, xp: 0.96, coins: 12480)),
      hudRow(const HudData(name: '晨光河畔牧場', level: 5, xp: 0, coins: 12480)),
    ]),
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.text(_zh.level(lv: 4)), findsOneWidget);
      expect(find.text(_zh.level(lv: 5)), findsOneWidget);
    },
  ),
];
