// .seg：一排切換（kit.css；商店的抽牛／設施、配種的自己配種／借種）。
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'press.dart';

/// .seg：一排切換（白底、粗框、圓角 22、下陰影 3）；選中的黃底。平的元件，按下蓋色（G-12）。
class SegControl extends StatelessWidget {
  const SegControl({super.key, required this.labels, required this.selected, required this.onSelect});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.ink, width: AppSizes.border),
      borderRadius: const BorderRadius.all(AppRadii.r22),
      boxShadow: AppShadows.solid(3),
    ),
    child: Row(
      children: [
        for (final (i, label) in labels.indexed) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              button: true,
              selected: i == selected,
              child: Pressable(
                key: Key('seg-$i'),
                onTap: () => onSelect(i),
                builder: (context, look) => PressTint(
                  tint: look.tint,
                  borderRadius: const BorderRadius.all(AppRadii.r16),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 36),
                    alignment: Alignment.center,
                    decoration: i == selected
                        ? BoxDecoration(
                            color: AppColors.yellow,
                            // CSS 寫 2.5px，boards 量出來是 2（Chrome 畫成 2px）；照核准的 boards
                            border: Border.all(color: AppColors.ink, width: 2),
                            borderRadius: const BorderRadius.all(AppRadii.r16),
                          )
                        : null,
                    child: Text(
                      label,
                      softWrap: false,
                      style: AppText.style(
                        15,
                        weight: i == selected ? FontWeight.w900 : FontWeight.w700,
                        color: i == selected ? AppColors.ink : AppColors.ink2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
