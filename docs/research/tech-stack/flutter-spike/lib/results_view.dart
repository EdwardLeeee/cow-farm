// 測試結果畫面：一張大字表格，使用者截圖就好。
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'report.dart';
import 'stats.dart';

class ResultsView extends StatelessWidget {
  const ResultsView({super.key, required this.report, this.onCopy, this.onRerun});

  final BenchmarkReport report;
  final VoidCallback? onCopy;
  final VoidCallback? onRerun;

  /// 表格的設計寬度（iPhone 14 Pro Max 寬 430 pt，扣掉左右各 16）。較窄的手機會等比縮小。
  static const double tableWidth = 398;

  @override
  Widget build(BuildContext context) {
    final BenchmarkReport r = report;
    final String refresh = r.displayRefreshRate == null
        ? '—'
        : r.displayRefreshRate!.toStringAsFixed(0);
    return ColoredBox(
      color: const Color(0xFFF7F3E8),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                '牧場測試：效能結果',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              if (r.interrupted) ...<Widget>[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  color: const Color(0xFFFFE0B2),
                  child: const Text(
                    '測試途中 app 曾離開畫面（鎖定或切到背景），數字可能不準，請按「再跑一次」。',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              _InfoLine('裝置', '${r.device.model} · ${r.device.os}'),
              _InfoLine('螢幕', '${r.screen} · 螢幕上限 $refresh Hz'),
              _InfoLine('App', '${r.appVersion} (${r.buildNumber}) · ${r.buildMode} · ${r.renderer}'),
              _InfoLine('版本', 'Flutter ${r.flutterVersion} · Dart ${r.dartVersion} · Flame ${r.flameVersion}'),
              _InfoLine('完成', _formatTime(r.finishedAt)),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: SizedBox(width: tableWidth, child: _ResultsTable(phases: r.phases)),
              ),
              const SizedBox(height: 8),
              Text(
                '畫面時間＝max(build, raster)，超過一格時間就會掉格；8.3 ms 是 120 Hz 一格，'
                '16.7 ms 是 60 Hz 一格。p99＝最慢 1% 的門檻。每段 ${r.config.phaseSeconds} 秒，'
                '前 ${r.config.settleSeconds} 秒不計。延遲＝vsync 到畫完。記憶體＝RSS。',
                style: const TextStyle(fontSize: 12, color: Color(0xFF555555), height: 1.35),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton(onPressed: onCopy, child: const Text('複製結果')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(onPressed: onRerun, child: const Text('再跑一次')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '$label  ',
              style: const TextStyle(color: Color(0xFF777777)),
            ),
            TextSpan(text: value),
          ],
        ),
        style: const TextStyle(fontSize: 14, height: 1.3),
      ),
    );
  }
}

/// 表格的一列：名稱、單位、從每段統計取值並格式化。
class _Row {
  const _Row(this.label, this.unit, this.value);

  final String label;
  final String unit;
  final String Function(PhaseStats s) value;
}

String formatMs(double? v) =>
    v == null ? '—' : (v >= 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(2));

String formatPct(double? v) {
  if (v == null) return '—';
  if (v == 0) return '0';
  return v < 1 ? v.toStringAsFixed(2) : v.toStringAsFixed(1);
}

String formatFps(double? v) => v == null ? '—' : v.toStringAsFixed(1);

String formatMb(double? v) => v == null ? '—' : v.toStringAsFixed(0);

final List<_Row> _rows = <_Row>[
  _Row('實際 FPS', '', (PhaseStats s) => formatFps(s.fps)),
  _Row('畫面時間 中位', 'ms', (PhaseStats s) => formatMs(s.frameMedianMs)),
  _Row('畫面時間 p99', 'ms', (PhaseStats s) => formatMs(s.frameP99Ms)),
  _Row('超過 8.3 ms', '%', (PhaseStats s) => formatPct(s.over120HzPct)),
  _Row('超過 16.7 ms', '%', (PhaseStats s) => formatPct(s.over60HzPct)),
  _Row('build p99', 'ms', (PhaseStats s) => formatMs(s.buildP99Ms)),
  _Row('raster p99', 'ms', (PhaseStats s) => formatMs(s.rasterP99Ms)),
  _Row('延遲 p99', 'ms', (PhaseStats s) => formatMs(s.latencyP99Ms)),
  _Row('記憶體峰值', 'MB', (PhaseStats s) => formatMb(s.rssMaxMb)),
  _Row('畫面數', '', (PhaseStats s) => '${s.frames}'),
];

class _ResultsTable extends StatelessWidget {
  const _ResultsTable({required this.phases});

  final List<PhaseStats> phases;

  static const TextStyle _value = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    fontFeatures: <ui.FontFeature>[ui.FontFeature.tabularFigures()],
  );

  @override
  Widget build(BuildContext context) {
    Widget cell(Widget child, {Alignment align = Alignment.centerRight}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: Align(alignment: align, child: child),
    );
    return Table(
      columnWidths: <int, TableColumnWidth>{
        0: const FlexColumnWidth(2.1),
        for (int i = 1; i <= phases.length; i++) i: const FlexColumnWidth(1),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: const TableBorder(
        horizontalInside: BorderSide(color: Color(0x22000000)),
        bottom: BorderSide(color: Color(0x44000000)),
      ),
      children: <TableRow>[
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFF6B8E23)),
          children: <Widget>[
            cell(
              const Text(
                '牛的數量',
                style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600),
              ),
              align: Alignment.centerLeft,
            ),
            for (final PhaseStats p in phases)
              cell(
                Text(
                  '${p.cows}',
                  style: _value.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        for (int i = 0; i < _rows.length; i++)
          TableRow(
            decoration: BoxDecoration(
              color: i.isEven ? const Color(0xFFFFFFFF) : const Color(0xFFF1EEE4),
            ),
            children: <Widget>[
              cell(
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(text: _rows[i].label),
                      if (_rows[i].unit.isNotEmpty)
                        TextSpan(
                          text: ' ${_rows[i].unit}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF777777)),
                        ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 15),
                ),
                align: Alignment.centerLeft,
              ),
              for (final PhaseStats p in phases) cell(Text(_rows[i].value(p), style: _value)),
            ],
          ),
      ],
    );
  }
}
