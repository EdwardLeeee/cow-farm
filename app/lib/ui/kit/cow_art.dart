// 牛的圖：cow-ui 從設計稿的牛產生器匯出的 SVG（app/assets/cows/，T3：執行時讀，不在建置時轉）。
// 擺法照設計稿 design/m2/src/js/kit.js 的 cowSVG：整隻牛縮放到放得進 w×h（四邊留 pad），腳底貼齊底下的留邊、左右置中。
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../api/breeds.dart' show kHybrid;
import '../../theme/tokens.dart';

/// 一張牛圖的量測（cows.json 的 images）：SVG 的 viewBox 原點在腳底中間，往上是負的；四邊各留 4。
class CowImageMeta {
  const CowImageMeta({
    required this.w,
    required this.h,
    required this.x0,
    required this.y0,
    required this.height,
    this.face = const (0.0, 0.0, 0.0),
    this.shadow = const (0.0, 0.0, 0.0),
    this.headTop = Offset.zero,
  });
  final double w; // viewBox 寬（含左右各 4 的留邊）
  final double h; // viewBox 高（含上下各 4 的留邊）
  final double x0;
  final double y0;
  final double height; // 牛本身的高（不含留邊）

  /// 臉的圓（cx, cy, r）：頭像（cowFace）只畫這個圓裡面。
  final (double, double, double) face;

  /// 腳下影子的橢圓（cx, rx, ry），畫在腳底那一條線上。
  final (double, double, double) shadow;

  /// 頭頂：「奶桶滿了」泡泡、牛的小名片從這裡往上放。
  final Offset headTop;
}

/// cows.json：每個品種有幾種花色（seeds）、有沒有自己畫的朝右圖（right），每張圖的量測。
class CowArt {
  CowArt._(this._variants, this._right, this._images);

  static const margin = 4.0; // 匯出時每邊留的空白（assetexport.mjs 的 PAD）

  final Map<String, int> _variants;
  final Set<String> _right;
  final Map<String, CowImageMeta> _images;

  static CowArt? _instance;

  /// 載入過的 cows.json；還沒載入時是 null（牛的位置照樣留著，只是先不畫）。
  static CowArt? get instance => _instance;

  /// 讀 assets/cows/cows.json。main 和測試在畫畫面之前呼叫一次。
  static Future<CowArt> load([AssetBundle? bundle]) async {
    final existing = _instance;
    if (existing != null) return existing;
    final j = jsonDecode(await (bundle ?? rootBundle).loadString('assets/cows/cows.json')) as Map<String, dynamic>;
    final breeds = (j['breeds'] as Map).cast<String, dynamic>();
    final images = (j['images'] as Map).cast<String, dynamic>();
    return _instance = CowArt._(
      {for (final e in breeds.entries) e.key: ((e.value as Map)['seeds'] as List).length},
      {
        for (final e in breeds.entries)
          if ((e.value as Map)['right'] == true) e.key,
      },
      {
        for (final e in images.entries)
          e.key: () {
            final m = (e.value as Map).cast<String, dynamic>();
            double d(String k) => (m[k] as num).toDouble();
            double n(Object? v, String k) => ((v as Map?)?[k] as num?)?.toDouble() ?? 0;
            return CowImageMeta(
              w: d('w'),
              h: d('h'),
              x0: d('x0'),
              y0: d('y0'),
              height: d('height'),
              face: (n(m['face'], 'cx'), n(m['face'], 'cy'), n(m['face'], 'r')),
              shadow: (n(m['shadow'], 'cx'), n(m['shadow'], 'rx'), n(m['shadow'], 'ry')),
              headTop: Offset(n(m['headTop'], 'x'), n(m['headTop'], 'y')),
            );
          }(),
      },
    );
  }

  /// 圖檔名（不含副檔名）與要不要左右翻。同品種的個體差異：花色 = [variant] 除以花色數的餘數（T3 選項 2）；
  /// 朝右時有自己畫的朝右圖就用，沒有就把朝左的圖翻過來。
  /// [sick]：病牛（v0.3 第 5 節）一律轉正面，用名字後面加 `_sick` 的圖（臉色發青、額頭藍線；cows.json 的 about）。
  (String, bool) pick({
    required String breed,
    required bool bull,
    required bool calf,
    required bool front,
    required bool right,
    int variant = 0,
    bool sick = false,
  }) {
    final n = _variants[breed] ?? 1;
    final native = right && _right.contains(breed);
    final name =
        '${breed}_${bull ? 'bull' : 'cow'}_${calf ? 'calf' : 'adult'}_${front ? 'front' : 'side'}'
        '_${native ? 'right' : 'left'}_v${variant % n}';
    // 病牛的圖只有正面；沒有那張圖（舊的素材）就照一般的畫
    return (sick && front && _images.containsKey('${name}_sick') ? '${name}_sick' : name, right && !native);
  }

