// S11-01 場主升級慶祝（設計稿 s10.js 的 levelUp；screens.css 的 .lv-wrap、.confetti、.lv-card、.lv-ribbon、.lv-big）：
// 暗幕、彩紙、中間一張卡（「場主升級」彩帶、Lv 5、累積收入到 7,500 幣了！、說明、「好」）。沒有獎勵，只有慶祝（D24）。
// 動畫 A-05 之後做；現在是靜態的（等於減少動態版）。
import 'package:flutter/material.dart';

import '../../l10n/format.dart';
import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../kit/kit.dart';

/// 升到 [level] 級的慶祝；[levelAt] 是這一級的門檻（累積收入）。
class LevelUpOverlay extends StatelessWidget {
  const LevelUpOverlay({super.key, required this.level, required this.levelAt, required this.onOk});

  final int level;
  final num levelAt;
  final VoidCallback onOk;

  /// 彩紙的顏色（設計稿的五色）。
  static const _colors = [
    Color(0xFFFFD45E),
    Color(0xFFFF9784),
    Color(0xFFA9DBFF),
    Color(0xFFBDE8A6),
    Color(0xFFFFD0DE),
  ];

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Positioned.fill(
      key: const Key('level-up'),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return Stack(
            children: [
              // 暗幕：點了不關（要按「好」）
              const Positioned.fill(child: ModalBarrier(color: AppColors.backdrop, dismissible: false)),
              // .confetti：上面 14% 起、高 40% 的範圍裡 26 片（位置、顏色、角度照設計稿的公式）
              for (var i = 0; i < 26; i++)
                Positioned(
                  left: w * ((i * 37) % 100) / 100,
                  top: h * 0.14 + h * 0.4 * ((i * 53) % 46) / 100,
                  child: IgnorePointer(
                    child: Transform.rotate(
                      angle: ((i * 29) % 90) * 3.141592653589793 / 180,
                      child: Container(
                        width: 10,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _colors[i % 5],
                          border: Border.all(color: AppColors.ink, width: 2),
                          borderRadius: const BorderRadius.all(Radius.circular(3)),
                        ),
                      ),
                    ),
                  ),
                ),
              // .lv-wrap：左右留 24，卡片在正中間
              Positioned.fill(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _LevelCard(level: level, levelAt: levelAt, onOk: onOk, s: s),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.level, required this.levelAt, required this.onOk, required this.s});

  final int level;
  final num levelAt;
  final VoidCallback onOk;
  final Strings s;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.topCenter,
    children: [
      AppCard(
        key: const Key('level-card'),
        padding: const EdgeInsets.fromLTRB(16, 30, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // .lv-big：「Lv」和大數字，基線對齊、隔 6
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  s.s11Lv,
                  style: AppText.style(26, weight: FontWeight.w900, color: AppColors.ink2),
                ),
                const SizedBox(width: 6),
                Text('$level', key: const Key('level-up-lv'), style: AppText.number(76, lineHeight: 88)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              s.s11Earned(v: fmt(levelAt)),
              textAlign: TextAlign.center,
              style: AppText.style(18, weight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(s.s11Hint, textAlign: TextAlign.center, style: KitText.hint()),
            const SizedBox(height: 14),
            AppButton(s.ok, key: const Key('level-up-ok'), kind: ButtonKind.primary, block: true, onPressed: onOk),
          ],
        ),
      ),
      // .lv-ribbon：卡片上緣往上 20、置中
      Positioned(
        top: -20,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.coral,
            border: Border.all(color: AppColors.ink, width: AppSizes.border),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            boxShadow: AppShadows.solid(3),
          ),
          child: Text(s.s11Ribbon, softWrap: false, style: AppText.style(18, weight: FontWeight.w900)),
        ),
      ),
    ],
  );
}
