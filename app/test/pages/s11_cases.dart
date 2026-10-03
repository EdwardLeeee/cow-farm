// S11 升級慶祝與提示的頁面狀態（設計稿 s10.js 的 S11）。
// S11-03 新手引導卡：卡片本身照局部表；什麼時候出、放哪裡、右上角的 × 在 coach_test。
// S11-05 備份提醒：什麼時候出、兩顆按鈕在 backup_remind_test。
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/settings.dart';
import 'package:cowfarm/ui/kit/frame.dart';
import 'package:cowfarm/ui/ranch/coach_card.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
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
    // 設計稿的 .coach-sheet：上面多留 30、右邊多留 12，放得下卡片右上角的 ×（卡片的寬度不變）。
    // 設計稿第一張用虛線畫出 × 點得到的範圍（說明用），app 不畫
    (tester, lang) => pumpSheet(tester, lang, [
      Padding(padding: const EdgeInsets.fromLTRB(0, 30, 12, 0), child: _coachWithClose(CoachKind.pen)),
      Padding(padding: const EdgeInsets.only(right: 12), child: _coachWithClose(CoachKind.bull)),
    ], padding: const EdgeInsets.fromLTRB(12, 4 + 8, 0, 16 + 8)),
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.text(_zh.s11CoachPenTitle), findsOneWidget);
      expect(find.text(_zh.s11CoachPenBody(price: '280')), findsOneWidget);
      expect(find.text(_zh.s11CoachBullTitle), findsOneWidget);
      expect(find.text(_zh.s11CoachPenGo), findsOneWidget);
      expect(find.text(_zh.s11CoachBullGo), findsOneWidget);
      expect(find.byType(CoachClose), findsNWidgets(2));
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
  PageCase(
    'S11-05',
    '升到 Lv2 之後：提醒備份牧場（只出現一次）',
    (tester, lang) async {
      // 剛升到 Lv2（累積收入 620：門檻 500、下一級 1,500，經驗 12%）、660 幣；荷斯坦和長大的小公牛、牛舍 2／3、
      // 奶桶 9.8／28（每小時 14）、倉庫 150（牛奶 18、稻米 22）。能登入的建置、還沒備份，齒輪上有小點（G-10）。
      // 慶祝卡（S11-01）按「好」以後跳出提醒
      final m = await ranchModel(
        state: ranchState(
          cows: [designCow(1, 'holstein', milk: 14), designCow(2, 'yellow', bull: true, kg: 431)],
          bucket: 9.8,
          bucketCap: 28,
          perHour: 14,
          milkLots: [
            {'qty': 18, 'tier': 0, 'freshness': 1.0},
          ],
          warehouseCap: 150,
          coins: 660,
          level: 2,
          levelProgress: {'earned': 620, 'level_at': 500, 'next_at': 1500},
          penSlots: 3,
          beef: 0,
          rice: 22,
        ),
        signIn: FakeSignIn(),
      );
      m.levelUp = (level: 2, levelAt: 500);
      await pumpAppIn(tester, m, lang, prefs: swipeHintSeen);
      await tester.tap(find.byKey(const Key('level-up-ok')));
      await tester.pump();
    },
    check: (tester) {
      expect(find.byKey(const Key('backup-remind')), findsOneWidget);
      expect(find.text(_zh.s11BackupTitle), findsOneWidget);
      expect(find.text(_zh.s11BackupBody), findsOneWidget);
      expect(find.text(_zh.s11Later), findsOneWidget);
      expect(find.text(_zh.s11BackupNow), findsOneWidget);
      expect(find.byKey(const Key('gear-dot')), findsOneWidget, reason: '還沒備份、也沒打開過備份頁（G-10）');
    },
  ),
  PageCase(
    'S11-06',
    '新手引導卡在牧場頁',
    (tester, lang) async {
      // 開局第 15 分鐘的牧場：Lv 1（累積收入 320，經驗 64%）、412 幣、荷斯坦和還沒長大的小公牛、牛舍 2／2、
      // 奶桶 6.2／28（每小時 14）、倉庫 150（牛奶 9）。第一次擴建剛開放（280 幣），擴建卡在跑馬燈下面
      final st = ranchState(
        cows: [
          designCow(1, 'holstein', milk: 14),
          {...designCow(2, 'yellow', bull: true, stage: 'calf'), 'origin': 'start'},
        ],
        bucket: 6.2,
        bucketCap: 28,
        perHour: 14,
        milkLots: [
          {'qty': 9, 'tier': 0, 'freshness': 1.0},
        ],
        warehouseCap: 150,
        coins: 412,
        level: 1,
        levelProgress: {'earned': 320, 'level_at': 0, 'next_at': 500},
        penSlots: 2,
        beef: 0,
        rice: 0,
      );
      final upgrades = (st['upgrades'] as Map).cast<String, dynamic>();
      final m = await ranchModel(
        state: {
          ...st,
          'pen': {...(st['pen'] as Map), 'next_cost': 280, 'next_open_at': t0 - 60},
          'upgrades': {
            ...upgrades,
            'pen': {...(upgrades['pen'] as Map), 'level': 0, 'cost': 280, 'next_open_at': t0 - 60},
          },
        },
      );
      // 測試的偏好預設兩張引導卡都看過：這裡清掉
      await pumpAppIn(tester, m, lang, prefs: {...swipeHintSeen, SettingsController.coachSeenKey: ''});
      await tester.pump();
    },
    check: (tester) {
      expect(find.byKey(const Key('coach-pen')), findsOneWidget);
      expect(find.byType(CoachClose), findsOneWidget);
      expect(find.text(_zh.s11CoachPenBody(price: '280')), findsOneWidget);
    },
  ),
];

/// 引導卡和右上角的 ×（牧場頁上是分開放的兩個元件，這裡照同樣的位置疊在一起）。
Widget _coachWithClose(CoachKind kind) => Stack(
  clipBehavior: Clip.none,
  children: [
    CoachCard(kind: kind, penPrice: kind == CoachKind.pen ? 280 : null, onGo: () {}),
    Positioned(
      right: -CoachClose.outRight,
      top: -CoachClose.outTop,
      child: CoachClose(onTap: () {}),
    ),
  ],
);
