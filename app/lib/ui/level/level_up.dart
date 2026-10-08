// S11-01 場主升級慶祝（設計稿 s10.js 的 levelUp；screens.css 的 .lv-wrap、.confetti、.lv-card、.lv-ribbon、.lv-big）：
// 暗幕、彩紙、中間一張卡（「場主升級」彩帶、Lv 5、累積收入到 7,500 幣了！、說明、「好」）。沒有獎勵，只有慶祝（D24）。
// 開著動畫時播 A-05（設計稿 anims.js 的 A05，1.3 秒）：暗幕變暗、卡片彈出來、等級數字從 4 翻成 5（頂列的等級同時換）、
// 彩紙落下，停在最後一格等「好」：最後一格跟 S11-01 一樣（#178）。減少動態：直接是最後一格，整個淡入 0.2 秒。
// 沒開動畫（測試）是 S11-01 的靜態樣子。兩位數（Lv 10 以上）是 S11-07。
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/format.dart';
import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../kit/fly.dart';
import '../kit/frame.dart';
import '../kit/kit.dart';
import '../kit/motion.dart';

/// 升到 [level] 級的慶祝；[levelAt] 是這一級的門檻（累積收入）。
class LevelUpOverlay extends StatefulWidget {
  const LevelUpOverlay({super.key, required this.level, required this.levelAt, required this.onOk});

  final int level;
  final num levelAt;
  final VoidCallback onOk;

  @override
  State<LevelUpOverlay> createState() => _LevelUpOverlayState();
}

/// 怎麼出現：S11-01 的靜態樣子（沒開動畫）、播 A-05、減少動態（A-05 的最後一格淡入）。
enum _Play { still, anim, reduced }

class _LevelUpOverlayState extends State<LevelUpOverlay> with SingleTickerProviderStateMixin {
  /// A-05 的長度（秒）。
  static const _dur = 1.3;

  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))
    ..addListener(_tickHud);
  _Play? _play;

  /// 頂列（A-05 改等級那一份）；[_hudOld] 是頂列現在顯示升級前的等級，[_hudSent] 是正式通知過頂列了。
  HudFxNotifier? _hud;
  bool _hudOld = false, _hudSent = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_play != null) return;
    if (AppMotion.read(context)) {
      _play = _Play.anim;
      _hud = HudFxScope.read(context)?.notifier;
      // 伺服器的等級剛變，這一格頂列本來就要重畫：先悄悄換成升級前的（畫面正在建，不能叫頂列重畫），第一格動畫再正式換
      _hud?.edit((fx) => fx.withLevel(widget.level - 1, xp: 1), quiet: true);
      _hudOld = true;
      _anim.forward();
    } else if (AppMotion.reducedRead(context)) {
      _play = _Play.reduced;
    } else {
      _play = _Play.still;
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    // 數字還沒翻過去就按了「好」：下一格把頂列換回伺服器的等級（這一格還在拆畫面，不能改）
    if (_hudOld) {
      final hud = _hud;
      WidgetsBinding.instance.addPostFrameCallback((_) => hud?.edit((fx) => fx.withLevel(null)));
    }
    super.dispose();
  }

  /// 頂列的等級和經驗條：卡片的數字翻到一半（f ≥ 0.5）以前是升級前的等級、經驗條是滿的，之後照伺服器的。
  void _tickHud() {
    if (_play != _Play.anim) return;
    final old = animInOut(animSeg(_anim.value * _dur, 0.4, 0.65)) < 0.5;
    if (old == _hudOld && _hudSent) return;
    _hudOld = old;
    _hudSent = true;
    _hud?.edit((fx) => old ? fx.withLevel(widget.level - 1, xp: 1) : fx.withLevel(null));
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Positioned.fill(
      key: const Key('level-up'),
      child: switch (_play) {
        _Play.anim => AnimatedBuilder(animation: _anim, builder: (context, _) => _layer(s, _anim.value * _dur)),
        // 減少動態：A-05 的最後一格（就是 S11-01）淡入
        _Play.reduced => FadeIn(child: _layer(s, null)),
        _ => _layer(s, null),
      },
    );
  }

  /// 彩紙的顏色（設計稿的五色）。
  static const _colors = [
    Color(0xFFFFD45E),
    Color(0xFFFF9784),
    Color(0xFFA9DBFF),
    Color(0xFFBDE8A6),
    Color(0xFFFFD0DE),
  ];

  /// A-05 第 [t] 秒的樣子；null 是 S11-01 的靜態樣子。
  Widget _layer(Strings s, double? t) => LayoutBuilder(
    builder: (context, c) {
      final w = c.maxWidth, h = c.maxHeight;
      final card = _LevelCard(
        number: t == null
            ? Text('${widget.level}', key: const Key('level-up-lv'), style: AppText.number(76, lineHeight: 88))
            : _LvRoll(from: widget.level - 1, to: widget.level, f: animInOut(animSeg(t, 0.4, 0.65))),
        levelAt: widget.levelAt,
        onOk: widget.onOk,
        s: s,
      );
      return Stack(
        children: [
          // 暗幕：點了不關（要按「好」）；A-05 前 0.2 秒變暗
          Positioned.fill(
            child: ModalBarrier(
              color: t == null
                  ? AppColors.backdrop
                  : AppColors.backdrop.withValues(alpha: AppColors.backdrop.a * animSeg(t, 0, 0.2)),
              dismissible: false,
            ),
          ),
          // .confetti：上面 14% 起、高 40% 的範圍裡 26 片（位置、顏色、角度照設計稿的公式）。
          // A-05：第 0.35 秒起一片晚一點（i % 7 × 0.04 秒）從 −10% 落下、多轉 240 度
          if (t == null || t >= 0.35)
            for (var i = 0; i < 26; i++)
              Positioned(
                key: ValueKey('confetti-$i'),
                left: w * ((i * 37) % 100) / 100,
                top: h * 0.14 + h * 0.4 * _confettiTop(i, t) / 100,
                child: IgnorePointer(
                  child: Transform.rotate(
                    angle: _confettiAngle(i, t) * math.pi / 180,
                    child: Container(
                      width: 10,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _colors[i % 5],
                        border: Border.all(color: AppColors.ink, width: 2),
                        borderRadius: const BorderRadius.all(Radius.circular(3)),
                      ),
                    ),
                  ),
                ),
              ),
          // .lv-wrap：左右留 24，卡片在正中間。A-05：0.05–0.35 秒從 0.4 倍彈到 1 倍（outBack），0.05–0.15 秒淡入
          Positioned.fill(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: t == null
                    ? card
                    : Opacity(
                        opacity: animSeg(t, 0.05, 0.15),
                        child: Transform.scale(
                          scale: t < 0.05 ? 0.4 : 0.4 + 0.6 * animOutBack(animSeg(t, 0.05, 0.35)),
                          child: card,
                        ),
                      ),
              ),
            ),
          ),
        ],
      );
    },
  );

  /// 第 i 片彩紙落了幾成（A-05）。
  static double _confettiFall(int i, double t) => animSeg(t, 0.35 + (i % 7) * 0.04, 1.3);

  /// 第 i 片彩紙的 top（.confetti 高度的 %）：S11-01 是 y = (i × 53) % 46；A-05 從 y − 60 落到 y（最後一格跟 S11-01 一樣）。
  static double _confettiTop(int i, double? t) {
    final y = ((i * 53) % 46).toDouble();
    return t == null ? y : y - 60 * (1 - _confettiFall(i, t));
  }

  /// 第 i 片彩紙的角度：S11-01 是 (i × 29) % 90；A-05 多轉 240 度，落完轉回 S11-01 的角度。
  static double _confettiAngle(int i, double? t) => ((i * 29) % 90) + (t == null ? 0 : (1 - _confettiFall(i, t)) * 240);
}

