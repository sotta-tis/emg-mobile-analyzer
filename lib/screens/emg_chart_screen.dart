import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:emg_mobile_analyzer/ble_providers.dart';
import 'package:emg_mobile_analyzer/services/ble_service.dart';

class EmgLiveChartScreen extends ConsumerStatefulWidget {
  const EmgLiveChartScreen({super.key});

  @override
  ConsumerState<EmgLiveChartScreen> createState() => _EmgLiveChartScreenState();
}

class _EmgLiveChartScreenState extends ConsumerState<EmgLiveChartScreen> {
  /// 表示する最大サンプル数
  static const int maxPoints = 2000;

  /// グラフに使うデータバッファ
  final List<double> _data = [];

  /// y軸レンジ自動調整フラグ
  bool _autoYRange = true;

  /// 手動レンジのときの絶対値（例: ±_yRange）
  double _yRange = 1.0;

  /// 間引きステップ（1なら間引きなし、2なら2サンプルに1点表示）
  int _downSampleStep = 1;

  @override
  Widget build(BuildContext context) {
    final ble = ref.watch(bleServiceProvider);

    // BLEパケットを購読してデータをためる
    ref.listen<AsyncValue<BleDataPacket>>(blePacketProvider, (previous, next) {
      if (!next.hasValue) return;
      final packet = next.value!;

      // dispose後のsetStateを防ぐ
      if (!mounted) return;

      setState(() {
        _data.addAll(packet.samples);
        if (_data.length > maxPoints) {
          _data.removeRange(0, _data.length - maxPoints);
        }
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('sEMG Live'),
        actions: [
          IconButton(
            onPressed: () => ble.startScan(),
            icon: const Icon(Icons.bluetooth_searching),
          ),
        ],
      ),
      body: Column(
        children: [
          // グラフ
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildChart(),
            ),
          ),
          // 表示設定
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: _buildControls(),
          ),
          // 簡単な統計値
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: _buildStats(),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    if (_data.isEmpty) {
      return const Center(child: Text('データ待機中'));
    }

    // 間引きして描画用データを作成
    final spots = <FlSpot>[];
    for (int i = 0; i < _data.length; i += _downSampleStep) {
      spots.add(FlSpot(i.toDouble(), _data[i]));
    }

    // y軸レンジ決定
    double minY;
    double maxY;
    if (_autoYRange) {
      minY = _data.reduce(math.min);
      maxY = _data.reduce(math.max);

      // レンジが極端に狭いときは少しマージンを持たせる
      if ((maxY - minY).abs() < 1e-6) {
        minY -= 0.5;
        maxY += 0.5;
      }
    } else {
      minY = -_yRange;
      maxY = _yRange;
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: _data.length.toDouble(),
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
        gridData: const FlGridData(show: true),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
      ),
    );
  }

  /// 表示レンジや間引きのコントロールUI
  Widget _buildControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // y軸レンジ設定
        Row(
          children: [
            Switch(
              value: _autoYRange,
              onChanged: (v) {
                setState(() {
                  _autoYRange = v;
                });
              },
            ),
            const Text('Yレンジ自動調整'),
            const Spacer(),
            if (!_autoYRange)
              SizedBox(
                width: 200,
                child: Row(
                  children: [
                    const Text('±'),
                    Expanded(
                      child: Slider(
                        value: _yRange,
                        min: 0.1,
                        max: 5.0,
                        divisions: 49,
                        label: _yRange.toStringAsFixed(1),
                        onChanged: (v) {
                          setState(() {
                            _yRange = v;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        // 間引き設定
        Row(
          children: [
            const Text('表示間引き:'),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: _downSampleStep,
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 (間引きなし)')),
                DropdownMenuItem(value: 2, child: Text('2')),
                DropdownMenuItem(value: 4, child: Text('4')),
                DropdownMenuItem(value: 8, child: Text('8')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _downSampleStep = v;
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  /// 現在バッファしているデータの簡単な統計値表示
  Widget _buildStats() {
    if (_data.isEmpty) {
      return const SizedBox.shrink();
    }

    final minVal = _data.reduce(math.min);
    final maxVal = _data.reduce(math.max);

    double sumSq = 0;
    for (final v in _data) {
      sumSq += v * v;
    }
    final rms = math.sqrt(sumSq / _data.length);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('min: ${minVal.toStringAsFixed(3)}'),
        Text('max: ${maxVal.toStringAsFixed(3)}'),
        Text('RMS: ${rms.toStringAsFixed(3)}'),
        Text('samples: ${_data.length}'),
      ],
    );
  }
}
