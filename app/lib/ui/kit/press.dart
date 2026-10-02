// 按下的樣子（G-11～G-13；使用者 2026-10-02 核准 cow-ui 的狀態表 M2-G-按下-狀態表）：
// - 浮起的元件（有實心下陰影 4、3、2）：手指一碰到就往下移（陰影 − 1），下陰影變薄成 1，底邊停在原來的位置；放開 0.1 秒彈回。
// - 平的元件（沒有自己的陰影）：蓋一層 12% 的可可色，不移動。
// - 手機開了「減少動態」：浮起的元件也不移動、陰影不變，跟平的元件一樣只蓋顏色；放開立刻回去。
// - 停用、處理中（轉圈）的按了不會變。
import 'package:flutter/material.dart';

/// 按下時蓋的顏色：12% 的可可色（screens.css 的 --press）。
const kPressTint = Color.fromRGBO(75, 51, 38, 0.12);

/// 現在按下的樣子，給元件自己畫：[shadow] 是下陰影的高度（浮起的元件按下時變 1），[tint] 是要蓋的顏色（沒有就是 null）。
class PressLook {
  const PressLook(this.shadow, this.tint);
  final double shadow;
  final Color? tint;
}

/// 可以按的元件。[lift] 是元件的下陰影高度（4、3、2；平的元件是 0）。[onTap] 是 null 就是停用，按了不會變。
/// 元件照 [builder] 拿到的 [PressLook] 畫陰影和蓋色；往下移由這裡負責。
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.onTap, required this.builder, this.lift = 0, this.behavior});

  final VoidCallback? onTap;
  final double lift;
  final HitTestBehavior? behavior;
  final Widget Function(BuildContext context, PressLook look) builder;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with SingleTickerProviderStateMixin {
  late final _press = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));

  /// 減少動態：每次畫的時候記下來。放開、取消可能發生在元件已經拿掉之後（例：提示時間到收起來時手指還按著），那時不能再查。
  bool _still = false;

  bool get _enabled => widget.onTap != null;

  @override
  void didUpdateWidget(Pressable old) {
    super.didUpdateWidget(old);
    if (!_enabled) _press.value = 0; // 按到一半變成停用（例：開始處理），馬上回去
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) {
    if (_enabled) _press.value = 1; // 一碰就變
  }

  void _up() {
    if (!mounted) return;
    if (_still) {
      _press.value = 0; // 減少動態：放開立刻回去
    } else {
      _press.reverse(); // 0.1 秒彈回
    }
  }

  @override
  Widget build(BuildContext context) {
    final still = _still = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: widget.behavior ?? HitTestBehavior.opaque,
      onTapDown: _enabled ? _down : null,
      onTapUp: _enabled ? (_) => _up() : null,
      onTapCancel: _enabled ? _up : null,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _press,
        builder: (context, _) {
          final t = _press.value;
          final raised = widget.lift > 0 && !still;
          final look = PressLook(
            raised ? widget.lift - (widget.lift - 1) * t : widget.lift,
            !raised && t > 0 ? kPressTint.withValues(alpha: kPressTint.a * t) : null,
          );
          final child = widget.builder(context, look);
          if (!raised || t == 0) return child;
          return Transform.translate(offset: Offset(0, (widget.lift - 1) * t), child: child);
        },
      ),
    );
  }
}

/// 在元件上蓋按下的顏色（形狀跟元件一樣）。[tint] 是 null 就不蓋。
class PressTint extends StatelessWidget {
  const PressTint({
    super.key,
    required this.tint,
    required this.child,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  final Color? tint;
  final Widget child;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    if (tint == null) return child;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(color: tint, borderRadius: borderRadius, shape: shape),
      child: child,
    );
  }
}
