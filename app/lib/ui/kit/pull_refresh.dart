// G-09 下拉重新整理（設計稿 g.js 的 G-09；screens.css 的 .pull-ind）。
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import 'kit.dart';

/// 下拉重新整理：拉的手勢跟 Material 的一樣（[RefreshIndicator.noSpinner]），畫面換成設計稿的「轉圈＋重新整理中…」。
/// [builder] 拿到 refreshing（正在重新整理），把 [PullIndicator] 放在清單最上面。
class PullRefresh extends StatefulWidget {
  const PullRefresh({super.key, required this.onRefresh, required this.builder});

  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext context, bool refreshing) builder;

  @override
  State<PullRefresh> createState() => _PullRefreshState();
}

class _PullRefreshState extends State<PullRefresh> {
  bool _refreshing = false;

  Future<void> _run() async {
    setState(() => _refreshing = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      RefreshIndicator.noSpinner(onRefresh: _run, child: widget.builder(context, _refreshing));
}

/// .pull-ind：高 44，轉圈和「重新整理中…」置中（字 14 特粗、ink-2，間距 8）。
class PullIndicator extends StatelessWidget {
  const PullIndicator({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('pull-indicator'),
    height: 44,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spinner(),
        const SizedBox(width: 8),
        Text(
          Strings.of(context).gRefreshing,
          style: AppText.style(14, weight: FontWeight.w900, color: AppColors.ink2),
        ),
      ],
    ),
  );
}
