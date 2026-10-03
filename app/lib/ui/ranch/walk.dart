// 牛在牧場走動（A-11）和轉身（A-07）的動作：照 design/m2/src/js/anims.js 的 walkPose、A07.frame 逐條移植。
// 只算數字（位移、彈、搖、縮放），畫在 ranch_game.dart。
import 'dart:math' as math;

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

/// anims.js 的 seg(t, a, b)：t 在 a–b 之間走到哪裡（0–1）。
double seg(double t, double a, double b) => _clamp01((t - a) / (b - a));

/// anims.js 的 inOut（三次方，先加速再減速）。
double inOut(double x) => x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2;

/// anims.js 的 outBack（衝過頭一點再回來）。
double outBack(double x) {
  const c1 = 1.70158, c3 = c1 + 1;
  return 1 + c3 * math.pow(x - 1, 3) + c1 * math.pow(x - 1, 2);
}

/// A-11 一輪 4 秒：往前走 1.4 秒 → 停 0.6 秒 → 轉身往回走 1.4 秒 → 停 0.6 秒，回到原位。
const kWalkCycle = 4.0;

/// 走動的一個姿勢：往前多遠（場景座標，正的是牛面向的方向）、是不是在往回走（整頭牛左右翻過來）、
/// 往上彈多少（場景座標）、搖幾度（以腳底為軸）。
class WalkPose {
  const WalkPose(this.x, {this.back = false, this.bob = 0, this.tilt = 0});

  final double x;
  final bool back;
  final double bob;
  final double tilt;

  /// 站在原位不動。
  static const rest = WalkPose(0);
}

/// 一個位置的走法（anims.js 的 WALK）：走多遠（場景座標）、節奏錯開幾秒。
class WalkPlan {
  const WalkPlan(this.dist, this.phase);

  final double dist;
  final double phase;
}

/// app 用的走法：設計稿的 [t] = 0 時，各頭牛已經走到各自節奏的一半。app 一打開大家都在原位（跟靜態的牧場畫面
/// 一樣），每頭牛等自己的節奏輪到（u = 0）才起步；起步以後跟 [designWalkPose] 完全一樣。
/// 距離 0 的位置（前面沒有空間）原地一搖一搖：只彈、搖，不轉身。
WalkPose walkPose(double t, WalkPlan plan, {bool calf = false}) {
  final wait = (kWalkCycle - plan.phase % kWalkCycle) % kWalkCycle;
  if (t < wait) return WalkPose.rest;
  final p = designWalkPose(t, plan, calf: calf);
  return plan.dist == 0 ? WalkPose(0, bob: p.bob, tilt: p.tilt) : p;
}

/// anims.js 的 walkPose(t, dist, phase, T, calf) 原樣。
WalkPose designWalkPose(double t, WalkPlan plan, {bool calf = false}) {
  final u = ((t + plan.phase) % kWalkCycle + kWalkCycle) % kWalkCycle / kWalkCycle;
  double x, k;
  bool moving, back;
  if (u < 0.35) {
    k = u / 0.35;
    x = inOut(k) * plan.dist;
    moving = true;
    back = false;
  } else if (u < 0.5) {
    x = plan.dist;
    moving = false;
    back = false;
    k = 0;
  } else if (u < 0.85) {
    k = (u - 0.5) / 0.35;
    x = plan.dist * (1 - inOut(k));
    moving = true;
    back = true;
  } else {
    x = 0;
    moving = false;
    back = false;
    k = 0;
  }
  final steps = calf ? 5 : 4;
  final wave = moving ? math.sin(k * math.pi * steps) : 0.0;
  final bob = moving ? wave.abs() * (calf ? 6 : 2.4) : 0.0;
  final tilt = moving ? wave * (calf ? 4 : 2.2) : 0.0;
  return WalkPose(x, back: back, bob: bob, tilt: tilt);
}

/// A-07 轉身一次 0.5 秒（側面 → 正面）。
const kTurnSeconds = 0.5;

/// 轉身的一個姿勢：[front] 畫正面還是側面、左右縮放（以腳底為軸）、正面往上跳多少（場景座標）。
class TurnPose {
  const TurnPose({required this.front, required this.scaleX, this.hop = 0});

  final bool front;
  final double scaleX;
  final double hop;
}

/// anims.js 的 A07.frame：[t] 是從側面開始轉了幾秒（0–0.5）。0–0.22 秒側面往中間收窄，之後換成正面展開、輕輕跳一下。
/// 正面轉回側面時倒著播（t 從 0.5 回到 0）。
TurnPose turnPose(double t) {
  final a = seg(t, 0, 0.22), b = seg(t, 0.22, 0.44);
  final hop = math.sin(math.pi * seg(t, 0.22, 0.5)) * 8;
  return t < 0.22
      ? TurnPose(front: false, scaleX: math.max(0.001, 1 - inOut(a)))
      : TurnPose(front: true, scaleX: math.max(0.001, outBack(b)), hop: hop);
}

