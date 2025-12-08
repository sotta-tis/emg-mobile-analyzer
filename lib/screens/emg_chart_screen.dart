// lib/features/emg/screens/emg_live_chart_screen.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:emg_mobile_analyzer/ble_providers.dart';
import 'package:emg_mobile_analyzer/services/ble_service.dart';
import 'package:emg_mobile_analyzer/services/emg_window_buffer.dart';
import 'package:emg_mobile_analyzer/services/emg_feature_extractor.dart';

class EmgLiveChartScreen extends ConsumerStatefulWidget {
  const EmgLiveChartScreen({super.key});

  @override
  ConsumerState<EmgLiveChartScreen> createState() => _EmgLiveChartScreenState();
}

class _EmgLiveChartScreenState extends ConsumerState<EmgLiveChartScreen> {
  static const int maxPoints = 2000;

  final List<double> _data = [];

  late final EmgWindowBuffer _windowBuffer;
  EmgFeatures? _latestFeatures;

  @override
  void initState() {
    super.initState();

    // 150ms window, 50ms hop を想定（1kHz）
    _windowBuffer = EmgWindowBuffer(windowSize: 150, hopSize: 50);
  }

  @override
  Widget build(BuildContext context) {
    final ble = ref.watch(bleServiceProvider);

    // BLEパケットを購読
    ref.listen<AsyncValue<BleDataPacket>>(blePacketProvider, (previous, next) {
      if (!next.hasValue) return;
      final packet = next.value!;

      // dispose後のsetStateを防ぐ
      if (!mounted) return;

      setState(() {
        // グラフ用バッファ
        _data.addAll(packet.samples);
        if (_data.length > maxPoints) {
          _data.removeRange(0, _data.length - maxPoints);
        }

        // ウィンドウバッファに追加
        _windowBuffer.addSamples(packet.samples, packet.timestamp);
        final windows = _windowBuffer.popReadyWindows();

        // 切り出された各ウィンドウについて特徴量を計算し、
        // 一番最後のウィンドウの特徴量を画面表示用として保持
        for (final w in windows) {
          _latestFeatures = EmgFeatureExtractor.compute(w.samples);
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
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildChart(),
            ),
          ),
          const Divider(height: 1),
          // 最新ウィンドウの特徴量
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildFeatureView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    if (_data.isEmpty) {
      return const Center(child: Text('データ待機中'));
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < _data.length; i++) {
      spots.add(FlSpot(i.toDouble(), _data[i]));
    }

    final minY = _data.reduce(math.min);
    final maxY = _data.reduce(math.max);
    final yMargin =
        (maxY - minY).abs() < 1e-6 ? 0.5 : 0.1 * (maxY - minY).abs();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: _data.length.toDouble(),
        minY: minY - yMargin,
        maxY: maxY + yMargin,
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

  Widget _buildFeatureView() {
    final f = _latestFeatures;
    if (f == null) {
      return const Center(child: Text('特徴量計算待ち'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '最新ウィンドウの特徴量',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: [
              _featureRow('MVA', f.mva),
              _featureRow('CPS', f.cps),
              _featureRow('LFO', f.lfo),
              _featureRow('VAR', f.variance),
              _featureRow('CPS', f.aw),
              _featureRow('COMP', f.complexity),
              _featureRow('AR1', f.ar[0]),
              _featureRow('AR2', f.ar[1]),
              _featureRow('AR3', f.ar[2]),
              _featureRow('AR4', f.ar[3]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _featureRow(String name, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(name)),
          const SizedBox(width: 8),
          Text(value.toStringAsFixed(4)),
        ],
      ),
    );
  }
}
