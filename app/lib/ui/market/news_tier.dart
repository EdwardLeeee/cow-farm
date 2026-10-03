// D33 新聞分級的共用元件（設計稿 s06.js 的 tierTag、tierBadge、pctText、newsIcons、newsPin；screens.css 的 .badge.sup／.swan、
// .news-pin、.np-*、.bn-ic）：市場的新聞卡（S06-14、S06-17）和牧場頁的大新聞提示（S03-15～17、S03-22～24）共用。
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../l10n/format.dart';
import '../../l10n/l10n.dart';
import '../../state/game_model.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../kit/app_icon.dart';
import '../kit/kit.dart';
import 'market_page.dart' show agoText;

/// 超級黑天鵝的深色（.badge.swan 的底；深色大卡上白底標籤的字）。
const kSwanInk = Color(0xFF2F2A35);

/// 深色卡片的框和下陰影（.news-pin.swan、.big-news.swan）。
const kSwanLine = Color(0xFF17141B);

/// 超級大事件的金色標籤（.badge.sup、.big-news.sup .bn-tag）：由上往下的漸層。
const kSuperTagGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFFFE98F), Color(0xFFFFC13B)],
);

/// 幅度：全幅的 pct（+100%、−90%、+25%）。
String newsPctText(NewsItem n) => '${n.pct >= 0 ? '+' : '−'}${(n.pct.abs() * 100).round()}%';

/// 深色卡上「跌」的顏色（S03-23、S06-17 的 −90%）：設計稿是淺綠 #7BE0A6（漲紅跌綠）。
/// 綠漲紅跌時（S13-18）設計稿沒畫，用一樣亮的淺紅。
Color crashPctColor({required bool upIsRed}) => upIsRed ? const Color(0xFF7BE0A6) : const Color(0xFFEF8F93);

/// .badge.sup／.badge.swan：「✦ 超級大事件」「（天鵝）超級黑天鵝」。[onDark] 是深色卡上的（白底、深色字和框）。
/// [prompt] 是牧場頁提示的標籤（.big-news.sup／.swan .bn-tag：字 13、行高 22、左右 8、圖示和字隔 3、圓角 10）。
class NewsTierBadge extends StatelessWidget {
  const NewsTierBadge({super.key, required this.tier, this.onDark = false, this.prompt = false});

  final NewsTier tier;
  final bool onDark;
  final bool prompt;

  /// 標籤裡的字（.badge 12／18；提示的 13／22）。
  static TextStyle textStyle({required bool prompt, Color color = AppColors.ink}) =>
      AppText.style(prompt ? 13 : 12, weight: FontWeight.w900, color: color, lineHeight: prompt ? 22 : 18);

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final sup = tier == NewsTier.superUp;
    final fg = sup ? AppColors.ink : (onDark ? kSwanInk : Colors.white);
    return Container(
      key: Key('tier-${tier.wire}'),
      height: prompt ? 26 : 22,
      padding: EdgeInsets.symmetric(horizontal: prompt ? 8 : 7),
      decoration: BoxDecoration(
        gradient: sup ? kSuperTagGradient : null,
        color: sup ? null : (onDark ? Colors.white : kSwanInk),
        border: Border.all(color: onDark ? Colors.white : AppColors.ink, width: 2),
        borderRadius: BorderRadius.all(Radius.circular(prompt ? 10 : 11)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sup) const AppIcon('sparkle', size: 13) else AppIcon('swan', size: 15, color: fg),
          SizedBox(width: prompt ? 3 : 2),
          Text(
            sup ? s.s06SuperTag : s.s06SwanTag,
            softWrap: false,
            style: textStyle(prompt: prompt, color: fg),
          ),
        ],
      ),
    );
  }
}

/// .bn-ic／.np-ic：52 的白色圓角框，一種商品放大圖示（34），三種一起放上兩個、下一個（22）。
/// CSS 寫 2.5px 的框，boards 量出來是 2（Chrome 畫成 2px）；照核准的 boards。
class NewsIconBox extends StatelessWidget {
  const NewsIconBox({super.key, required this.commodity});

  /// null 是三種商品一起。
  final Commodity? commodity;

  @override
  Widget build(BuildContext context) {
    final c = commodity;
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: const BorderRadius.all(AppRadii.r16),
      ),
      child: c == null
          ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [AppIcon('milk', size: 22), SizedBox(width: 2), AppIcon('beef', size: 22)],
                ),
                AppIcon('rice', size: 22),
              ],
            )
          : AppIcon(c.wire, size: 34),
    );
  }
}

/// .news-pin：進行中的超級大事件、超級黑天鵝，釘在新聞卡最上面的大卡（S06-17）。
/// 上面一列：級別標籤、商品標籤、多久以前；下面：商品圖示、專屬標題、大字的幅度和兩行說明。
/// 超級大事件金色底、右上角有白色的光；超級黑天鵝深色底、白字、幅度用淺色的「跌」。
class NewsPinCard extends StatelessWidget {
  const NewsPinCard({super.key, required this.news});

  final NewsItem news;

