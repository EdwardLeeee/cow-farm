// 牛的圖：cow-ui 從設計稿的牛產生器匯出的 SVG（app/assets/cows/，T3：執行時讀，不在建置時轉）。
// 擺法照設計稿 design/m2/src/js/kit.js 的 cowSVG：整隻牛縮放到放得進 w×h（四邊留 pad），腳底貼齊底下的留邊、左右置中。
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 一張牛圖的量測（cows.json 的 images）：SVG 的 viewBox 原點在腳底中間，往上是負的；四邊各留 4。
class CowImageMeta {
  const CowImageMeta({required this.w, required this.h, required this.x0, required this.y0, required this.height});
  final double w; // viewBox 寬（含左右各 4 的留邊）
  final double h; // viewBox 高（含上下各 4 的留邊）
  final double x0;
  final double y0;
  final double height; // 牛本身的高（不含留邊）
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
            return CowImageMeta(w: d('w'), h: d('h'), x0: d('x0'), y0: d('y0'), height: d('height'));
          }(),
      },
    );
  }

  /// 圖檔名（不含副檔名）與要不要左右翻。同品種的個體差異：花色 = [variant] 除以花色數的餘數（T3 選項 2）；
  /// 朝右時有自己畫的朝右圖就用，沒有就把朝左的圖翻過來。
  (String, bool) pick({
    required String breed,
    required bool bull,
    required bool calf,
    required bool front,
    required bool right,
    int variant = 0,
  }) {
    final n = _variants[breed] ?? 1;
    final native = right && _right.contains(breed);
    final name =
        '${breed}_${bull ? 'bull' : 'cow'}_${calf ? 'calf' : 'adult'}_${front ? 'front' : 'side'}'
        '_${native ? 'right' : 'left'}_v${variant % n}';
    return (name, right && !native);
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

  @override
  Widget build(BuildContext context) {
    final art = CowArt.instance;
    final (name, mirror) =
        art?.pick(breed: breed, bull: bull, calf: calf, front: front, right: right, variant: variant) ?? ('', false);
    final m = art?.meta(name);
    if (m == null) return SizedBox(width: width, height: height);
    // cowSVG：k = min((w − 2pad) / 牛的寬, (h − 2pad) / 牛的高)；牛的寬 = viewBox 寬 − 左右留邊
    final k = [
      (width - pad * 2) / (m.w - CowArt.margin * 2),
      (height - pad * 2) / m.height,
    ].reduce((a, b) => a < b ? a : b);
    Widget pic = SvgPicture.asset('assets/cows/svg/$name.svg', width: m.w * k, height: m.h * k, fit: BoxFit.fill);
    if (mirror) pic = Transform.flip(flipX: true, child: pic);
    return SizedBox(
      width: width,
      height: height,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 腳底（viewBox 原點）放在 y = h − pad；左右留邊一樣寬，所以整張圖置中
            Positioned(left: (width - m.w * k) / 2, top: height - pad + m.y0 * k, child: pic),
          ],
        ),
      ),
    );
  }
}
