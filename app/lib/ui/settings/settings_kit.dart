// 設定（S13）的共用元件（設計稿 s13.js；screens.css 的 .me-card、.avatar.sm、.set-group、.set-row、.toggle、
// .ud-sample）。
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../kit/app_icon.dart';
import '../kit/cow_art.dart';
import '../kit/kit.dart';
import '../kit/press.dart';

/// .avatar.sm：46×46 的牛臉圓頭像（框 3、下陰影 2）。臉 40×40，往下 3（grid 置中，臉的上緣在框裡 1.5）。
/// [breed] 是牧場選的頭像（S21；沒選過是荷斯坦）。
class SmallAvatar extends StatelessWidget {
  const SmallAvatar({super.key, this.breed = 'holstein'});

  final String breed;

  @override
  Widget build(BuildContext context) => Container(
    width: 46,
    height: 46,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFFBFE6FF),
      border: Border.all(color: AppColors.ink, width: AppSizes.border),
      boxShadow: AppShadows.solid(2),
    ),
    child: ClipOval(
      child: Stack(
        clipBehavior: Clip.none,
        children: [Positioned(left: 0, top: 1.5, child: CowFace(breed: breed, size: 40))],
      ),
    ),
  );
}

/// .me-card：自己牧場的卡片（頭像、牧場名、「#1234・Lv 4」）。[trailing] 是右邊的備份狀態（S13-02）。
class MeCard extends StatelessWidget {
  const MeCard({super.key, required this.name, required this.meta, this.trailing, this.avatar = 'holstein'});

  final String name;

  /// 頭像的品種（S21 的 `state.profile.avatar`）。
  final String avatar;

  /// 第二行（「#1234・Lv 4」）。
  final String meta;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => AppCard(
    key: const Key('me-card'),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(
      children: [
        SmallAvatar(breed: avatar),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AppText.style(16, weight: FontWeight.w700, lineHeight: 21)),
              // .hint 在一般的 div 裡：行高照 div 的（16px 的 normal），字是 13
              Text(meta, strutStyle: kDivStrut, style: KitText.hint()),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    ),
  );
}

/// .set-group：一張卡片裝好幾列（左右留 12、上下 2），第二列起上面是 2px 的淡色虛線。
class SetGroup extends StatelessWidget {
  const SetGroup({super.key, required this.rows});

  final List<SetRow> rows;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final (i, r) in rows.indexed) i == 0 ? r : r._divided()],
    ),
  );
}

/// .set-row：圖示、名稱（[sub] 是下面一行小字）、右邊的東西。最少 54 高（第二列起含上面的虛線 2），內容在虛線下面上下置中。
/// 可以按的列按下時蓋一層顏色、圓角 12（G-12 平的元件）。[danger] 是紅字（刪除我的牧場）。
class SetRow extends StatelessWidget {
  const SetRow({
    super.key,
    this.icon,
    required this.label,
    this.sub,
    this.trailing,
    this.danger = false,
    this.labelSize = 16,
    this.labelStyle,
    this.onTap,
    this.semanticsLabel,
    this.toggled,
    this.selected,
  }) : _divider = false;

  const SetRow._({
    super.key,
    required this.icon,
    required this.label,
    required this.sub,
    required this.trailing,
    required this.danger,
    required this.labelSize,
    required this.labelStyle,
    required this.onTap,
    required this.semanticsLabel,
    required this.toggled,
    required this.selected,
  }) : _divider = true;

  /// 上面有虛線的同一列（SetGroup 的第二列起）。
  SetRow _divided() => SetRow._(
    key: key,
    icon: icon,
    label: label,
    sub: sub,
    trailing: trailing,
    danger: danger,
    labelSize: labelSize,
    labelStyle: labelStyle,
    onTap: onTap,
    semanticsLabel: semanticsLabel,
    toggled: toggled,
    selected: selected,
  );

  final bool _divider;

  final String? icon;
  final String label;
  final String? sub;
  final Widget? trailing;
  final bool danger;
  final double labelSize;

  /// 名稱的樣式（語言名稱用各自的字型時）。
  final TextStyle? labelStyle;
  final VoidCallback? onTap;

  /// 讀螢幕讀的字（右邊的狀態也要讀出來）；null 就讀名稱。
  final String? semanticsLabel;

