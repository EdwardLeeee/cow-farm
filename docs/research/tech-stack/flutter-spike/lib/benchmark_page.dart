// 自動測試流程：熱身 → N = 30、60、100、200 各跑一段 → 顯示結果表。
//
// 每張畫面的時間由引擎回報（SchedulerBinding.addTimingsCallback）。release 版約每秒回報一批，
// 所以不照「收到的時間」分段，而是用每張畫面自己的 buildStart 時間戳對照各段的起訖；
// 起訖點取自同一個時鐘（SchedulerBinding.currentSystemFrameTimeStamp）。
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'cow_game.dart';
import 'price_chart.dart';
import 'probe/probe.dart';
import 'report.dart';
import 'results_view.dart';
import 'stats.dart';

const String kAppVersion = '0.0.1';
const String kBuildNumber = String.fromEnvironment('BUILD_NUMBER', defaultValue: '1');
const String kFlameVersion = '1.38.2';

/// 測試進行中的狀態列文字與進度。
class RunStatus {
  const RunStatus(this.label, this.progress);

  final String label;
  final double progress;
}

class BenchmarkPage extends StatefulWidget {
  const BenchmarkPage({super.key, this.config = RunConfig.fromEnvironment});

  final RunConfig config;

  @override
  State<BenchmarkPage> createState() => _BenchmarkPageState();
}

