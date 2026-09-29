import 'dart:ui' show FrameTiming;

import 'package:cowfarm_spike/stats.dart';
import 'package:flutter_test/flutter_test.dart';

FrameSample _sample(int startMs, {required double buildMs, required double rasterMs}) =>
    FrameSample(
      buildStartUs: startMs * 1000,
      buildUs: (buildMs * 1000).round(),
      rasterUs: (rasterMs * 1000).round(),
      totalUs: ((buildMs + rasterMs) * 1000).round() + 500,
    );

void main() {
  group('percentile', () {
    test('線性內插，與 numpy 預設相同', () {
      final List<double> values = <double>[1, 2, 3, 4];
      expect(median(values), 2.5);
      expect(percentile(values, 0.99), closeTo(3.97, 1e-9));
      expect(percentile(values, 0), 1);
      expect(percentile(values, 1), 4);
    });

    test('奇數個取正中間，不必先排序', () {
      expect(median(<double>[9, 1, 5]), 5);
    });

    test('只有一筆時所有百分位數都是它', () {
      expect(median(<double>[7]), 7);
      expect(percentile(<double>[7], 0.99), 7);
    });

    test('沒有資料時回傳 null，不丟例外', () {
      expect(median(<double>[]), isNull);
      expect(percentile(<double>[], 0.99), isNull);
      expect(fractionAbove(<double>[], budget120HzMs), isNull);
    });
  });

  test('fractionAbove 用「大於」，剛好等於門檻不算', () {
    expect(fractionAbove(<double>[8, budget120HzMs, 9, 20], budget120HzMs), 0.5);
    expect(fractionAbove(<double>[8, 9, 20], budget60HzMs), closeTo(1 / 3, 1e-9));
  });

  test('畫面時間取 build 與 raster 的較大值', () {
    expect(_sample(0, buildMs: 3, rasterMs: 5).frameUs, 5000);
    expect(_sample(0, buildMs: 7, rasterMs: 2).frameUs, 7000);
  });

  test('FrameSample.fromTiming 讀引擎的時間戳', () {
    final FrameTiming timing = FrameTiming(
      vsyncStart: 1000,
      buildStart: 1500,
      buildFinish: 4500,
      rasterStart: 5000,
      rasterFinish: 11000,
      rasterFinishWallTime: 11000,
    );
    final FrameSample s = FrameSample.fromTiming(timing);
    expect(s.buildStartUs, 1500);
    expect(s.buildUs, 3000);
    expect(s.rasterUs, 6000);
    expect(s.totalUs, 10000);
    expect(s.frameUs, 6000);
  });

  group('PhaseStats.compute', () {
    test('只算時間窗內的畫面，FPS 用時間窗長度換算', () {
      final List<FrameSample> samples = <FrameSample>[
        // 時間窗之前（上一段）的畫面，應排除。
        _sample(900, buildMs: 30, rasterMs: 30),
        // 時間窗 1000–2000 ms 內 10 張：8 張 4 ms、1 張 10 ms、1 張 20 ms。
        for (int i = 0; i < 8; i++) _sample(1000 + i * 100, buildMs: 2, rasterMs: 4),
        _sample(1800, buildMs: 10, rasterMs: 3),
        _sample(1900, buildMs: 1, rasterMs: 20),
        // 時間窗結束點本身不算（右開區間）。
        _sample(2000, buildMs: 40, rasterMs: 40),
      ];
      final PhaseStats stats = PhaseStats.compute(
        cows: 60,
        samples: samples,
        windowStartUs: 1000 * 1000,
        windowEndUs: 2000 * 1000,
        rssMaxMb: 123.4,
      );
      expect(stats.cows, 60);
      expect(stats.frames, 10);
      expect(stats.windowSeconds, 1.0);
      expect(stats.fps, 10);
      expect(stats.frameMedianMs, 4);
      expect(stats.frameMaxMs, 20);
      expect(stats.over120HzPct, closeTo(20, 1e-9));
      expect(stats.over60HzPct, closeTo(10, 1e-9));
      expect(stats.frameP99Ms, closeTo(19.1, 1e-9));
      expect(stats.rssMaxMb, 123.4);
      expect(stats.toJson()['over_8_3ms_pct'], 20.0);
    });

    test('時間窗內沒有畫面時全部是 null', () {
      final PhaseStats stats = PhaseStats.compute(
        cows: 200,
        samples: <FrameSample>[_sample(0, buildMs: 1, rasterMs: 1)],
        windowStartUs: 5000000,
        windowEndUs: 6000000,
      );
      expect(stats.frames, 0);
      expect(stats.fps, isNull);
      expect(stats.frameMedianMs, isNull);
      expect(stats.frameP99Ms, isNull);
      expect(stats.over120HzPct, isNull);
      expect(stats.toJson()['fps'], isNull);
    });
  });
}
