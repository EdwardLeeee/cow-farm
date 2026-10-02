// 卡片的小標籤和進度條（kit.css 的 .card-title、.bar）：牧場面板、倉庫、之後的升級頁都用。
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'app_icon.dart';

/// .card-title：小標籤（黃底；奶桶藍、收購價綠）。
class CardTitle extends StatelessWidget {
  const CardTitle(this.text, {super.key, this.color = AppColors.yellow, this.icon});

  final String text;
  final Color color;

  /// 字前面的圖示（18，倉庫的牛奶、牛肉、稻米）。
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final label = Text(text, softWrap: false, style: AppText.style(13, weight: FontWeight.w900, lineHeight: 20));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: const BorderRadius.all(AppRadii.r10),
      ),
      child: icon == null
          ? label
          : Row(mainAxisSize: MainAxisSize.min, children: [AppIcon(icon!, size: 18), const SizedBox(width: 4), label]),
    );
  }
}

/// .bar：進度條（藍色、粗描邊，右緣一條深色線，上面一條白色反光）。
class MeterBar extends StatelessWidget {
  const MeterBar({
    super.key,
    required this.fraction,
    this.height = 14,
    this.fill = AppColors.blue2,
    this.track = const Color(0xFFE6F3FC),
  });

  /// 綠（.bar.green）：新鮮度 70% 以上。
  const MeterBar.green({super.key, required this.fraction, this.height = 14})
    : fill = const Color(0xFF8CD46F),
      track = const Color(0xFFEAF7E1);

  /// 黃（.bar.yellow）：新鮮度 30–70%、倉庫快滿。
  const MeterBar.yellow({super.key, required this.fraction, this.height = 14})
    : fill = const Color(0xFFFFB938),
      track = const Color(0xFFFFF4CC);

  /// 紅（.bar.red，底色不變）：快壞了、倉庫滿了。
  const MeterBar.red({super.key, required this.fraction, this.height = 14})
    : fill = const Color(0xFFFF8A80),
      track = const Color(0xFFE6F3FC);

  final double fraction;
  final double height;
  final Color fill;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: track,
        // CSS 寫 2.5px，boards 量出來是 2（Chrome 畫成 2px）；照核准的 boards
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: f,
            heightFactor: 1,
            child: Container(
              decoration: BoxDecoration(
                color: fill,
                border: f >= 1 ? null : const Border(right: BorderSide(color: AppColors.ink, width: 2)),
              ),
              child: const Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: 3,
                  width: double.infinity,
                  child: ColoredBox(color: Color(0x8CFFFFFF)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
