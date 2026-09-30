import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../state/game_model.dart';

/// 每隔 GameModel.uiTick 重畫一次（倒數、奶桶、遊戲時鐘）。uiTick 是 null（測試）就不重畫。
class TickerBuilder extends StatefulWidget {
  const TickerBuilder({super.key, required this.builder});
  final WidgetBuilder builder;

  @override
  State<TickerBuilder> createState() => _TickerBuilderState();
}

class _TickerBuilderState extends State<TickerBuilder> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final tick = context.read<GameModel>().uiTick;
    if (tick != null) {
      _timer = Timer.periodic(tick, (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
