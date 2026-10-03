// S01 啟動與載入（design/m2/src/js/screens/s01.js、screens.css 的 .splash）：天空、太陽、遊戲名、兩頭牛、草地，
// 下面的框放這個狀態要說的話（載入中、建立牧場中、載入失敗）。位置都照手機整個螢幕的高度算（--H），天空延伸到狀態列下面。
// S13-04「牧場已經刪除了」只有天空和遊戲名，框在遊戲名下面（[scenery] false）。
// S14-01 第一次打開（開新牧場／找回我的牧場）是同一個場景，沒有草地上的小草小花和版本號（[deco]、[version] false）。
// S16-01 維護中用同一套天空、標題和草地（[MaintenanceScreen]）。
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../../version.dart';
import '../kit/app_icon.dart';
import '../kit/cow_art.dart';
import '../kit/kit.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.child, this.scenery = true, this.deco = true, this.version = true});

  /// 框裡的內容（S01-01 啟動畫面沒有）。
  final Widget? child;

  /// 太陽、兩頭牛、草地和版本號。沒有的話（S13-04）框在 H × 0.2 + 100，緊接在遊戲名下面。
  final bool scenery;

  /// 草地上的小草、小花（s01.js 的 splash-deco；有 [scenery] 才有；S14-01 沒有）。
  final bool deco;

  /// 最下面的版本號（有 [scenery] 才有；S14-01 沒有）。
  final bool version;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final s = Strings.of(context);
    final w = mq.size.width, h = mq.size.height, top = h * 0.2;
    // 版本號一律在框的下面；框太高（英文、泰文的窄手機）時整頁可以捲（ceo 2026-10-02）
    return ColoredBox(
      color: AppColors.cream,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: h),
          child: IntrinsicHeight(
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                // 天空的漸層照一個畫面的高度算；整頁變長時，多出來的部分是草地
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: h,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF94D3FF), Color(0xFFC4E9FF), Color(0xFFE4F6FF)],
                        stops: [0, 0.42, 0.6],
                      ),
                    ),
                  ),
                ),
                if (scenery) Positioned(right: 36, top: mq.padding.top + 40, child: const _Sun()),
                Positioned(
                  left: 0,
                  right: 0,
                  top: top,
                  // 一行放不下（英文、泰文）就把字縮小到放得下；繁中放得下，不會變（ceo 2026-10-02）
                  child: Center(
                    child: FittedBox(fit: BoxFit.scaleDown, child: _Title(s.appTitle)),
                  ),
                ),
                // 草地：比畫面左右各寬 20，上緣是一道弧
                if (scenery) Positioned(left: -20, right: -20, top: top + 222, bottom: -20, child: const _Ground()),
                if (scenery && deco)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: top + 222,
                    bottom: 0,
                    child: CustomPaint(painter: _GrassPainter(w)),
                  ),
                if (scenery)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: top + 78,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        CowPicture(breed: 'holstein', width: 150, height: 150),
                        // margin-left: -18px：小牛疊在大牛右邊 18，整組（228 寬）置中
                        SizedBox(
                          width: 96 - 18,
                          height: 96,
                          child: OverflowBox(
                            maxWidth: 96,
                            alignment: Alignment.centerRight,
                            child: CowPicture(
                              breed: 'yellow',
                              bull: true,
                              calf: true,
                              right: true,
                              width: 96,
                              height: 96,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // 框在 H × 0.2 + 262（S13-04：+ 100）；版本號平常在最下面（安全區上面 12），框太高時接在框下面
                Column(
                  children: [
                    SizedBox(height: top + (scenery ? 262 : 100)),
                    if (child != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: child),
                    const Spacer(),
                    if (scenery && version) ...[
                      const SizedBox(height: 12),
                      Text(
                        s.s01Version(v: appVersion),
                        key: const Key('app-version'),
                        textAlign: TextAlign.center,
                        style: AppText.style(12, weight: FontWeight.w700, color: const Color(0xFF3F7A3A)),
                      ),
                    ],
                    SizedBox(height: mq.padding.bottom + 12),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// S16-01 伺服器維護中（s13.js 的 maint；screens.css 的 .tool-badge、.maint-time）：天空、「維護中」、牛和扳手圓章、草地，
/// 下面一張卡：「伺服器正在維護」、預計恢復的時間、說明、「重新整理」。位置照整個螢幕的高度算，從 H × 0.12 起。
/// 預計恢復的那一行：過了時間還在維護換成「比預計的時間晚一點，請再等一下」（S16-04）；沒有時間就不顯示（S16-05）。
class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key, this.ends, this.late = false, required this.onReload});

  /// 預計恢復的時間（手機的時區）；null 是沒有預計時間。
  final DateTime? ends;

  /// 已經過了預計恢復的時間。
  final bool late;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final s = Strings.of(context);
    final h = mq.size.height, top = h * 0.12;
    final ends = this.ends;
    final eta = late ? s.s16Late : (ends == null ? null : s.maintenanceEta(ends));
    return ColoredBox(
      key: const Key('maintenance'),
      color: AppColors.cream,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: h),
          child: IntrinsicHeight(
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: h,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF94D3FF), Color(0xFFC4E9FF), Color(0xFFE4F6FF)],
                        stops: [0, 0.42, 0.6],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: top,
                  child: Center(
                    child: FittedBox(fit: BoxFit.scaleDown, child: _Title(s.s16Title, size: 36)),
                  ),
                ),
                Positioned(left: -20, right: -20, top: top + 202, bottom: -20, child: const _Ground()),
                // 牛 140×140，右邊疊一個扳手圓章（往左 24、離底 18）；整組置中、靠底對齊
                Positioned(
                  left: 0,
                  right: 0,
                  top: top + 70,
                  child: const Center(
                    child: SizedBox(
                      width: 140 + 64 - 24,
                      height: 140,
                      child: Stack(
                        children: [
                          Positioned(left: 0, bottom: 0, child: CowPicture(breed: 'holstein', width: 140, height: 140)),
                          Positioned(left: 140 - 24, bottom: 18, child: _ToolBadge()),
                        ],
                      ),
                    ),
                  ),
                ),
                Column(
                  children: [
                    SizedBox(height: top + 236),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: AppCard(
                        key: const Key('maintenance-card'),
                        child: Column(
                          children: [
                            // <b> 在一般的 div 裡：字 18、行高 26
                            Text(
                              s.s16Lead,
                              textAlign: TextAlign.center,
                              style: AppText.style(18, weight: FontWeight.w700, lineHeight: 26),
                            ),
                            if (eta != null)
                              Padding(
                                key: const Key('maintenance-eta'),
                                padding: const EdgeInsets.only(top: 6, bottom: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const AppIcon('clock', size: 18),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        eta,
                                        textAlign: TextAlign.center,
                                        style: AppText.style(15, weight: FontWeight.w900),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Text(s.s16Body, textAlign: TextAlign.center, style: KitText.hint()),
                            const SizedBox(height: 12),
                            AppButton(
                              s.reload,
                              key: const Key('maintenance-reload'),
                              kind: ButtonKind.primary,
                              block: true,
                              icon: 'refresh',
                              onPressed: onReload,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(height: mq.padding.bottom + 12),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// .tool-badge：64×64 的白色圓章（框 3、下陰影 3），中間一支 44 的扳手。
class _ToolBadge extends StatelessWidget {
  const _ToolBadge();

  @override
  Widget build(BuildContext context) => Container(
    width: 64,
    height: 64,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white,
      border: Border.all(color: AppColors.ink, width: AppSizes.border),
      boxShadow: AppShadows.solid(3),
    ),
    child: const AppIcon('tools', size: 44),
  );
}

class _Sun extends StatelessWidget {
  const _Sun();

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFFFFE58A),
      border: Border.all(color: AppColors.ink, width: AppSizes.border),
      // box-shadow: 0 0 0 10px rgba(255, 229, 138, 0.35)：外面一圈淡淡的光
      boxShadow: const [BoxShadow(color: Color.fromRGBO(255, 229, 138, 0.35), spreadRadius: 10)],
    ),
  );
}

/// 遊戲名：白字、8px 可可色描邊（描邊在下、字在上，看起來外圈 4px）、往下 5px 的實心影子。
class _Title extends StatelessWidget {
  const _Title(this.text, {this.size = 44});

  final String text;

  /// 字級（S16-01 維護中是 36；行高照樣 56）。
  final double size;

  @override
  Widget build(BuildContext context) {
    TextStyle style(Paint? fg) => AppText.style(
      size,
      weight: FontWeight.w900,
      color: Colors.white,
      lineHeight: 56,
      letterSpacing: 4,
    ).copyWith(color: fg == null ? Colors.white : null, foreground: fg);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.ink;
    return Padding(
      key: const Key('game-title'),
      // CSS 的 padding: 0 8px。字距 4：Chrome 加在每個字後面，Flutter 前後各加一半（第一個字往右 2），左右各挪 2 對回 Chrome
      padding: const EdgeInsets.only(left: 8 - 2, right: 8 + 2),
      child: Stack(
        children: [
          Transform.translate(
            offset: const Offset(0, 5),
            child: Text(text, style: style(stroke), textAlign: TextAlign.center),
          ),
          Text(text, style: style(stroke), textAlign: TextAlign.center),
          Text(text, style: style(null), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _Ground extends StatelessWidget {
  const _Ground();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      // border-radius: 50% 50% 0 0 / 28px 28px 0 0
      final r = Radius.elliptical(c.maxWidth / 2, 28);
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFAEE594),
          border: const Border(
            top: BorderSide(color: AppColors.ink, width: AppSizes.border),
          ),
          borderRadius: BorderRadius.only(topLeft: r, topRight: r),
        ),
      );
    },
  );
}

/// 草地上的草叢和小花（s01.js 的 deco，R1-A 場景的畫法）。座標系是 [width]×400。
class _GrassPainter extends CustomPainter {
  _GrassPainter(this.width);

  final double width;

  static const _tufts = [
    (0.08, 40.0), (0.22, 92.0), (0.4, 30.0), (0.62, 70.0), (0.86, 36.0), (0.93, 118.0), //
    (0.14, 170.0), (0.5, 150.0), (0.74, 196.0), (0.3, 236.0), (0.88, 260.0), (0.06, 300.0),
  ];
  static const _flowers = [
    (0.18, 58.0, Colors.white), (0.78, 52.0, Color(0xFFFFC2D4)), (0.56, 112.0, Color(0xFFFFE08A)), //
    (0.1, 128.0, Color(0xFFFFC2D4)), (0.84, 170.0, Colors.white), (0.36, 196.0, Color(0xFFFFE08A)),
    (0.66, 250.0, Colors.white),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const k = 1.1;
    final grass = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF6FBF5E);
    for (final (fx, y) in _tufts) {
      final x = fx * width;
      // M x−6k,y q2k,−6k 3k,−7k q k,4k 3k,7k q1.5k,−5k 3k,−8k q k,5k 3k,8k
      final p = Path()..moveTo(x - 6 * k, y);
      void q(double cx, double cy, double dx, double dy) => p.relativeQuadraticBezierTo(cx * k, cy * k, dx * k, dy * k);
      q(2, -6, 3, -7);
      q(1, 4, 3, 7);
      q(1.5, -5, 3, -8);
      q(1, 5, 3, 8);
      canvas.drawPath(p, grass);
    }
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppColors.ink;
    for (final (fx, y, c) in _flowers) {
      final x = fx * width;
      for (var i = 0; i < 5; i++) {
        final a = i / 5 * math.pi * 2 - math.pi / 2;
        final o = Offset(x + math.cos(a) * 3.3, y + math.sin(a) * 3.3);
        canvas.drawCircle(o, 2.6, Paint()..color = c);
        canvas.drawCircle(o, 2.6, line..strokeWidth = 1.2);
      }
      canvas.drawCircle(Offset(x, y), 2.2, Paint()..color = const Color(0xFFFFD04D));
      canvas.drawCircle(Offset(x, y), 2.2, line..strokeWidth = 1.1);
    }
  }

  @override
  bool shouldRepaint(_GrassPainter oldDelegate) => oldDelegate.width != width;
}
