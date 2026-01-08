// lib/features/emg/screens/ble_and_chart_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:emg_mobile_analyzer/ble_providers.dart';
import 'package:emg_mobile_analyzer/services/ble_service.dart';
import 'package:emg_mobile_analyzer/emg_providers.dart';
import 'package:emg_mobile_analyzer/services/emg_feature_extractor.dart';

import 'package:emg_mobile_analyzer/widgets/emg_wave_form_chart.dart';
import 'package:emg_mobile_analyzer/widgets/ble_manager_panel.dart';
import 'package:emg_mobile_analyzer/widgets/emg_features_panel.dart';
import 'package:emg_mobile_analyzer/widgets/emg_label_record_panel.dart';
import 'package:emg_mobile_analyzer/widgets/emg_realtime_inference_panel.dart';

class EmgScreen extends ConsumerStatefulWidget {
  const EmgScreen({super.key});

  @override
  ConsumerState<EmgScreen> createState() => _EmgScreenState();
}

class _EmgScreenState extends ConsumerState<EmgScreen> {
  static const int maxPoints = 2000;

  final List<double> _data = [];
  StreamSubscription<BleDataPacket>? _sub;

  EmgFeatures? _latestFeatures;

  @override
  void initState() {
    super.initState();

    final ble = ref.read(bleServiceProvider);
    final windowBuffer = ref.read(emgWindowBufferProvider);

    _sub = ble.packetStream.listen((pkt) {
      // dispose後の呼び出し対策
      if (!mounted) return;

      // 1) 波形用：そのまま流す
      _data.addAll(pkt.samples);
      if (_data.length > maxPoints) {
        _data.removeRange(0, _data.length - maxPoints);
      }

      // 2) 特徴量用：windowに切って最後のものを表示
      windowBuffer.addSamples(pkt.samples, pkt.timestamp);
      final windows = windowBuffer.popReadyWindows();
      if (windows.isNotEmpty) {
        final last = windows.last;
        final feat = EmgFeatureExtractor.compute(
          last.samples,
          fs: 1000.0,
          lfoCutoffHz: 150.0,
        );
        setState(() {
          _latestFeatures = feat;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('sEMG Analyzer')),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: BleManagerPanel()),
          const SliverToBoxAdapter(child: Divider(height: 1)),

          // 波形チャート（高さを固定してスクロール可能に）
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                height: 260, // 画面に収まる程度の高さ。必要なら調整
                child: EmgWaveformChart(
                  dataSource: () => _data,
                  maxPoints: maxPoints,
                  refreshInterval: const Duration(milliseconds: 50), // 20fps
                  downsample: 2, // 重ければ 4 に
                  fixedMinY: -1.0, // 縦軸固定（データ振幅に合わせて調整可）
                  fixedMaxY: 1.0,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: EmgRealtimeInferencePanel(),
            ),
          ),

          // 特徴量パネル
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: EmgFeaturesPanel(),
            ),
          ),
          // ラベル付けパネル
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: EmgLabelRecordPanel(),
            ),
          ),
        ],
      ),
    );
  }
}
