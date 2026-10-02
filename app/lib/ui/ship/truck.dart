// 出貨卡車的造型（A-03）：零件的圖和量測。之後可能有不同造型（使用者在考慮「卡車造型可以用遊戲幣買」，
// ceo 2026-10-03），動畫只認 TruckSkin，不寫死哪一台卡車。
// 預設的卡車是 cow-ui 匯出的 assets/ui/parts/truck_*.svg，量測在 assets/ui/ui.json 的 anchors.truck（卡車自己的座標）：
// - back 畫在牛後面；front 畫在牛前面（不含車身上的牧場名、擋板、輪子，這三樣另外畫）。
// - 每個零件的範圍讀 SVG 的 viewBox：車身、擋板就是卡車座標；輪子的圖以 wheelSvgOrigin 為中心，畫到每個輪子的位置。
import 'dart:convert';

import 'package:flutter/services.dart';

import 'truck_motion.dart';

/// 卡車車身上寫牧場名（ui.json 的 namePlate）：基線在 (x, y)，置中。
class TruckNamePlate {
  const TruckNamePlate({required this.at, required this.size, required this.weight, required this.color});

  final Offset at;
  final double size;
  final int weight;
  final Color color;
}

/// 倒車燈（ui.json 的 reverseLight）：倒車時一閃一閃，亮的時候疊一個亮色的方塊。
class TruckLight {
  const TruckLight({required this.rect, required this.on, required this.off});

  final Rect rect;
  final Color on;
  final Color off;
}

/// 一台卡車。
class TruckSkin {
  const TruckSkin({
    required this.back,
    required this.front,
    required this.wheel,
    required this.gate,
    required this.backBox,
    required this.frontBox,
    required this.wheelBox,
    required this.gateBox,
    required this.geometry,
    required this.wheels,
    required this.hinge,
    required this.gateOpenDeg,
    required this.namePlate,
    required this.light,
  });

  /// 零件的圖（asset 路徑）。
  final String back, front, wheel, gate;

  /// 零件的範圍：車身、擋板是卡車座標；輪子是以輪子中心為 (0, 0) 的座標。
  final Rect backBox, frontBox, wheelBox, gateBox;

  final TruckGeometry geometry;

  /// 輪子的中心（卡車座標）。
  final List<Offset> wheels;

  /// 擋板的軸（卡車座標），打開時轉 [gateOpenDeg] 度。
  final Offset hinge;
  final double gateOpenDeg;

  final TruckNamePlate namePlate;
  final TruckLight light;

  static TruckSkin? _default;

  /// 預設的卡車（讀過一次就記住）。
  static Future<TruckSkin> loadDefault([AssetBundle? bundle]) async =>
      _default ??= await load(bundle ?? rootBundle, prefix: 'assets/ui/parts/truck_');

  /// 讀一台卡車：零件是 [prefix]back.svg、front.svg、wheel.svg、tailgate.svg，量測在 ui.json 的 anchors.truck。
  static Future<TruckSkin> load(AssetBundle bundle, {required String prefix}) async {
    final anchors = (jsonDecode(await bundle.loadString('assets/ui/ui.json')) as Map)['anchors'] as Map;
    final t = (anchors['truck'] as Map).cast<String, dynamic>();
    Future<Rect> box(String path) async => _viewBox(await bundle.loadString(path));
    double d(Object? v) => (v as num).toDouble();
    Offset pt(Object? v) => Offset(d((v as List)[0]), d(v[1]));
    Color color(String hex) => Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));

    final paths = (
      back: '${prefix}back.svg',
      front: '${prefix}front.svg',
      wheel: '${prefix}wheel.svg',
      gate: '${prefix}tailgate.svg',
    );
    final origin = pt(t['wheelSvgOrigin']);
    final size = t['size'] as List;
    final plate = (t['namePlate'] as Map).cast<String, dynamic>();
    final light = (t['reverseLight'] as Map).cast<String, dynamic>();
    return TruckSkin(
      back: paths.back,
      front: paths.front,
      wheel: paths.wheel,
      gate: paths.gate,
      backBox: await box(paths.back),
      frontBox: await box(paths.front),
      wheelBox: (await box(paths.wheel)).shift(-origin),
      gateBox: await box(paths.gate),
      geometry: TruckGeometry(
        size: Size(d(size[0]), d(size[1])),
        wheelR: d(t['wheelR']),
        floor: d(t['floor']),
        bedCx: d(t['bedCx']),
      ),
      wheels: [for (final w in t['wheels'] as List) pt(w)],
      hinge: pt(t['hinge']),
      gateOpenDeg: d(t['gateOpenDeg']),
      namePlate: TruckNamePlate(
        at: Offset(d(plate['x']), d(plate['y'])),
        size: d(plate['size']),
        weight: (plate['weight'] as num).toInt(),
        color: color(plate['color'] as String),
      ),
      light: TruckLight(
        rect: Rect.fromLTWH(d(light['x']), d(light['y']), d(light['w']), d(light['h'])),
        on: color(light['on'] as String),
        off: color(light['off'] as String),
      ),
    );
  }

  /// SVG 的 viewBox（「x y 寬 高」）。
  static Rect _viewBox(String svg) {
    final m = RegExp(r'viewBox="([-\d.]+)[ ,]+([-\d.]+)[ ,]+([-\d.]+)[ ,]+([-\d.]+)"').firstMatch(svg);
    if (m == null) throw FormatException('沒有 viewBox', svg.substring(0, svg.length.clamp(0, 80)));
    final v = [for (var i = 1; i <= 4; i++) double.parse(m.group(i)!)];
    return Rect.fromLTWH(v[0], v[1], v[2], v[3]);
  }
}
