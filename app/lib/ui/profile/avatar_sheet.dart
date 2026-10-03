// S21-02、S21-03 換頭像（D34；設計稿 s21.js 的 avatarSheet、screens.css 的 .av-*）。在牧場資料點頭像打開。
// - 只能選圖鑑裡發現過的牛（使用者：「本來我們的原則就是沒有發現過的牛就要不能選」）；換頭像不用錢，不寫價錢。
// - 還沒發現的畫成剪影加鎖，點了不能選，下面那行換成「還沒發現「星空牛」，在圖鑑發現以後就能用」（S21-03）。
// - 上面一列：現在的頭像（淡）→ 選的頭像、品種名。窄於 340 收起來、格子 5 欄（平常 6 欄）。
import 'package:flutter/material.dart';

import '../../api/breeds.dart';
import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../kit/app_icon.dart';
import '../kit/cow_art.dart';
import '../kit/kit.dart';
import '../kit/press.dart';

class AvatarSheet extends StatefulWidget {
  const AvatarSheet({
    super.key,
    required this.current,
    required this.found,
    required this.onUse,
    required this.onClose,
    this.busy = false,
  });

  /// 現在的頭像（品種代號）。
  final String current;

  /// 圖鑑發現過的品種。
  final Set<String> found;

  /// 按「用這個頭像」：選的跟現在的不一樣才會呼叫。
  final ValueChanged<String> onUse;
  final VoidCallback onClose;

  /// 送出中：按鈕停用。
  final bool busy;

  @override
  State<AvatarSheet> createState() => AvatarSheetState();
}

class AvatarSheetState extends State<AvatarSheet> {
  late String _sel = widget.current;

  /// 點了還沒發現的牛（S21-03）；點了發現過的就清掉。
  String? _tapped;

  /// 伺服器說這種牛還沒發現（avatar_locked，手機的圖鑑比伺服器舊）：跟點了鎖住的格子一樣提示。
  void showLocked(String breed) => setState(() => _tapped = breed);