  static const _radius = BorderRadius.all(Radius.circular(18));

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final m = context.watch<GameModel>();
    final upIsRed = context.watch<SettingsController>().upIsRed;
    final swan = news.tier == NewsTier.crash;
    final fg = swan ? Colors.white : AppColors.ink;
    final line = swan ? kSwanLine : AppColors.ink;
    final c = news.commodity;
    final up = news.pct >= 0;
    final sub = c == null
        ? (up ? s.s06PinUpAll : s.s06PinDownAll)
        : '${up ? s.s06PinUp(name: s.commodity(c)) : s.s06PinDown(name: s.commodity(c))}\n'
              '${s.s06PinNow(price: priceText(m.market?.quotes[c]?.price ?? 0), unit: s.unitOf(c))}';
    return Container(
      key: Key('news-pin-${news.id}'),
      decoration: BoxDecoration(
        borderRadius: _radius,
        boxShadow: [BoxShadow(color: line, offset: const Offset(0, 3))],
      ),
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: line, width: 3),
        borderRadius: _radius,
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: CustomPaint(
          painter: NewsTierBackground.pin(swan: swan),
          child: Padding(
            // padding 8 12 12，加上框 3
            padding: const EdgeInsets.fromLTRB(15, 11, 15, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // .np-top
                Row(
                  children: [
                    NewsTierBadge(tier: news.tier, onDark: swan),
                    const SizedBox(width: 6),
                    Text(
                      s.newsTag(news),
                      softWrap: false,
                      style: AppText.style(13, weight: FontWeight.w900, color: fg),
                    ),
                    const Spacer(),
                    const SizedBox(width: 6),
                    Text(
                      agoText(s, m, news.time),
                      softWrap: false,
                      style: AppText.style(
                        12,
                        weight: FontWeight.w700,
                        color: swan ? const Color(0xFFCFC6DA) : AppColors.ink2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // .np-main
                Row(
                  children: [
                    NewsIconBox(commodity: c),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.newsHeadline(news),
                            style: AppText.style(16, weight: FontWeight.w900, color: fg, lineHeight: 22),
                          ),
                          const SizedBox(height: 4),
                          // .np-fx：大字的幅度、兩行說明
                          Row(
                            children: [
                              Text(
                                newsPctText(news),
                                key: const Key('news-pin-pct'),
                                softWrap: false,
                                style: AppText.number(
                                  28,
                                  lineHeight: 32,
                                  color: swan ? crashPctColor(upIsRed: upIsRed) : AppColors.up(upIsRed: upIsRed),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // .np-sub：13／18 的兩行，照 Chrome 的基線（Flutter 低 0.7）
                              Expanded(
                                child: CssParagraph(
                                  TextSpan(text: sub),
                                  style: AppText.style(
                                    13,
                                    weight: FontWeight.w700,
                                    color: swan ? const Color(0xFFE5DEEE) : AppColors.ink2,
                                    lineHeight: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

/// 超級大事件、超級黑天鵝卡片的底（.news-pin、.big-news 的 .sup／.swan）：照 CSS 的算法畫，跟卡片的大小有關，所以自己畫。
/// 超級大事件是放射狀的金色（circle at [center]，半徑到最遠的角，#FFFBE6 0、#FFE58A [mid]、#FFD45E 100%）；
/// [rays] 加右上角 16 道白光（.np-rays）。超級黑天鵝是 160 度的深色漸層。
class NewsTierBackground extends CustomPainter {
  const NewsTierBackground({required this.swan, required this.center, required this.mid, this.rays = false});

  /// 新聞卡的大卡（.news-pin）。
  const NewsTierBackground.pin({required bool swan})
    : this(swan: swan, center: const Offset(0.88, 0.10), mid: 0.55, rays: true);

  /// 牧場頁的提示（.big-news）。
  const NewsTierBackground.prompt({required bool swan}) : this(swan: swan, center: const Offset(0.85, 0), mid: 0.60);

  final bool swan;

  /// 放射的中心（寬、高的比例）。
  final Offset center;
  final double mid;
  final bool rays;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (swan) {
      canvas.drawRect(
        rect,
        Paint()..shader = cssLinearGradient(size, 160, const [Color(0xFF3A3342), Color(0xFF221E27)]),
      );
      return;
    }
    final c = Offset(size.width * center.dx, size.height * center.dy);
    // farthest-corner：四個角裡離中心最遠的
    final r = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ].map((p) => (p - c).distance).reduce(math.max);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          r,
          const [Color(0xFFFFFBE6), Color(0xFFFFE58A), Color(0xFFFFD45E)],
          [0, mid, 1],
        ),
    );
    if (!rays) return;
    // .np-rays：170 × 170 的 SVG（viewBox −50…50），右 −46、上 −54，不透明度 0.6；16 道白色三角形，各寬 11.2 度、長 60
    const box = 170.0, k = box / 100;
    final origin = Offset(size.width + 46 - box / 2, -54 + box / 2);
    canvas.save();
    canvas.clipRect(Rect.fromCenter(center: origin, width: box, height: box));
    Offset p(double deg) {
      final a = deg * math.pi / 180;
      return origin + Offset(60 * math.cos(a), 60 * math.sin(a)) * k;
    }

    final path = Path();
    for (var i = 0; i < 16; i++) {
      final a = i * 22.5;
      final p1 = p(a - 5.6), p2 = p(a + 5.6);
      path
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.6));
    canvas.restore();
  }

  @override
  bool shouldRepaint(NewsTierBackground old) =>
      old.swan != swan || old.center != center || old.mid != mid || old.rays != rays;
}

/// CSS 的 linear-gradient([deg]deg, …)：0 度朝上、順時針；漸層線經過中心，長度是 |W sin| + |H cos|。
ui.Gradient cssLinearGradient(Size size, double deg, List<Color> colors, [List<double>? stops]) {
  final a = deg * math.pi / 180;
  final dir = Offset(math.sin(a), -math.cos(a));
  final len = (size.width * math.sin(a)).abs() + (size.height * math.cos(a)).abs();
  final c = size.center(Offset.zero);
  return ui.Gradient.linear(c - dir * (len / 2), c + dir * (len / 2), colors, stops);
}
