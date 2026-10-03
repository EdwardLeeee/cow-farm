// A-03 出貨卡車：每個時間點畫面上的東西在哪裡。照 design/m2/src/js/anims.js 的 A03.frame 逐條移植，
// 只算數字（螢幕座標，點），畫在 truck_scene.dart。卡車的尺寸、輪子、擋板、車斗從卡車造型（TruckSkin）來。
import 'dart:math' as math;
import 'dart:ui';

import '../ranch/walk.dart' show inOut, outBack, seg;

/// 整段 3.6 秒，最後是白光轉場。
const kTruckSeconds = 3.6;

/// 卡車畫成設計稿卡車座標的幾倍（anims.js 的 TS）。
const kTruckScale = 0.86;

double _outCubic(double x) => 1 - math.pow(1 - x, 3).toDouble();
double _lerp(double a, double b, double k) => a + (b - a) * k;

/// 卡車造型的量測（ui.json 的 anchors.truck，卡車自己的座標）。
class TruckGeometry {
  const TruckGeometry({required this.size, required this.wheelR, required this.floor, required this.bedCx});

  final Size size;
  final double wheelR;

  /// 車斗地板的 y。
  final double floor;

  /// 牛站在車斗的哪裡（x）。
  final double bedCx;
}

/// 一個時間點的畫面。
class TruckFrame {
  const TruckFrame({
    required this.truck,
    required this.wheelDeg,
    required this.lightOn,
    required this.gateOpen,
    required this.beeps,
    required this.sideFoot,
    required this.frontBase,
    required this.showFront,
    required this.wave,
    required this.squash,
    required this.sayOpacity,
    required this.sayAt,
    required this.sayScale,
    required this.hearts,
    required this.puffs,
    required this.flash,
  });

  /// 卡車左上角（卡車座標的原點）在螢幕上的位置；卡車畫成 [kTruckScale] 倍。
  final Offset truck;

  /// 輪子轉了幾度（順時針為正）。
  final double wheelDeg;

  /// 倒車燈亮著。
  final bool lightOn;

  /// 擋板打開多少（0 關著、1 放下來變斜坡；轉 −145° × 這個）。
  final double gateOpen;

  /// 兩個「嗶」：左上角、旋轉（度，以中心為軸）、透明度。
  final List<({Offset at, double deg, double opacity})> beeps;

  /// 側面的牛的腳底。
  final Offset sideFoot;

  /// 正面的牛那一格的下緣中間（揮手、擠一下都以這裡為軸；腳底在它上面 3）。
  final Offset frontBase;

  final bool showFront;

  /// 揮手搖幾度。
  final double wave;

  /// 落地轉身時擠一下：高 × [squash]、寬 × (2 − [squash])。
  final double squash;

  /// 「謝謝你的照顧！」：透明度、左上角的位置、縮放（以左下角為軸，.cut-say 的 transform-origin 0 100%）。
  final double sayOpacity;
  final Offset sayAt;
  final double sayScale;

  /// 三顆愛心（20 點的圖示）：左上角、縮放（以中心為軸）、透明度。
  final List<({Offset at, double scale, double opacity})> hearts;

  /// 往前開走時車尾的四團煙（28 點的圓）：左上角、縮放（以中心為軸）、透明度。
  final List<({Offset at, double scale, double opacity})> puffs;

  /// 最後的白光。
  final double flash;
}

