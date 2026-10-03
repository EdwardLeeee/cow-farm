// 沒有場景的頁面的頁首和篩選（screens.css 的 .page-head、.filter；kit.css 的 .icon-btn）。
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import 'app_icon.dart';
import 'press.dart';

/// .page-head：返回、標題和小字、右邊一顆按鈕。英文、泰文放不下時標題可以換兩行（screens.css 第 1 條）。
class PageHead extends StatelessWidget {
  const PageHead({super.key, required this.title, this.sub, this.onBack, this.action, this.actionFixed = false});

  final String title;
  final String? sub;
  final VoidCallback? onBack;
  final Widget? action;

  /// [action] 照自己的寬度、不縮（flex: none），標題讓位：「連線中…」膠囊（S13-20 的 .hud-offline.in-head）。
  /// 沒有的話右邊是按鈕，最多佔一半、字換行。
  final bool actionFixed;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) => _row(context, c.maxWidth));

  Widget _row(BuildContext context, double width) => Row(
    children: [
      if (onBack != null) ...[
        CircleIconButton(icon: 'back', label: Strings.of(context).back, onTap: onBack!),
        const SizedBox(width: 8),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.style(20, weight: FontWeight.w900, lineHeight: 26)),
            if (sub != null)
              Text(
                sub!,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: AppText.style(13, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 18),
              ),
          ],
        ),
      ),
      // 右邊的按鈕照自己的寬度靠右，標題拿剩下的（.page-head .grow { flex: 1 }）；
      // 英文、泰文太寬時按鈕最多佔一半、字換行，標題才不會被擠到從字的中間斷（screens.css 第 1 條）
      if (action != null) ...[
        const SizedBox(width: 8),
        if (actionFixed)
          action!
        else
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width / 2),
            child: action!,
          ),
      ],
    ],
  );
}

/// .icon-btn：44×44 的白色圓形鈕（返回、上一頁…）。G-12：浮起，按下往下 2。
/// 自己一個無障礙節點（container）：不然旁邊的標題會併進來，讀成「返回 借種紀錄 借出收入累計 0 幣」一顆按鈕。
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({super.key, required this.icon, required this.label, required this.onTap});

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: label,
    child: Pressable(
      key: Key('btn-$icon'),
      lift: 3,
      onTap: onTap,
      builder: (context, look) => PressTint(
        tint: look.tint,
        shape: BoxShape.circle,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: AppColors.ink, width: AppSizes.border),
            boxShadow: AppShadows.solid(look.shadow),
          ),
          child: AppIcon(icon, size: 22),
        ),
      ),
    ),
  );
}

/// .filter：一排膠囊，選中的黃底。放不下時可以左右滑（設計稿是不換行）。G-12：平的元件，按下蓋色。
class FilterChips extends StatelessWidget {
  const FilterChips({super.key, required this.labels, required this.selected, required this.onSelect});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    clipBehavior: Clip.none,
    child: Row(
      children: [
        for (final (i, label) in labels.indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Semantics(
            container: true,
            button: true,
            selected: i == selected,
            child: Pressable(
              key: Key('filter-$i'),
              onTap: () => onSelect(i),
              builder: (context, look) => PressTint(
                tint: look.tint,
                borderRadius: const BorderRadius.all(AppRadii.r22),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? AppColors.yellow : Colors.white,
                    // CSS 寫 2.5px，Chrome 畫成 2px；照核准的設計稿（boards 量出來 2）
                    border: Border.all(color: AppColors.ink, width: 2),
                    borderRadius: const BorderRadius.all(AppRadii.r22),
                  ),
                  child: Text(
                    label,
                    softWrap: false,
                    style: AppText.style(14, weight: i == selected ? FontWeight.w900 : FontWeight.w700),
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
