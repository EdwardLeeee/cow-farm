// .kv（kit.css）：小格子，上面一行小字、下面一行大字（可以接小字單位）。牛的詳細（S04）兩欄、田地（S17 的 .kv3）三欄。
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'kit.dart';

/// 一格：小字 [k]、大字 [v]，後面接小字單位 [unit]（「14 瓶／時」「3 / 12 塊」；沒有是 null）。
typedef KvCell = (String k, String v, String? unit);

TextStyle _even(TextStyle s) => s.copyWith(leadingDistribution: TextLeadingDistribution.even);

/// .kv：[columns] 欄、間距 8；同一排的格子一樣高（CSS grid）。大字 .kv .v 是 17px，.kv3 是 16px（[valueSize]）。
class KvGrid extends StatelessWidget {
  const KvGrid({super.key, required this.cells, this.columns = 2, this.valueSize = 17, this.cellKeys = const {}});

  final List<KvCell> cells;
  final int columns;
  final double valueSize;

  /// 第幾格掛什麼 key（例：A-08 稻穗飛進「倉庫稻米」那一格）。
  final Map<int, Key> cellKeys;

  @override
  Widget build(BuildContext context) {
    final value = _even(AppText.number(valueSize, lineHeight: 22));
    final unitStyle = _even(AppText.style(12, weight: FontWeight.w700, lineHeight: 22, letterSpacing: 0.2));
    Widget cell(int i) {
      final (k, v, unit) = cells[i];
      return Container(
        key: cellKeys[i],
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.lineSoft, width: 2),
          borderRadius: const BorderRadius.all(AppRadii.r12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              k,
              softWrap: false,
              style: AppText.style(12, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 16),
            ),
            // 有單位的那一行在 Chrome 是 25 高（小字往下多佔 3），沒有是 22
            CssLine(
              TextSpan(
                style: value,
                children: [
                  TextSpan(text: v),
                  // 「14 <small>瓶／時</small>」：空白是大字的，小字再往右 2
                  if (unit != null) ...[
                    TextSpan(
                      text: ' ',
                      style: value.copyWith(letterSpacing: 0.2 + 2),
                    ),
                    TextSpan(text: unit, style: unitStyle),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < cells.length; i += columns) ...[
          if (i > 0) const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = 0; j < columns; j++) ...[
                  if (j > 0) const SizedBox(width: 8),
                  Expanded(child: i + j < cells.length ? cell(i + j) : const SizedBox.shrink()),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
