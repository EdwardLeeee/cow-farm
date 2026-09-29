// 效能統計：純函式，不依賴畫面，方便測試。
//
// 名詞
// - build：UI 執行緒建構這張畫面的時間（FrameTiming.buildDuration）。
// - raster：繪圖執行緒把畫面畫出來的時間（FrameTiming.rasterDuration）。
// - 畫面時間：max(build, raster)。兩條執行緒是流水線，任一段超過一格的時間就會掉格。
//   Flutter 文件：「To ensure smooth animations of X fps, this should not exceed 1000/X
//   milliseconds. That's about 16ms for 60fps, and 8ms for 120fps.」
// - 延遲：FrameTiming.totalSpan，從 vsync 到畫完。
import 'dart:math' as math;
import 'dart:ui' show FramePhase, FrameTiming;

/// 60 Hz 一格的時間（毫秒）。
const double budget60HzMs = 1000 / 60;

/// 120 Hz 一格的時間（毫秒）。iPhone 14 Pro Max 的 ProMotion 最高 120 Hz。
const double budget120HzMs = 1000 / 120;

/// 一張畫面的量測值，單位微秒。
class FrameSample {
  const FrameSample({
    required this.buildStartUs,
    required this.buildUs,
    required this.rasterUs,
    required this.totalUs,
  });

  /// 從引擎回報的 [FrameTiming] 轉換。
  ///
  /// `buildStart` 的時間戳和 `SchedulerBinding.currentSystemFrameTimeStamp` 是同一個時鐘
  /// （FrameTiming.buildDuration 的文件：onBeginFrame 收到的 Duration「is exactly」
  /// buildStart），所以可以拿來判斷這張畫面屬於哪一段測試。
  factory FrameSample.fromTiming(FrameTiming timing) => FrameSample(
    buildStartUs: timing.timestampInMicroseconds(FramePhase.buildStart),
    buildUs: timing.buildDuration.inMicroseconds,
    rasterUs: timing.rasterDuration.inMicroseconds,
    totalUs: timing.totalSpan.inMicroseconds,
  );

  final int buildStartUs;
  final int buildUs;
  final int rasterUs;
  final int totalUs;

  /// 畫面時間：build 與 raster 取大的那個。
  int get frameUs => math.max(buildUs, rasterUs);
}

/// 已排序（由小到大）資料的百分位數，p 介於 0 到 1。
///
/// 用相鄰兩點線性內插（與 numpy 預設的 linear 相同）。沒有資料時回傳 null，不丟例外：
/// 某一段可能收不到任何畫面（例如 app 被切到背景）。
double? percentileOfSorted(List<double> sorted, double p) {
  if (sorted.isEmpty) return null;
  if (p <= 0) return sorted.first;
  if (p >= 1) return sorted.last;
  final double rank = (sorted.length - 1) * p;
  final int lo = rank.floor();
  final int hi = rank.ceil();
  if (lo == hi) return sorted[lo];
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (rank - lo);
}

/// 未排序資料的百分位數；會複製一份再排序。
double? percentile(Iterable<double> values, double p) {
  final List<double> sorted = values.toList()..sort();
  return percentileOfSorted(sorted, p);
}

/// 中位數。
double? median(Iterable<double> values) => percentile(values, 0.5);

/// 大於門檻的比例（0 到 1）。沒有資料時回傳 null。
double? fractionAbove(Iterable<double> values, double threshold) {
  int total = 0;
  int above = 0;
  for (final double v in values) {
    total++;
    if (v > threshold) above++;
  }
  if (total == 0) return null;
  return above / total;
}

/// 一段測試（固定牛數）的統計結果。毫秒與百分比都已換算好，null 代表沒有資料。
class PhaseStats {
  const PhaseStats({
    required this.cows,
    required this.frames,
    required this.windowSeconds,
    this.fps,
    this.frameMedianMs,
    this.frameP99Ms,
    this.frameMaxMs,
    this.over120HzPct,
    this.over60HzPct,
    this.buildMedianMs,
    this.buildP99Ms,
    this.rasterMedianMs,
    this.rasterP99Ms,
    this.latencyMedianMs,
    this.latencyP99Ms,
    this.rssMaxMb,
  });