class _BenchmarkPageState extends State<BenchmarkPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final CowGame _game = CowGame();
  final PriceSeries _prices = PriceSeries();
  final List<FrameSample> _samples = <FrameSample>[];
  final ValueNotifier<RunStatus> _status = ValueNotifier<RunStatus>(
    const RunStatus('準備中…', 0),
  );
  late final Ticker _ticker = createTicker(_onTick);
  late final DeviceSummary _device = readDeviceSummary();

  RunConfig get _config => widget.config;

  Timer? _priceTimer;
  bool _running = false;
  bool _interrupted = false;
  int _inactiveEvents = 0;
  int? _runStartUs;

  /// -1 是熱身；0..n-1 是各段；n 是收尾（等最後一批畫面時間）。
  int _stage = -1;
  late List<double?> _rssMaxMb;
  double? _rssBaselineMb;
  int _lastRssSampleUs = 0;
  int _lastStatusUs = 0;
  BenchmarkReport? _report;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _start();
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    WidgetsBinding.instance.removeObserver(this);
    _priceTimer?.cancel();
    _ticker.dispose();
    _status.dispose();
    _prices.dispose();
    super.dispose();
  }

  void _start() {
    _samples.clear();
    _rssMaxMb = List<double?>.filled(_config.cowCounts.length, null);
    _rssBaselineMb = null;
    _runStartUs = null;
    _stage = -1;
    _interrupted = false;
    _inactiveEvents = 0;
    _lastRssSampleUs = 0;
    _lastStatusUs = 0;
    _prices.reset();
    _game.setCowCount(_config.cowCounts.first);
    if (_game.paused) _game.resumeEngine();
    _priceTimer?.cancel();
    _priceTimer = Timer.periodic(const Duration(milliseconds: 100), (_) => _prices.step());
    _running = true;
    _status.value = RunStatus('熱身中（${_config.cowCounts.first} 頭）', 0);
    if (_report != null) setState(() => _report = null);
    _ticker.start();
  }

  void _onTimings(List<ui.FrameTiming> timings) {
    if (!_running) return;
    for (final ui.FrameTiming timing in timings) {
      _samples.add(FrameSample.fromTiming(timing));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_running) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // 畫面不再顯示、不再出新畫面：這一輪的數字不可靠。
        _interrupted = true;
      case AppLifecycleState.inactive:
        // iOS 冷啟動、拉下通知時都會短暫 inactive，畫面照常更新，只記次數不警告。
        _inactiveEvents++;
      case AppLifecycleState.resumed:
        break;
    }
  }

  int _secondsToUs(num seconds) => (seconds * 1000000).round();

  void _onTick(Duration elapsed) {
    // 這一張畫面的 onBeginFrame 時間戳，等於它的 FrameTiming.buildStart。
    final int nowUs = SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds;
    final int startUs = _runStartUs ??= nowUs;
    final double t = (nowUs - startUs) / 1e6;
    final RunConfig c = _config;
    final int n = c.cowCounts.length;
    final double measuredEnd = (c.warmupSeconds + c.phaseSeconds * n).toDouble();

    if (t >= measuredEnd + c.tailSeconds) {
      _finish();
      return;
    }
    final int stage = t < c.warmupSeconds
        ? -1
        : (t < measuredEnd ? ((t - c.warmupSeconds) / c.phaseSeconds).floor() : n);
    if (stage != _stage) {
      if (_stage == -1 && stage >= 0) _rssBaselineMb = _rssMb();
      _stage = stage;
      if (stage >= 0 && stage < n) _game.setCowCount(c.cowCounts[stage]);
    }

    // 每秒量一次記憶體，記下每段的最大值。
    if (nowUs - _lastRssSampleUs >= 1000000) {
      _lastRssSampleUs = nowUs;
      final double? rss = _rssMb();
      if (rss != null && stage >= 0 && stage < n) {
        final double? prev = _rssMaxMb[stage];
        _rssMaxMb[stage] = prev == null || rss > prev ? rss : prev;
      }
    }

    // 狀態列每 0.25 秒更新一次就好，避免狀態列本身變成負擔。
    if (nowUs - _lastStatusUs >= 250000) {
      _lastStatusUs = nowUs;
      final int total = c.totalSeconds;
      final String label;
      if (stage == -1) {
        label = '熱身中（${c.cowCounts.first} 頭）· 還有 ${(c.warmupSeconds - t).ceil()} 秒';
      } else if (stage < n) {
        final double left = c.warmupSeconds + c.phaseSeconds * (stage + 1) - t;
        label = '第 ${stage + 1}/$n 段：${c.cowCounts[stage]} 頭 · 還有 ${left.ceil()} 秒';
      } else {
        label = '整理結果中…';
      }
      _status.value = RunStatus(label, (t / total).clamp(0.0, 1.0));
    }
  }

  double? _rssMb() {
    final int? bytes = currentRssBytes();
    return bytes == null ? null : bytes / (1024 * 1024);
  }

  void _finish() {
    _running = false;
    _ticker.stop();
    _priceTimer?.cancel();
    _game.pauseEngine();

    final RunConfig c = _config;
    final int startUs = _runStartUs!;
    final List<PhaseStats> phases = <PhaseStats>[
      for (int i = 0; i < c.cowCounts.length; i++)
        PhaseStats.compute(
          cows: c.cowCounts[i],
          samples: _samples,
          windowStartUs:
              startUs + _secondsToUs(c.warmupSeconds + c.phaseSeconds * i + c.settleSeconds),
          windowEndUs: startUs + _secondsToUs(c.warmupSeconds + c.phaseSeconds * (i + 1)),
          rssMaxMb: _rssMaxMb[i],
        ),
    ];

    final ui.FlutterView view = View.of(context);
    final ui.Size physical = view.physicalSize;
    final BenchmarkReport report = BenchmarkReport(
      appVersion: kAppVersion,
      buildNumber: kBuildNumber,
      buildMode: kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug'),
      renderer: kIsWeb
          ? (kIsWasm ? 'Web（wasm）' : 'Web（JS）')
          : (ui.ImageFilter.isShaderFilterSupported ? 'Impeller' : 'Skia'),
      device: _device,
      screen:
          '${physical.width.round()}×${physical.height.round()} px @${view.devicePixelRatio.toStringAsFixed(1)}x',
      displayRefreshRate: view.display.refreshRate,
      flutterVersion: FlutterVersion.version ?? '?',
      dartVersion: FlutterVersion.dartVersion ?? '?',
      flameVersion: kFlameVersion,
      config: c,
      phases: phases,
      finishedAt: DateTime.now(),
      interrupted: _interrupted,
      inactiveEvents: _inactiveEvents,
      rssBaselineMb: _rssBaselineMb,
    );

    // 印到 console（網頁版的開發者工具、Android 的 adb logcat、Mac 的 Console.app 看得到）。
    for (final PhaseStats p in phases) {
      debugPrint('COWFARM_SPIKE_PHASE ${jsonEncode(p.toJson())}');
    }
    debugPrint('COWFARM_SPIKE_RESULT ${jsonEncode(report.toJson())}');
    setState(() => _report = report);
  }

  Future<void> _copy() async {
    final BenchmarkReport? report = _report;
    if (report == null) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await Clipboard.setData(
        ClipboardData(text: const JsonEncoder.withIndent('  ').convert(report.toJson())),
      );
      messenger.showSnackBar(const SnackBar(content: Text('已複製，可以貼到對話裡。')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('複製失敗，請改用截圖。')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final BenchmarkReport? report = _report;
    return Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: GameWidget<CowGame>(game: _game)),
          Positioned(
            left: 12,
            right: 12,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: SizedBox(height: 132, child: PriceChart(series: _prices)),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _StatusBar(status: _status, totalSeconds: _config.totalSeconds),
          ),
          if (report != null)
            Positioned.fill(
              child: ResultsView(report: report, onCopy: _copy, onRerun: _start),
            ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.status, required this.totalSeconds});

  final ValueListenable<RunStatus> status;
  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xCC1B2A10),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: ValueListenableBuilder<RunStatus>(
            valueListenable: status,
            builder: (BuildContext context, RunStatus s, Widget? _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '測試中，請不要碰螢幕（全程約 $totalSeconds 秒）',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  s.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: s.progress),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
