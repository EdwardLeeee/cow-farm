// .seg：一排切換（kit.css；商店的抽牛／設施、配種的自己配種／借種）。
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'press.dart';

/// .seg：一排切換（白底、粗框、圓角 22、下陰影 3）；選中的黃底。平的元件，按下蓋色（G-12）。
/// [small]：.seg.small（每顆最矮 32、字 13；排行榜的總資產／圖鑑／本週收入）。
/// 每顆的 key 是「[keyPrefix]-第幾顆」（同一頁有兩排時分得出來）。
class SegControl extends StatelessWidget {
  const SegControl({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelect,
    this.small = false,
    this.keyPrefix = 'seg',
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  final bool small;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.ink, width: AppSizes.border),
      borderRadius: const BorderRadius.all(AppRadii.r22),
      boxShadow: AppShadows.solid(3),
    ),
    // flex: 1 的寬度照 CSS 算：每顆先是自己的框（選中的有左右 2 的框、其他的 0），剩下的平分。
    // 所以選中的那顆比其他的寬 4（430 寬：196 對 192）
    child: LayoutBuilder(
      builder: (context, c) {
        const gap = 4.0, ring = 2.0 * 2;
        final share = (c.maxWidth - gap * (labels.length - 1) - ring) / labels.length;
        return Row(
          children: [
            for (final (i, label) in labels.indexed) ...[
              if (i > 0) const SizedBox(width: gap),
              SizedBox(
                width: i == selected ? share + ring : share,
                child: Semantics(
                  container: true,
                  button: true,
                  selected: i == selected,
                  child: Pressable(
                    key: Key('$keyPrefix-$i'),
                    onTap: () => onSelect(i),
                    builder: (context, look) => PressTint(
                      tint: look.tint,
                      borderRadius: const BorderRadius.all(AppRadii.r16),
                      child: Container(
                        constraints: BoxConstraints(minHeight: small ? 32 : 36),
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
                            small ? 13 : 15,
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
        );
      },
    ),
  );
}