  /// 用 [samples] 裡 buildStart 落在 [windowStartUs, windowEndUs) 的畫面計算。
  factory PhaseStats.compute({
    required int cows,
    required Iterable<FrameSample> samples,
    required int windowStartUs,
    required int windowEndUs,
    double? rssMaxMb,
  }) {
    final List<FrameSample> inWindow = <FrameSample>[
      for (final FrameSample s in samples)
        if (s.buildStartUs >= windowStartUs && s.buildStartUs < windowEndUs) s,
    ];
    final double windowSeconds = math.max(0, windowEndUs - windowStartUs) / 1e6;
    List<double> ms(int Function(FrameSample) pick) =>
        inWindow.map((FrameSample s) => pick(s) / 1000.0).toList()..sort();
    final List<double> frame = ms((FrameSample s) => s.frameUs);
    final List<double> build = ms((FrameSample s) => s.buildUs);
    final List<double> raster = ms((FrameSample s) => s.rasterUs);
    final List<double> latency = ms((FrameSample s) => s.totalUs);
    double? pct(double? fraction) => fraction == null ? null : fraction * 100;
    return PhaseStats(
      cows: cows,
      frames: inWindow.length,
      windowSeconds: windowSeconds,
      fps: inWindow.isEmpty || windowSeconds <= 0 ? null : inWindow.length / windowSeconds,
      frameMedianMs: percentileOfSorted(frame, 0.5),
      frameP99Ms: percentileOfSorted(frame, 0.99),
      frameMaxMs: frame.isEmpty ? null : frame.last,
      over120HzPct: pct(fractionAbove(frame, budget120HzMs)),
      over60HzPct: pct(fractionAbove(frame, budget60HzMs)),
      buildMedianMs: percentileOfSorted(build, 0.5),
      buildP99Ms: percentileOfSorted(build, 0.99),
      rasterMedianMs: percentileOfSorted(raster, 0.5),
      rasterP99Ms: percentileOfSorted(raster, 0.99),
      latencyMedianMs: percentileOfSorted(latency, 0.5),
      latencyP99Ms: percentileOfSorted(latency, 0.99),
      rssMaxMb: rssMaxMb,
    );
  }

  final int cows;
  final int frames;
  final double windowSeconds;
  final double? fps;
  final double? frameMedianMs;
  final double? frameP99Ms;
  final double? frameMaxMs;

  /// 畫面時間超過 8.33 ms（120 Hz 一格）的百分比。
  final double? over120HzPct;

  /// 畫面時間超過 16.67 ms（60 Hz 一格）的百分比。
  final double? over60HzPct;
  final double? buildMedianMs;
  final double? buildP99Ms;
  final double? rasterMedianMs;
  final double? rasterP99Ms;
  final double? latencyMedianMs;
  final double? latencyP99Ms;
  final double? rssMaxMb;

  Map<String, Object?> toJson() {
    double? r(double? v, [int digits = 2]) =>
        v == null ? null : double.parse(v.toStringAsFixed(digits));
    return <String, Object?>{
      'cows': cows,
      'frames': frames,
      'window_s': r(windowSeconds, 1),
      'fps': r(fps, 1),
      'frame_median_ms': r(frameMedianMs),
      'frame_p99_ms': r(frameP99Ms),
      'frame_max_ms': r(frameMaxMs),
      'over_8_3ms_pct': r(over120HzPct),
      'over_16_7ms_pct': r(over60HzPct),
      'build_median_ms': r(buildMedianMs),
      'build_p99_ms': r(buildP99Ms),
      'raster_median_ms': r(rasterMedianMs),
      'raster_p99_ms': r(rasterP99Ms),
      'latency_median_ms': r(latencyMedianMs),
      'latency_p99_ms': r(latencyP99Ms),
      'rss_max_mb': r(rssMaxMb, 1),
    };
  }
}
