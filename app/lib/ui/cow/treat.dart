// 治療病牛（v0.3 第 5 節；設計稿 s04.js 的 S04-19～21）：從牛的詳細（S04-18）或牧場點牛的名片（S03-29）按「治療」，
// 先問一次（S04-19「治療荷斯坦 #3？」「花 5,000 幣，馬上就好。」），確定了才送 POST /v1/cure（協定 2.6）。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../l10n/format.dart';
import '../../l10n/l10n.dart';
import '../../state/game_model.dart';
import '../kit/kit.dart';

/// 治療一頭要多少幣（`economy.cure_price`；舊的伺服器沒有就照設計稿的 5,000）。
double curePrice(GameModel m) => m.state?.economy?.curePrice ?? 5000;

/// S04-19：治療確認。按「治療」回 true，「取消」回 false。
class TreatDialog extends StatelessWidget {
  const TreatDialog({super.key, required this.cow, required this.price});

  final Cow cow;
  final double price;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return AppDialog(
      key: const Key('treat-dialog'),
      title: s.s04TreatTitle(cow: s.cowLabel(cow)),
      body: Text(s.s04TreatBody(price: fmt(price)), textAlign: TextAlign.center),
      buttons: [
        AppButton(s.cancel, key: const Key('treat-cancel'), onPressed: () => Navigator.of(context).pop(false)),
        AppButton(
          s.treat(price: fmt(price)),
          key: const Key('treat-ok'),
          kind: ButtonKind.primary,
          icon: 'coin',
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

/// 按了「治療」：先問（S04-19），確定了才治療。取消是 null。
Future<ActionResult<Map<String, dynamic>>?> treatCow(BuildContext context, Cow cow) async {
  final m = context.read<GameModel>();
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: Colors.transparent, // 暗幕由 AppDialog 自己畫
    useSafeArea: false,
    builder: (_) => TreatDialog(cow: cow, price: curePrice(m)),
  );
  if (ok != true) return null;
  return m.cure(cow);
}
