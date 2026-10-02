import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 設計稿的圖示（`app/assets/ui/icons/<name>.svg`，cow-ui 從 design/m2/src/js/icons.js 匯出）。
class AppIcon extends StatelessWidget {
  const AppIcon(this.name, {super.key, this.size = 22, this.color});

  final String name;
  final double size;

  /// 用 currentColor 畫的圖示（漲跌的三角形）要的顏色；設計稿是跟著旁邊的字。
  final Color? color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/ui/icons/$name.svg',
    width: size,
    height: size,
    excludeFromSemantics: true,
    theme: color == null ? const SvgTheme() : SvgTheme(currentColor: color!),
  );
}
