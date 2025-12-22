import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class EmgWaveformChart extends StatefulWidget {
  const EmgWaveformChart({
    super.key,
    required this.dataSource,
    this.maxPoints = 2000,
    this.refreshInterval = const Duration(milliseconds: 50), // 20fps
    this.downsample = 1, // 2なら2点に1点、4なら4点に1点表示
    this.showGrid = true,
    this.showLeftTitles = true,
    this.fixedMinY,
    this.fixedMaxY,
  });

  /// 外側で保持している波形バッファを返す関数
  final List<double> Function() dataSource;

  /// 画面に表示する最大点数
  final int maxPoints;

  /// UI更新間隔（重いなら 100ms でもOK）
  final Duration refreshInterval;

  /// 表示間引き（負荷が高い時に上げる）
  final int downsample;

  final bool showGrid;
  final bool showLeftTitles;

  /// 縦軸を固定したい場合に指定（例: -2.0, 2.0）。未指定なら自動スケーリング。
  final double? fixedMinY;
  final double? fixedMaxY;

  @override
  State<EmgWaveformChart> createState() => _EmgWaveformChartState();
}

class _EmgWaveformChartState extends State<EmgWaveformChart> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.refreshInterval, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant EmgWaveformChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // refreshInterval が変わったらタイマーを貼り直す
    if (oldWidget.refreshInterval != widget.refreshInterval) {
      _timer?.cancel();
      _timer = Timer.periodic(widget.refreshInterval, (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.dataSource();
    if (data.isEmpty) {
      return const Center(child: Text('データ待機中'));
    }

    // 表示範囲だけ切り出し
    final start = math.max(0, data.length - widget.maxPoints);
    final view = data.sublist(start);

    // 間引き（負荷対策）
    final ds = widget.downsample < 1 ? 1 : widget.downsample;
    final int n = (view.length / ds).ceil();

    // min/max を求める（Y軸レンジ）
    double minY;
    double maxY;
    if (widget.fixedMinY != null && widget.fixedMaxY != null) {
      minY = widget.fixedMinY!;
      maxY = widget.fixedMaxY!;
      // min==max でレンジゼロになるのを防ぐ
      if (minY == maxY) {
        minY -= 0.5;
        maxY += 0.5;
      }
    } else {
      double localMin = double.infinity;
      double localMax = -double.infinity;
      for (int i = 0; i < view.length; i += ds) {
        final v = view[i];
        if (v < localMin) localMin = v;
        if (v > localMax) localMax = v;
      }
      if (!localMin.isFinite || !localMax.isFinite) {
        return const Center(child: Text('データが不正です'));
      }
      final ySpan = (localMax - localMin).abs();
      final yMargin = ySpan < 1e-6 ? 0.5 : 0.1 * ySpan;
      minY = localMin - yMargin;
      maxY = localMax + yMargin;
    }

    // spots を生成（必要点数のみ）
    final spots = List<FlSpot>.generate(n, (j) {
      final i = j * ds;
      final y = view[i < view.length ? i : view.length - 1];
      return FlSpot(j.toDouble(), y);
    }, growable: false);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (n - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
            barWidth: 1,
          ),
        ],
        gridData: FlGridData(show: widget.showGrid),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: widget.showLeftTitles),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: true),
      ),
    );
  }
}