  void _pick(String breed) => setState(() {
    if (widget.found.contains(breed)) {
      _sel = breed;
      _tapped = null;
    } else {
      _tapped = breed;
    }
  });

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final cols = narrow ? 5 : 6;
    final tapped = _tapped;
    return AppSheet(
      title: s.s21AvatarTitle,
      onClose: widget.onClose,
      children: [
        if (!narrow) _Preview(current: widget.current, selected: _sel),
        if (!narrow) const SizedBox(height: 12),
        // .av-grid：每格是正方形，格子之間 8
        Column(
          key: const Key('av-grid'),
          children: [
            for (var i = 0; i < kCodexOrder.length; i += cols) ...[
              if (i > 0) const SizedBox(height: 8),
              Row(
                children: [
                  for (var c = 0; c < cols; c++) ...[
                    if (c > 0) const SizedBox(width: 8),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: i + c < kCodexOrder.length
                            ? _Cell(
                                key: Key('av-${kCodexOrder[i + c]}'),
                                breed: kCodexOrder[i + c],
                                locked: !widget.found.contains(kCodexOrder[i + c]),
                                on: kCodexOrder[i + c] == _sel,
                                tapped: kCodexOrder[i + c] == tapped,
                                onTap: () => _pick(kCodexOrder[i + c]),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        // .av-count：發現了幾種；點了鎖住的換成那種牛的提示（橘色）
        Row(
          key: const Key('av-count'),
          children: [
            const AppIcon('lock', size: 14),
            const SizedBox(width: 4),
            Expanded(
              child: tapped != null
                  // 「星空牛」，：相連的全形標點照 Chrome 收掉半格
                  ? Text.rich(
                      TextSpan(children: cjkTrimSpans(s.s21AvatarLocked(name: s.breedName(tapped)))),
                      style: KitText.warn(),
                    )
                  : Text(
                      s.s21AvatarCount(n: widget.found.where(kCodexOrder.contains).length, total: kCodexOrder.length),
                      style: KitText.hint(),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        BtnRow(
          children: [
            AppButton(s.cancel, key: const Key('av-cancel'), onPressed: widget.onClose),
            AppButton(
              s.s21AvatarUse,
              key: const Key('av-use'),
              kind: ButtonKind.primary,
              busy: widget.busy,
              // 選的跟現在一樣：按了只是關掉（不用問伺服器）
              onPressed: () => _sel == widget.current ? widget.onClose() : widget.onUse(_sel),
            ),
          ],
        ),
      ],
    );
  }
}

/// .av-preview：現在的頭像（淡 60%）→ 選的頭像，右邊品種名和「只有圖鑑裡發現過的能選」。
class _Preview extends StatelessWidget {
  const _Preview({required this.current, required this.selected});

  final String current;
  final String selected;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Container(
      key: const Key('av-preview'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.lineSoft, width: 2),
        borderRadius: const BorderRadius.all(AppRadii.r16),
      ),
      child: Row(
        children: [
          Opacity(opacity: 0.6, child: AvatarCircle.preview(breed: current)),
          const SizedBox(width: 8),
          const AppIcon('chevron', size: 18),
          const SizedBox(width: 8),
          AvatarCircle.preview(breed: selected),
          const SizedBox(width: 8 + 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.breedName(selected), style: AppText.style(17, weight: FontWeight.w700, lineHeight: 23)),
                Text(s.s21AvatarFoundOnly, style: KitText.hint()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// .av-circle：牛臉的圓（框 2.5、淺藍底、切圓）。臉的大小、位置照 Chrome 量的（Playwright 量設計稿 S21-02 的 430、390）：
/// - 上面那一列（[AvatarCircle.preview]）：圓 52、臉 48，臉在框裡左 −0.5、上 3.5。
/// - 格子裡（[AvatarCircle.cell]）：臉是 0.92 ×（圓 − 4），連同上面 4 的 margin 一起在框裡置中。
/// [locked] 是還沒發現的：停用色、臉是 22% 的黑色剪影。
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    required this.breed,
    required this.size,
    required this.face,
    required this.faceLeft,
    required this.faceTop,
    this.locked = false,
  });

  const AvatarCircle.preview({super.key, required this.breed})
    : size = 52,
      face = 48,
      faceLeft = -0.5,
      faceTop = 3.5,
      locked = false;

  factory AvatarCircle.cell({Key? key, required String breed, required double size, bool locked = false}) {
    final inner = size - 5, face = 0.92 * (size - 4);
    return AvatarCircle(
      key: key,
      breed: breed,
      size: size,
      face: face,
      faceLeft: (inner - face) / 2,
      faceTop: (inner - face - 4) / 2 + 4,
      locked: locked,
    );
  }

  final String breed;
  final double size;
  final double face;

  /// 臉的左上角在框裡（框 2.5 以內）的位置。
  final double faceLeft;
  final double faceTop;
  final bool locked;

  static const _black = ColorFilter.matrix([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0]);

  @override
  Widget build(BuildContext context) {
    Widget pic = CowFace(breed: breed, size: face);
    if (locked) {
      pic = Opacity(
        opacity: 0.22,
        child: ColorFiltered(colorFilter: _black, child: pic),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: locked ? AppColors.disabledBg : const Color(0xFFBFE6FF),
        border: Border.all(color: locked ? AppColors.disabledLine : AppColors.ink, width: 2.5),
      ),
      child: ClipOval(
        child: Stack(
          clipBehavior: Clip.none,
          children: [Positioned(left: faceLeft, top: faceTop, child: pic)],
        ),
      ),
    );
  }
}

/// .av-cell：一格（正方形、圓角 16）：頭像的圓是格子的 88%、臉是圓的 92%。選的：淡綠底加綠色內框、右上角打勾；
/// 點了鎖住的：淡橘底加橘色內框；還沒發現的：右下角小鎖。平的元件：按下蓋一層顏色。
class _Cell extends StatelessWidget {
  const _Cell({
    super.key,
    required this.breed,
    required this.locked,
    required this.on,
    required this.tapped,
    required this.onTap,
  });

  final String breed;
  final bool locked;
  final bool on;
  final bool tapped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Semantics(
      container: true,
      button: true,
      selected: on,
      label: locked ? s.gUnknownBreed : s.breedName(breed),
      onTap: onTap,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        builder: (context, look) => LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final circle = w * 0.88;
            final ring = on ? AppColors.green2 : (tapped ? const Color(0xFFE8964A) : null);
            return PressTint(
              tint: look.tint,
              borderRadius: const BorderRadius.all(AppRadii.r16),
              child: DecoratedBox(
                // CSS 的 inset 3px 外框：畫在格子裡面，不佔版面
                decoration: BoxDecoration(
                  color: on ? const Color(0xFFE4F7D8) : (tapped ? const Color(0xFFFFF1DF) : null),
                  border: ring == null ? null : Border.all(color: ring, width: 3),
                  borderRadius: const BorderRadius.all(AppRadii.r16),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: AvatarCircle.cell(breed: breed, size: circle, locked: locked),
                    ),
                    if (locked)
                      // .av-lock：右下角的小鎖（白底、停用色的框 2、鎖 12）
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.disabledLine, width: 2),
                          ),
                          child: const AppIcon('lock', size: 12),
                        ),
                      ),
                    if (on) const Positioned(right: -5, top: -5, child: AppIcon('ok', size: 20)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