/// 前 8 個位置的走法（設計稿 anims.js 的 WALK，依設計稿牛的編號排就是 herd.dart 的前 8 個位置）：
/// #3、#5、#7、#8、#11、#12、#14、#15（小牛）。
const kDesignWalk = <WalkPlan>[
  WalkPlan(18, 0.9), // #3
  WalkPlan(12, 1.1), // #5
  WalkPlan(16, 2.6), // #7
  WalkPlan(12, 1.6), // #8
  WalkPlan(18, 2.0), // #11
  WalkPlan(16, 3.3), // #12
  WalkPlan(16, 0.2), // #14
  WalkPlan(26, 0.0), // #15（小牛）
];

/// 40 個位置的走法（tool/herd_walk.py 算的，改了 herd.dart 的位置或規則就重跑、貼回來）。前 8 個照 [kDesignWalk]；
/// 其他 32 個設計稿沒畫到，照 ceo 2026-10-03 同意的規則：往面向的方向走、最多 18；跟同一排（上下差 40 以內）前面最近的
/// 位置至少隔 12（對面朝這邊走的話兩頭一起算）；腳底不進池塘、水槽、乾草捆；空間不到 8 就原地一搖一搖（距離 0）；
/// 節奏是位置編號 × 0.618 × 4 秒（黃金比例），相鄰的牛不會同時動。
const kHerdWalk = <WalkPlan>[
  WalkPlan(18, 0.9), // 0：(70, 420) 右，設計稿 WALK
  WalkPlan(12, 1.1), // 1：(410, 334) 右，設計稿 WALK
  WalkPlan(16, 2.6), // 2：(310, 422) 左，設計稿 WALK
  WalkPlan(12, 1.6), // 3：(318, 338) 左，設計稿 WALK
  WalkPlan(18, 2), // 4：(724, 552) 左，設計稿 WALK
  WalkPlan(16, 3.3), // 5：(122, 522) 右，設計稿 WALK
  WalkPlan(16, 0.2), // 6：(104, 344) 右，設計稿 WALK
  WalkPlan(26, 0), // 7：(186, 424) 右，設計稿 WALK
  WalkPlan(18, 3.78), // 8：(730, 336) 左
  WalkPlan(18, 2.25), // 9：(431, 550) 右
  WalkPlan(9, 0.72), // 10：(569, 380) 右
  WalkPlan(18, 3.19), // 11：(730, 424) 左
  WalkPlan(18, 1.67), // 12：(270, 512) 左
  WalkPlan(0, 0.14), // 13：(454, 424) 右，原地一搖一搖
  WalkPlan(18, 2.61), // 14：(569, 550) 右
  WalkPlan(18, 1.08), // 15：(385, 468) 左
  WalkPlan(18, 3.55), // 16：(247, 380) 左
  WalkPlan(18, 2.03), // 17：(109, 468) 右
  WalkPlan(0, 0.5), // 18：(201, 550) 左，原地一搖一搖
  WalkPlan(0, 2.97), // 19：(661, 380) 左，原地一搖一搖
  WalkPlan(18, 1.44), // 20：(500, 336) 右
  WalkPlan(18, 3.91), // 21：(385, 380) 左
  WalkPlan(11, 2.39), // 22：(40, 512) 右
  WalkPlan(17, 0.86), // 23：(224, 336) 左
  WalkPlan(18, 3.33), // 24：(477, 380) 右
  WalkPlan(18, 1.8), // 25：(247, 468) 左
  WalkPlan(18, 0.28), // 26：(155, 380) 右
  WalkPlan(0, 2.75), // 27：(684, 512) 左，原地一搖一搖
  WalkPlan(0, 1.22), // 28：(63, 380) 右，原地一搖一搖
  WalkPlan(0, 3.69), // 29：(408, 512) 右，原地一搖一搖
  WalkPlan(18, 2.16), // 30：(63, 550) 右
  WalkPlan(11, 0.64), // 31：(293, 550) 左
  WalkPlan(18, 3.11), // 32：(40, 336) 右
  WalkPlan(18, 1.58), // 33：(661, 550) 左
  WalkPlan(0, 0.05), // 34：(178, 512) 右，原地一搖一搖
  WalkPlan(18, 2.52), // 35：(132, 424) 右
  WalkPlan(18, 1), // 36：(362, 424) 左
  WalkPlan(17, 3.47), // 37：(178, 336) 右
  WalkPlan(18, 1.94), // 38：(270, 336) 左
  WalkPlan(18, 0.41), // 39：(546, 336) 右
];

/// 位置 [slot] 的走法；超出 40 個（不會發生：牛舍最多 40 頭）就不走。
WalkPlan? walkPlanFor(int slot) => slot < kHerdWalk.length ? kHerdWalk[slot] : null;