  /// 開關（音效）開著沒有；null 是沒有開關的列。
  final bool? toggled;

  /// 一組選項裡現在選的那一個（語言）；null 是一般的列。
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        if (icon != null) ...[AppIcon(icon!, size: 22), const SizedBox(width: 10)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style:
                    labelStyle ??
                    AppText.style(
                      labelSize,
                      weight: FontWeight.w900,
                      color: danger ? KitText.errText : AppColors.ink,
                      lineHeight: 21,
                    ),
              ),
              if (sub != null) Text(sub!, style: KitText.hint(size: 12, lineHeight: 17)),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
    // 有 [semanticsLabel] 時把裡面的字換成這一句（excludeSemantics），點的動作也要掛在這裡：
    // 不然裡面 Pressable 的點擊跟著被排除，讀螢幕和網頁版的無障礙樹按了沒反應（8790 走查抓到）
    return Semantics(
      container: true,
      button: onTap != null,
      toggled: toggled,
      selected: selected,
      label: semanticsLabel,
      onTap: semanticsLabel != null ? onTap : null,
      excludeSemantics: semanticsLabel != null,
      child: Pressable(
        onTap: onTap,
        builder: (context, look) {
          final box = ConstrainedBox(
            constraints: BoxConstraints(minHeight: _divider ? 52 : 54),
            child: row,
          );
          return PressTint(
            tint: look.tint,
            borderRadius: const BorderRadius.all(AppRadii.r12),
            child: _divider
                ? CustomPaint(
                    painter: const DashedTopLine(),
                    child: Padding(padding: const EdgeInsets.only(top: 2), child: box),
                  )
                : box,
          );
        },
      ),
    );
  }
}

/// .set-right 的「字＋箭頭」（目前的語言、版本號…；字 13、行高 20，間距 4）。
class SetValue extends StatelessWidget {
  const SetValue(this.text, {super.key, this.chevron = true});

  final String text;
  final bool chevron;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(text, style: KitText.hint(lineHeight: 20)),
      if (chevron) ...[const SizedBox(width: 4), const AppIcon('chevron', size: 18)],
    ],
  );
}

/// .ext：外部網頁（「網頁」加小箭頭，字 13、行高 18，間距 2）。
class SetExternal extends StatelessWidget {
  const SetExternal(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(text, style: KitText.hint(lineHeight: 18)),
      const SizedBox(width: 2),
      const AppIcon('chevron', size: 16),
    ],
  );
}

/// .toggle：52×32 的開關（框 3、圓角 16；開是綠底，圓鈕在右邊）。點整列切換，這裡只畫。
class SetToggle extends StatelessWidget {
  const SetToggle({super.key, required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) => Container(
    width: 52,
    height: 32,
    decoration: BoxDecoration(
      color: on ? AppColors.green2 : AppColors.disabledBg,
      border: Border.all(color: AppColors.ink, width: AppSizes.border),
      borderRadius: const BorderRadius.all(AppRadii.r16),
    ),
    child: Stack(
      children: [
        Positioned(
          left: on ? 22 : 2,
          top: 2,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: AppColors.ink, width: 2.5),
            ),
          ),
        ),
      ],
    ),
  );
}

/// .ud-sample：「▲漲 ▼跌」的顏色樣本（字 12、間距 6）。[big] 是漲跌顏色面板裡的兩行（S13-18：字 12.5、間距 2）。
class UpDownSample extends StatelessWidget {
  const UpDownSample({super.key, required this.upIsRed, required this.up, required this.down, this.big = false});

  final bool upIsRed;
  final String up;
  final String down;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final size = big ? 12.5 : 12.0;
    final upText = Text(
      up,
      softWrap: false,
      style: AppText.style(
        size,
        weight: FontWeight.w900,
        color: AppColors.up(upIsRed: upIsRed),
      ),
    );
    final downText = Text(
      down,
      softWrap: false,
      style: AppText.style(
        size,
        weight: FontWeight.w900,
        color: AppColors.down(upIsRed: upIsRed),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: big
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [upText, const SizedBox(height: 2), downText],
            )
          : Row(mainAxisSize: MainAxisSize.min, children: [upText, const SizedBox(width: 6), downText]),
    );
  }
}
