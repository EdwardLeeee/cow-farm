import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/game_model.dart';

/// 所有會送出操作的按鈕都用這個：斷線或正在處理上一個操作時一律停用。
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.outlined = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// 畫面自己的條件（例如錢不夠）。
  final bool enabled;
  final bool outlined;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final canAct = context.select<GameModel, bool>((m) => m.canAct);
    final cb = (canAct && enabled) ? onPressed : null;
    final child = Text(label, textAlign: TextAlign.center);
    final btn = outlined ? OutlinedButton(onPressed: cb, child: child) : FilledButton(onPressed: cb, child: child);
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// 顯示操作結果（伺服器的錯誤訊息直接顯示）。
void showResult(BuildContext context, String? error, String okText) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(SnackBar(content: Text(error ?? okText), duration: const Duration(seconds: 2)));
}
