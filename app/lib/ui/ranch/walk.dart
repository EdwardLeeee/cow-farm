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
WalkPose walkPose(double t, WalkPlan plan, {bool calf = false}) {
  final wait = (kWalkCycle - plan.phase % kWalkCycle) % kWalkCycle;
  return t < wait ? WalkPose.rest : designWalkPose(t, plan, calf: calf);
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

/// 位置 [slot] 的走法；設計稿沒畫到的位置（第 9 個以後）先不走（等 ceo 決定，2026-10-03）。
WalkPlan? walkPlanFor(int slot) => slot < kDesignWalk.length ? kDesignWalk[slot] : null;