/// A-05 的 .lv-big .lv-roll：框裡放一個看不到的新數字撐出寬度和基線（「Lv」跟數字的基線對齊、兩位數也放得下，跟 S11-01
/// 一樣），舊的數字往上捲出去、新的從下面捲進來（f：0–1，各移 90）；只切上下（clip-path: inset(0 −24px)）。
class _LvRoll extends StatelessWidget {
  const _LvRoll({required this.from, required this.to, required this.f});

  final int from;
  final int to;
  final double f;

  @override
  Widget build(BuildContext context) {
    final style = AppText.number(76, lineHeight: 88);
    Widget number(int n, double dy, {Key? key}) => Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: Transform.translate(
        offset: Offset(0, dy),
        child: Text('$n', key: key, textAlign: TextAlign.center, softWrap: false, style: style),
      ),
    );
    return ClipRect(
      clipper: const _ClipTopBottom(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // .size：看不到的新數字（螢幕閱讀器也不唸）
          Visibility(
            visible: false,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: Text('$to', style: style),
          ),
          // 翻完就藏起來（設計稿：old 在 f ≥ 1 時 visibility: hidden）；新的還沒開始翻也不唸
          if (f < 1) number(from, -f * 90, key: const Key('level-up-old')),
          if (f > 0) number(to, (1 - f) * 90, key: const Key('level-up-lv')),
        ],
      ),
    );
  }
}

/// clip-path: inset(0 −24px)：只切上下，左右多留 24。
class _ClipTopBottom extends CustomClipper<Rect> {
  const _ClipTopBottom();

  @override
  Rect getClip(Size size) => Rect.fromLTRB(-24, 0, size.width + 24, size.height);

  @override
  bool shouldReclip(_ClipTopBottom oldClipper) => false;
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.number, required this.levelAt, required this.onOk, required this.s});

  /// 大數字：S11-01 是字，A-05 是捲動的框。
  final Widget number;
  final num levelAt;
  final VoidCallback onOk;
  final Strings s;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.topCenter,
    children: [
      AppCard(
        key: const Key('level-card'),
        padding: const EdgeInsets.fromLTRB(16, 30, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // .lv-big：「Lv」和大數字，基線對齊、隔 6
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  s.s11Lv,
                  style: AppText.style(26, weight: FontWeight.w900, color: AppColors.ink2),
                ),
                const SizedBox(width: 6),
                number,
              ],
            ),
            const SizedBox(height: 8),
            Text(
              s.s11Earned(v: fmt(levelAt)),
              textAlign: TextAlign.center,
              style: AppText.style(18, weight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(s.s11Hint, textAlign: TextAlign.center, style: KitText.hint()),
            const SizedBox(height: 14),
            AppButton(s.ok, key: const Key('level-up-ok'), kind: ButtonKind.primary, block: true, onPressed: onOk),
          ],
        ),
      ),
      // .lv-ribbon：卡片上緣往上 20、置中
      Positioned(
        top: -20,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.coral,
            border: Border.all(color: AppColors.ink, width: AppSizes.border),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            boxShadow: AppShadows.solid(3),
          ),
          child: Text(s.s11Ribbon, softWrap: false, style: AppText.style(18, weight: FontWeight.w900)),
        ),
      ),
    ],
  );
}