  CowImageMeta? meta(String name) => _images[name];
}

/// 一頭牛，畫在固定大小的 [width]×[height] 裡（大小跟圖載入了沒有無關，版面不會跳動）。
class CowPicture extends StatelessWidget {
  const CowPicture({
    super.key,
    required this.breed,
    this.bull = false,
    this.calf = false,
    this.front = true,
    this.right = false,
    this.variant = 0,
    required this.width,
    required this.height,
    this.pad = 4,
    this.sick = false,
  });

  final String breed;
  final bool bull;
  final bool calf;
  final bool front;
  final bool right;
  final int variant;
  final double width;
  final double height;
  final double pad;

  /// 病牛（v0.3 第 5 節）：正面的圖用臉色發青的那張，頭上疊溫度計泡泡（[SickBubble]）。
  final bool sick;

  @override
  Widget build(BuildContext context) {
    final art = CowArt.instance;
    final (name, mirror) =
        art?.pick(breed: breed, bull: bull, calf: calf, front: front, right: right, variant: variant, sick: sick) ??
        ('', false);
    final m = art?.meta(name);
    if (m == null) return SizedBox(width: width, height: height);
    // cowSVG：k = min((w − 2pad) / 牛的寬, (h − 2pad) / 牛的高)；牛的寬 = viewBox 寬 − 左右留邊。
    // 母小牛的高算到蝴蝶結頂（設計稿 kit.js：ch = max(牛的高, 蝴蝶結頂)；#151）：viewBox 上緣（扣掉留邊）就是那裡。
    // 病牛（正面、朝左）的寬算到泡泡的右邊、高算到泡泡頂，牛跟著往左移（x0、x1 的中間放在正中間）
    final bubble = sick && front && !mirror ? SickBubble.of(m) : null;
    final x0 = m.x0 + CowArt.margin;
    final x1 = math.max(m.x0 + m.w - CowArt.margin, bubble?.right ?? double.negativeInfinity);
    final top = math.max(math.max(m.height, -(m.y0 + CowArt.margin)), -(bubble?.top ?? 0));
    final k = math.min((width - pad * 2) / (x1 - x0), (height - pad * 2) / top);
    final feet = Offset(width / 2 - (x0 + x1) / 2 * k, height - pad);
    Widget pic = SvgPicture.asset('assets/cows/svg/$name.svg', width: m.w * k, height: m.h * k, fit: BoxFit.fill);
    if (mirror) pic = Transform.flip(flipX: true, child: pic);
    return SizedBox(
      width: width,
      height: height,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 腳底（viewBox 原點）放在 y = h − pad；左右留邊一樣寬，所以整張圖置中（病牛往左移，讓出泡泡的位置）
            Positioned(
              left: bubble == null ? (width - m.w * k) / 2 : feet.dx + m.x0 * k,
              top: height - pad + m.y0 * k,
              child: pic,
            ),
            if (bubble != null) bubble.positioned(feet, k),
          ],
        ),
      ),
    );
  }
}

/// 病牛頭上的溫度計泡泡（素材 ui/parts/sick_bubble：中心在 (0, 0)、半徑 10，viewBox −12.6 −11 24.6 25.8）。
/// 位置照那張牛圖的 face、headTop（ui.json 的 about；設計稿 sick.js 的 sickBubbleAt）：
/// 中心 (face.cx + 0.9315 × face.r, headTop.y − 0.2 × face.r)、半徑 0.5 × face.r，都是牛圖的座標（原點在腳底）。
class SickBubble {
  const SickBubble._(this.faceX, this.center, this.radius);

  /// 這張牛圖（朝左）的泡泡。
  factory SickBubble.of(CowImageMeta m) {
    final (cx, _, r) = m.face;
    return SickBubble._(cx, Offset(cx + 0.9315 * r, m.headTop.dy - 0.2 * r), 0.5 * r);
  }

  /// 臉的中間（牛圖的 x）。
  final double faceX;
  final Offset center;
  final double radius;

  double get right => center.dx + radius;
  double get top => center.dy - radius;

  /// viewBox 的左上角、寬高（半徑 10 的那一版）。
  static const _box = Rect.fromLTWH(-12.6, -11, 24.6, 25.8);

