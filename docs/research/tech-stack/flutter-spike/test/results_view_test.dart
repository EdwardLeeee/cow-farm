import 'package:cowfarm_spike/probe/probe.dart';
import 'package:cowfarm_spike/report.dart';
import 'package:cowfarm_spike/results_view.dart';
import 'package:cowfarm_spike/stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 在 [startS, startS + seconds) 內以 [fps] 張/秒產生畫面，每張 build/raster 固定。
List<FrameSample> _frames({
  required double startS,
  required double seconds,
  required double fps,
  required double buildMs,
  required double rasterMs,
}) {
  final int count = (seconds * fps).round();
  return <FrameSample>[
    for (int i = 0; i < count; i++)
      FrameSample(
        buildStartUs: ((startS + i / fps) * 1e6).round(),
        buildUs: (buildMs * 1000).round(),
        rasterUs: (rasterMs * 1000).round(),
        totalUs: ((buildMs + rasterMs) * 1000).round() + 800,
      ),
  ];
}

BenchmarkReport _report() {
  const RunConfig config = RunConfig();
  final List<FrameSample> samples = <FrameSample>[
    ..._frames(startS: 0, seconds: 10, fps: 120, buildMs: 2, rasterMs: 4),
    ..._frames(startS: 10, seconds: 10, fps: 60, buildMs: 3, rasterMs: 12),
  ];
  PhaseStats phase(int cows, double startS) => PhaseStats.compute(
    cows: cows,
    samples: samples,
    windowStartUs: (startS * 1e6).round(),
    windowEndUs: ((startS + 10) * 1e6).round(),
    rssMaxMb: 150,
  );
  return BenchmarkReport(
    appVersion: '0.0.1',
    buildNumber: '7',
    buildMode: 'release',
    renderer: 'Impeller',
    device: const DeviceSummary(model: 'iPhone15,3', os: 'iOS Version 18.6.2 (Build 22G100)'),
    screen: '1290×2796 px @3.0x',
    displayRefreshRate: 120,
    flutterVersion: '3.47.5',
    dartVersion: '3.13.4',
    flameVersion: '1.38.2',
    config: config,
    // 第 3、4 段沒有任何畫面（例如 app 被切到背景），要顯示「—」而不是當掉。
    phases: <PhaseStats>[phase(30, 0), phase(60, 10), phase(100, 20), phase(200, 30)],
    finishedAt: DateTime(2026, 10, 1, 20, 30, 5),
    interrupted: false,
  );
}

void main() {
  testWidgets('結果表顯示統計函式算出的數字，而且一個 iPhone 14 Pro Max 畫面放得下', (
    WidgetTester tester,
  ) async {
    // iPhone 14 Pro Max：1290×2796 px，3 倍 → 430×932 pt。
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: ResultsView(report: _report())));

    expect(find.text('牛的數量'), findsOneWidget);
    for (final String n in <String>['30', '60', '100', '200']) {
      expect(find.text(n), findsWidgets);
    }
    // 第 1 段：120 張/秒、畫面時間 4 ms、沒有超過 8.3 ms。
    expect(find.text('120.0'), findsOneWidget);
    expect(find.text('4.00'), findsWidgets);
    // 第 2 段：60 張/秒、畫面時間 12 ms，全部超過 8.3 ms、沒有超過 16.7 ms。
    expect(find.text('60.0'), findsOneWidget);
    expect(find.text('12.0'), findsWidgets);
    expect(find.text('100.0'), findsOneWidget);
    expect(find.text('1200'), findsOneWidget);
    expect(find.text('600'), findsOneWidget);
    // 沒有資料的段落顯示「—」。
    expect(find.text('—'), findsWidgets);
    expect(find.textContaining('iPhone15,3'), findsOneWidget);

    // 不必捲動：兩個按鈕都在畫面內。
    final Rect copy = tester.getRect(find.text('複製結果'));
    final Rect rerun = tester.getRect(find.text('再跑一次'));
    expect(copy.bottom, lessThanOrEqualTo(932));
    expect(rerun.bottom, lessThanOrEqualTo(932));
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄螢幕（360 dp 寬）表格等比縮小，不會左右溢出', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: ResultsView(report: _report())));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('實際 FPS'), findsOneWidget);
    // getRect 已套用 FittedBox 的縮放：表格右緣要在左右各留 16 的範圍內。
    final Rect table = tester.getRect(find.byType(Table));
    expect(table.left, greaterThanOrEqualTo(16 - 0.5));
    expect(table.right, lessThanOrEqualTo(360 - 16 + 0.5));
  });
}
