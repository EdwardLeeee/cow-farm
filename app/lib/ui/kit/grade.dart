// 牛肉的評級（設計稿 s04.js 的 GRADE_BG、gradeBar；screens.css 的 .gchip、.grade-bar、.grade-legend）：
// 倉庫的牛肉批次（S05）、牛的詳細的出貨評級機率（S04）、出貨確認（S07）。
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../l10n/format.dart';
import '../../theme/tokens.dart';

/// 評級的底色（s04.js 的 GRADE_BG）。
const kGradeColors = {'A': Color(0xFFFFD45E), 'B': Color(0xFFCFE6FF), 'C': Color(0xFFFFD9C2)};

const kGrades = ['A', 'B', 'C'];

/// .gchip：評級的小色塊（26×26、圓角 9）。
class GradeChip extends StatelessWidget {
  const GradeChip(this.grade, {super.key});

  final String grade;

  @override
  Widget build(BuildContext context) => Container(
    width: 26,
    height: 26,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: kGradeColors[grade] ?? const Color(0xFFFFFFFF),
      // CSS 寫 2.5px，boards 量出來是 2（Chrome 畫成 2px）；照核准的 boards
      border: Border.all(color: AppColors.ink, width: 2),
      borderRadius: const BorderRadius.all(Radius.circular(9)),
    ),
    child: Text(grade, style: AppText.style(14, weight: FontWeight.w900, lineHeight: 18)),
  );
}

/// .grade-bar 加 .grade-legend：A／B／C 的機率條（高 18），下面三個色塊和百分比。機率是伺服器給的。
class GradeBar extends StatelessWidget {
  const GradeBar({super.key, required this.probs});

  final Map<String, double> probs;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final g in kGrades)
        if ((probs[g] ?? 0) > 0) g,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 18,
          decoration: BoxDecoration(
            // CSS 寫 2.5px，boards 量出來是 2（Chrome 畫成 2px）；照核准的 boards
            border: Border.all(color: AppColors.ink, width: 2),
            borderRadius: const BorderRadius.all(AppRadii.r10),
          ),
          // 每一段的寬是機率 × 框內的寬（CSS 的 width: p%，含右邊 2px 的分隔線）；最後一段補滿。
          // overflow: hidden 裁在框的內緣（圓角 10 − 2），顏色才不會蓋到框的圓角
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(10 - 2)),
            child: LayoutBuilder(
              builder: (context, c) => Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, g) in shown.indexed)
                    if (i < shown.length - 1)
                      Container(
                        width: math.min(c.maxWidth, c.maxWidth * probs[g]!),
                        decoration: BoxDecoration(
                          color: kGradeColors[g],
                          border: const Border(right: BorderSide(color: AppColors.ink, width: 2)),
                        ),
                      )
                    else
                      Expanded(child: ColoredBox(color: kGradeColors[g]!)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final g in kGrades)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GradeChip(g),
                  const SizedBox(width: 5),
                  Text(pct(probs[g] ?? 0), style: AppText.number(15)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
