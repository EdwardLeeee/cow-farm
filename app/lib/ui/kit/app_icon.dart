import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 設計稿的圖示（`app/assets/ui/icons/<name>.svg`，cow-ui 從 design/m2/src/js/icons.js 匯出）。
class AppIcon extends StatelessWidget {
  const AppIcon(this.name, {super.key, this.size = 22});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset('assets/ui/icons/$name.svg', width: size, height: size, excludeFromSemantics: true);
}
