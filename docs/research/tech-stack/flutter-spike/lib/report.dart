import 'probe/probe.dart';
import 'stats.dart';

/// 測試流程的時間設定（秒）。預設值就是正式量測用的；--dart-define 只給本機快速檢查用。
class RunConfig {
  const RunConfig({
    this.warmupSeconds = 5,
    this.phaseSeconds = 20,
    this.settleSeconds = 1,
    this.tailSeconds = 2,
    this.cowCounts = const <int>[30, 60, 100, 200],
  });

  static const RunConfig fromEnvironment = RunConfig(
    warmupSeconds: int.fromEnvironment('SPIKE_WARMUP_SECONDS', defaultValue: 5),
    phaseSeconds: int.fromEnvironment('SPIKE_PHASE_SECONDS', defaultValue: 20),
  );

  /// 熱身：用第一段的牛數跑，不列入統計。
  final int warmupSeconds;

  /// 每一段（固定牛數）的長度。
  final int phaseSeconds;

  /// 每段開頭不計的秒數：切換牛數的那一下會新增元件，不代表穩定狀態。
  final int settleSeconds;

  /// 最後一段結束後再跑幾秒：release 版的畫面時間約每秒才回報一次，等最後一批送到。
  final int tailSeconds;
  final List<int> cowCounts;

  int get totalSeconds => warmupSeconds + phaseSeconds * cowCounts.length + tailSeconds;

  Map<String, Object> toJson() => <String, Object>{
    'warmup_s': warmupSeconds,
    'phase_s': phaseSeconds,
    'settle_s': settleSeconds,
    'tail_s': tailSeconds,
    'cow_counts': cowCounts,
  };
}

/// 一次完整測試的結果：顯示在畫面上、印到 console、也可以複製。
class BenchmarkReport {
  const BenchmarkReport({
    required this.appVersion,
    required this.buildNumber,
    required this.buildMode,
    required this.renderer,
    required this.device,
    required this.screen,
    required this.displayRefreshRate,
    required this.flutterVersion,
    required this.dartVersion,
    required this.flameVersion,
    required this.config,
    required this.phases,
    required this.finishedAt,
    required this.interrupted,
    this.inactiveEvents = 0,
    this.rssBaselineMb,
  });

  final String appVersion;
  final String buildNumber;
  final String buildMode;
  final String renderer;
  final DeviceSummary device;

  /// 例如 `1290×2796 px @3.0x`。
  final String screen;

  /// 引擎回報的螢幕最高更新率。iOS 上它等於硬體上限，不代表 app 真的跑到 120 Hz；
  /// 要看結果表的「實際 FPS」。
  final double? displayRefreshRate;
  final String flutterVersion;
  final String dartVersion;
  final String flameVersion;
  final RunConfig config;
  final List<PhaseStats> phases;
  final DateTime finishedAt;

  /// 測試途中 app 曾不在畫面上（切到背景、鎖定畫面），這一輪的數字不可靠。
  final bool interrupted;

  /// 測試途中短暫 inactive 的次數（冷啟動、拉下通知或控制中心）。畫面照常更新，只記錄不警告。
  final int inactiveEvents;
  final double? rssBaselineMb;

  Map<String, Object?> toJson() => <String, Object?>{
    'app': '$appVersion+$buildNumber',
    'mode': buildMode,
    'renderer': renderer,
    'device': device.toJson(),
    'screen': screen,
    'display_refresh_hz': displayRefreshRate == null
        ? null
        : double.parse(displayRefreshRate!.toStringAsFixed(1)),
    'flutter': flutterVersion,
    'dart': dartVersion,
    'flame': flameVersion,
    'config': config.toJson(),
    'rss_baseline_mb': rssBaselineMb == null
        ? null
        : double.parse(rssBaselineMb!.toStringAsFixed(1)),
    'interrupted': interrupted,
    'inactive_events': inactiveEvents,
    'finished_at': finishedAt.toIso8601String(),
    'phases': <Map<String, Object?>>[for (final PhaseStats p in phases) p.toJson()],
  };
}