  /// 泡泡在螢幕上的範圍：腳底在 [feet]、牛圖的 1 單位是 [k] 點。[mirror]：左右翻的圖（朝右），臉在腳底的另一邊，
  /// 泡泡照樣在臉的右上方（設計稿的泡泡不翻）。
  Rect rect(Offset feet, double k, {bool mirror = false}) {
    final s = radius * k / 10;
    final x = mirror ? -faceX + (center.dx - faceX) : center.dx;
    final c = feet + Offset(x, center.dy) * k;
    return Rect.fromLTWH(c.dx + _box.left * s, c.dy + _box.top * s, _box.width * s, _box.height * s);
  }

  Widget positioned(Offset feet, double k) => Positioned.fromRect(
    rect: rect(feet, k),
    child: SvgPicture.asset('assets/ui/parts/sick_bubble.svg', fit: BoxFit.fill, excludeFromSemantics: true),
  );
}

/// 牛的臉（設計稿 kit.js 的 cowFace）：正面的圖只取臉那個圓，畫成 [size]×[size]。頂列的頭像用。
/// 頭像選了雜種牛（[kHybrid]）畫乳牛體型的雜種牛（設計稿的 MIX_LOOK.dairy）。
class CowFace extends StatelessWidget {
  const CowFace({super.key, this.breed = 'holstein', required this.size});

  final String breed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final art = CowArt.instance;
    final look = breed == kHybrid ? 'mixDairy' : breed;
    final (name, _) = art?.pick(breed: look, bull: false, calf: false, front: true, right: false) ?? ('', false);
    final m = art?.meta(name);
    if (m == null) return SizedBox.square(dimension: size);
    final (cx, cy, r) = m.face;
    final k = size / (r * 2);
    return SizedBox.square(
      dimension: size,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // viewBox 的左上角是 (x0, y0)；把臉的圓的左上角 (cx − r, cy − r) 對到 (0, 0)
            Positioned(
              left: (m.x0 - (cx - r)) * k,
              top: (m.y0 - (cy - r)) * k,
              child: SvgPicture.asset('assets/cows/svg/$name.svg', width: m.w * k, height: m.h * k, fit: BoxFit.fill),
            ),
          ],
        ),
      ),
    );
  }
}

/// 牛的淺色剪影（設計稿 kit.js 的 cowSVG 加 sil: true）：整隻牛填 #C2B3A6，中間一個白字、深色描邊的「？」
/// （字級是高的 0.42、基線在高的 0.62、描邊 max(1.5, 高 × 0.03)）。找不到這頭牛（S04-11）、還沒發現的品種（S08-06）用。
/// [CowSilhouette.dark] 是深色的（sil: 'dark'，填 #2A1E1A、沒有「？」）：圖鑑還沒發現的品種（S09）、帳號失效（S15-03）、
/// 配種表還沒配出過的爸媽（S09-08，爸爸是公牛的影子）。
class CowSilhouette extends StatelessWidget {
  const CowSilhouette({
    super.key,
    required this.breed,
    this.bull = false,
    this.calf = false,
    required double size,
    this.pad = 4,
  }) : width = size,
       height = size,
       front = true,
       dark = false;

  const CowSilhouette.dark({
    super.key,
    required this.breed,
    this.bull = false,
    required this.width,
    required this.height,
    this.front = true,
    this.pad = 4,
  }) : calf = false,
       dark = true;

  final String breed;
  final bool bull;
  final bool calf;
  final double width;
  final double height;
  final bool front;
  final double pad;
  final bool dark;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: Stack(
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(dark ? const Color(0xFF2A1E1A) : const Color(0xFFC2B3A6), BlendMode.srcIn),
          child: CowPicture(breed: breed, bull: bull, calf: calf, front: front, width: width, height: height, pad: pad),
        ),
        if (!dark) Positioned.fill(child: CustomPaint(painter: _QuestionMark(height))),
      ],
    ),
  );
}

class _QuestionMark extends CustomPainter {
  _QuestionMark(this.h);

  final double h;

  @override
  void paint(Canvas canvas, Size size) {
    final style = AppText.style((h * 0.42).roundToDouble(), weight: FontWeight.w900);
    // paint-order: stroke：先畫描邊、再把白字蓋上去
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, h * 0.03)
      ..color = AppColors.ink2;
    for (final s in [style.copyWith(foreground: stroke), style.copyWith(color: const Color(0xFFFFFFFF))]) {
      final p = TextPainter(
        text: TextSpan(text: '？', style: s),
        textDirection: TextDirection.ltr,
      )..layout();
      final base = p.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      p.paint(canvas, Offset((size.width - p.width) / 2, h * 0.62 - base));
      p.dispose();
    }
  }

  @override
  bool shouldRepaint(_QuestionMark oldDelegate) => oldDelegate.h != h;
}