/// [t] 秒時的畫面；[screen] 是手機畫面的大小（點）。
TruckFrame truckFrame(double t, Size screen, TruckGeometry g) {
  final w = screen.width, h = screen.height;
  const ts = kTruckScale;
  final road = h * 0.74, wheelY = road + 14, cowGround = road + 6; // 輪子底、牛站的地方（都在路上）
  // 卡車的位置：tx 是車尾那一邊的左緣。0.1–0.85 倒車進來（往左，車尾在前）；2.75–3.45 往前開走（往右，車頭在前）
  final stopX = w - 4 - g.size.width * ts;
  final inK = _outCubic(seg(t, 0.1, 0.85)), outK = math.pow(seg(t, 2.75, 3.45), 2.2).toDouble();
  final tx = _lerp(w + 30, stopX, inK) + outK * (w + 90 - stopX);
  final moving = (t > 0.1 && t < 0.85) || t > 2.75;
  final dip = 4 * math.sin(math.pi * seg(t, 1.66, 1.9)); // 牛落在車斗上，車身沉一下
  final rev = t > 2.62 && t < 2.75 ? math.sin((t - 2.62) * 90) * 1.2 : 0.0; // 出發前抖一下
  final ty = wheelY - g.size.height * ts + 6 * ts + (moving ? math.sin(t * 30) * 1.2 : 0) + dip + rev;
  // 輪子轉動（跟移動距離成正比）
  final wheelDeg = ((tx - stopX) / (g.wheelR * ts)) * (180 / math.pi);
  // 倒車燈和「嗶嗶」：倒車時一閃一閃
  final blink = t > 0.1 && t < 0.85 && (t * 7).floor() % 2 == 0;
  final beeps = [
    for (var i = 0; i < 2; i++)
      (at: Offset(tx - 26 + i * 22, ty + 14 - i * 20), deg: -10.0 + i * 8, opacity: blink ? 1.0 : 0.0),
  ];
  // 擋板：0.9–1.12 放下來，1.72–1.92 關上
  final open = inOut(seg(t, 0.9, 1.12)) - inOut(seg(t, 1.72, 1.92));
  // 牛：先在路邊等（側面、朝著卡車）；1.15–1.7 跳兩下上車斗；落地後轉成正面，之後跟著卡車
  final p = seg(t, 1.15, 1.7), onBoard = t >= 1.7;
  const sx0 = 14.0;
  final bedX = tx + g.bedCx * ts, bedY = ty + g.floor * ts;
  final cxm = _lerp(sx0 + 54, bedX, inOut(p));
  final cym = _lerp(cowGround, bedY, p * p * (3 - 2 * p)) - (math.sin(math.pi * 2 * p)).abs() * 34;
  final idle = t < 1.15 ? (math.sin(t * 5)).abs() * 3 : 0.0;
  final showFront = p >= 0.86;
  final squash = showFront ? 1 + 0.12 * math.sin(math.pi * seg(t, 1.62, 1.82)) : 1.0; // 轉身時擠一下
  final wave = t > 2.0 && t < 2.75 ? math.sin((t - 2.0) * 17) * 6 : 0.0;
  final fx = onBoard ? bedX : cxm, fy = onBoard ? bedY : cym;
  // 對話泡泡、愛心
  final sk = seg(t, 2.0, 2.15), sOut = seg(t, 2.95, 3.1);
  final hearts = [
    for (var i = 0; i < 3; i++)
      () {
        final k = seg(t, 2.1 + i * 0.18, 2.9 + i * 0.18);
        return (
          at: Offset(fx + 22 + i * 16 - 10, fy - 96 - k * 46 - i * 6),
          scale: 0.7 + 0.5 * k,
          opacity: k > 0 && k < 1 ? math.sin(math.pi * k) : 0.0,
        );
      }(),
  ];
  // 往前開走時，車尾揚起的煙
  final puffs = [
    for (var i = 0; i < 4; i++)
      () {
        final k = seg(t, 2.78 + i * 0.13, 3.3 + i * 0.13);
        return (
          at: Offset(tx - 22 - k * 34 - i * 4, wheelY - 30 - k * 22),
          scale: 0.45 + k * 0.9,
          opacity: k > 0 && k < 1 ? 0.95 * (1 - k) : 0.0,
        );
      }(),
  ];
  return TruckFrame(
    truck: Offset(tx, ty),
    wheelDeg: wheelDeg,
    lightOn: blink,
    gateOpen: open,
    beeps: beeps,
    // 設計稿把側面的牛畫在 108×96 的框裡（腳底在下緣往上 3），框的左上角在 (cxm − 54, cym − 96 − idle)
    sideFoot: Offset(cxm, cym - idle - 3),
    frontBase: Offset(fx, fy),
    showFront: showFront,
    wave: wave,
    squash: squash,
    sayOpacity: sk * (1 - sOut),
    sayAt: Offset(math.min(fx - 150, w - 172), fy - 142),
    sayScale: 0.6 + 0.4 * outBack(sk),
    hearts: hearts,
    puffs: puffs,
    flash: seg(t, 3.38, 3.6),
  );
}
