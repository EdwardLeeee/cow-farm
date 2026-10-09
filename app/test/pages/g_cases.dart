// G 共用元件的頁面狀態（設計稿 g.js）：操作結果的提示（G-04）、處理中（G-06）、小牛長大倒數卡（G-08）、下拉重新整理（G-09）。
// G-01～G-03、G-07、G-10 在 s03_cases.dart；G-05（伺服器通知）設計稿沒畫在哪裡，還在待做清單。
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/l10n/format.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/theme/tokens.dart';
import 'package:cowfarm/ui/breed/breed_page.dart';
import 'package:cowfarm/ui/kit/cow_art.dart';
import 'package:cowfarm/ui/kit/cow_bits.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:cowfarm/ui/kit/meter.dart';
import 'package:cowfarm/ui/kit/pull_refresh.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
import 'page_case.dart';
import 's03_cases.dart';

final _zh = Strings.forLang(AppLang.zhHant);

/// 設計稿 G-08 的新小牛（#151）：小乳牛 #16（母，還不知道品種），再 2 小時 42 分長大，進度 10%（時鐘倍率 1）。
Map<String, dynamic> _designCalf() {
  const left = (2 * 60 + 42) * 60.0;
  return {...designCow(16, 'holstein', stage: 'calf'), 'age_h': left * 0.10 / 0.90 / 3600, 'adult_at': t0 + left};
}

/// .up-row：設施一列（名稱、效果，右邊一顆小按鈕），上面是 2px 的淡色虛線。
/// 設計稿的 .up-row:first-of-type 對不到第一列（卡片標題也是 div），所以每一列都有虛線；兩行字都照 div 的 16px（行高 24）。
Widget _upRow(String name, String effect, Widget button) {
  final row = Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                strutStyle: kDivStrut,
                style: AppText.style(15, weight: FontWeight.w700),
              ),
              Text(effect, strutStyle: kDivStrut, style: KitText.hint()),
            ],
          ),
        ),
        const SizedBox(width: 8),
        button,
      ],
    ),
  );
  return CustomPaint(
    painter: const DashedTopLine(),
    child: Padding(padding: const EdgeInsets.only(top: 2), child: row),
  );
}

final gCases = [
  PageCase(
    'G-04',
    '操作結果提示：成功、伺服器拒絕、網路不穩',
    (tester, lang) {
      final s = Strings.forLang(lang);
      return pumpSheet(tester, lang, [
        for (final (kind, text) in [
          (ToastKind.ok, s.s10Upgraded(what: s.bucketTitle, effect: s.s10EffectBottles(a: 42, b: 63))),
          (ToastKind.err, s.notEnoughCoins(n: fmt(1210))),
          (ToastKind.warn, s.networkError),
        ])
          // .g-toast：每則一格 50 高（格子之間再隔 12），提示靠左上
          SizedBox(
            height: 50,
            child: Align(
              alignment: Alignment.topLeft,
              child: ToastPill(text, kind: kind),
            ),
          ),
      ]);
    },
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.byType(ToastPill), findsNWidgets(3));
      expect(find.text(_zh.networkError), findsOneWidget);
    },
  ),
  PageCase(
    'G-06',
    '處理中：按下的那顆按鈕轉圈，其他按鈕停用',
    (tester, lang) {
      final s = Strings.forLang(lang);
      return pumpSheet(tester, lang, [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    CardTitle(s.upgradesTitle),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.gBusySub,
                        textAlign: TextAlign.right,
                        style: AppText.style(12, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 16),
                      ),
                    ),
                  ],
                ),
              ),
              _upRow(
                s.upBucket,
                s.s10EffectBottles(a: 42, b: 63),
                AppButton(s.gBusy, key: const Key('busy'), small: true, busy: true, onPressed: () {}),
              ),
              _upRow(
                s.upWarehouse,
                s.s10EffectBottles(a: 225, b: 337),
                AppButton(s.costCoins(v: fmt(480)), small: true, kind: ButtonKind.primary),
              ),
              _upRow(
                s.upFresh,
                s.effectFresh(a: 9, b: 12),
                AppButton(s.costCoins(v: fmt(4000)), small: true, kind: ButtonKind.primary),
              ),
            ],
          ),
        ),
      ]);
    },
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.byType(Spinner), findsOneWidget, reason: '只有按下的那顆轉圈');
      expect(find.text(_zh.gBusy), findsOneWidget);
    },
  ),
  PageCase(
    'G-08',
    '小牛長大倒數卡（配種、借種都會用）',
    (tester, lang) async {
      final calf = Cow.fromJson(_designCalf());
      await pumpSheet(tester, lang, [CalfCard(calf: calf)], model: await ranchModel());
      await settleImages(tester);
    },
    crop: find.byKey(const Key('sheet')),
    check: (tester) {
      expect(find.text(_zh.gNewCalf(cow: _zh.calfName(CowType.dairy, 16))), findsOneWidget);
      expect(find.textContaining(_zh.duration(h: 2, m: 42), findRichText: true), findsOneWidget);
      expect(find.byType(TierChip), findsNothing, reason: '小牛不放稀有度（#151）');
    },
  ),
  PageCase(
    'G-09',
    '下拉重新整理',
    (tester, lang) async {
      final s = Strings.forLang(lang);
      await pumpSheet(tester, lang, [
        const PullIndicator(),
        Opacity(
          opacity: 0.9,
          child: AppCard(
            child: Row(
              children: [
                const CowPicture(breed: 'chocolate', bull: true, width: 56, height: 56),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.gBreedSex(breed: s.breedName('chocolate'), sex: s.bull),
                      style: AppText.style(16, weight: FontWeight.w700),
                    ),
                    Text('${s.tierName(2)}${s.gSep}${s.costCoins(v: fmt(2000))}', style: KitText.hint()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ]);
      await settleImages(tester);
    },
    crop: find.byKey(const Key('sheet')),
    check: (tester) => expect(find.text(_zh.gRefreshing), findsOneWidget),
  ),
];
