import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/format.dart';
import '../../l10n/l10n.dart';
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

/// 操作失敗的原因 → 給玩家看的字（目前的語言）。伺服器的錯誤依錯誤碼查字串表（協定 1.4），不顯示伺服器的 message。
String actionErrorText(BuildContext context, ActionError error) =>
    actionErrorTextWith(Strings.of(context, listen: false), context.read<GameModel>(), error);

/// 同上，給 await 之後畫面可能已經關掉的地方用：先拿好 [s]、[m] 再呼叫。
String actionErrorTextWith(Strings s, GameModel m, ActionError error) => switch (error) {
  ApiActionError(:final error) => s.errorText(
    error.code,
    detail: error.detail,
    gameNow: m.gameNow,
    timeScale: m.timeScale,
  ),
  NetworkActionError() => s.networkError,
  OfflineActionError() => s.connecting,
};

/// 有人借了我的公牛（G-05）：「{cow} 借給 {ranch}，收到 {price} 幣」。
String noticeText(BuildContext context, GameNotice notice) {
  final s = Strings.of(context, listen: false);
  return switch (notice) {
    StudBorrowedNotice(:final cowId, :final breed, :final borrower, :final price) => s.gStudNoticeBody(
      cow: breed == null ? '#$cowId' : s.cowName(breed, cowId is int ? cowId : int.tryParse('$cowId') ?? 0),
      ranch: s.ranchText(borrower),
      price: fmt(price),
    ),
  };
}

/// 顯示操作結果：成功顯示 [okText]，失敗依錯誤碼顯示字串表的文案。
void showResult(BuildContext context, ActionError? error, String okText) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final text = error == null ? okText : actionErrorText(context, error);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
}
