import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:emg_mobile_analyzer/ble_providers.dart';
import 'package:emg_mobile_analyzer/services/emg_window_buffer.dart';
import 'package:emg_mobile_analyzer/services/emg_feature_extractor.dart';
import 'package:emg_mobile_analyzer/services/emg_ml_service.dart';
import 'package:emg_mobile_analyzer/emg_normalizer_const.dart';
import 'package:emg_mobile_analyzer/emg_ml_service_provider.dart';
import 'package:emg_mobile_analyzer/services/ble_service.dart';

class EmgInferencePanel extends ConsumerStatefulWidget {
  const EmgInferencePanel({super.key});

  @override
  ConsumerState<EmgInferencePanel> createState() => _EmgInferencePanelState();
}

class _EmgInferencePanelState extends ConsumerState<EmgInferencePanel> {
  // ラベル順（学習時の順と一致させる）
  static const labels = ["paper", "cizer", "rock", "pinch"];

  // window/hop（あなたの EmgWindowBuffer に合わせる）
  final EmgWindowBuffer _windowBuffer = EmgWindowBuffer(
    windowSize: 150,
    hopSize: 50,
  );

  StreamSubscription<BleDataPacket>? _sub;
  bool _running = false;
  bool _busyInfer = false;

  String _status = "idle";
  int _totalWindows = 0;

  // 表示用
  List<double>? _latestScores;
  int? _latestLabelIndex;
  DateTime? _latestTs;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (_running) return;

    _windowBuffer.clear();
    _latestScores = null;
    _latestLabelIndex = null;
    _latestTs = null;
    _totalWindows = 0;

    final ml = ref.read(emgMlServiceProvider);
    setState(() {
      _running = true;
      _status = "running";
    });

    _sub?.cancel();
    _sub = ref.read(bleServiceProvider).packetStream.listen((pkt) async {
      _windowBuffer.addSamples(pkt.samples, pkt.timestamp);

      final windows = _windowBuffer.popReadyWindows();
      if (windows.isEmpty) return;

      // 最新windowだけ推論（連続で複数window来る時も、最後だけ回す）
      final w = windows.last;
      _totalWindows += windows.length;

      // 推論が重くて詰まるなら、busy時はスキップ
      if (_busyInfer) return;

      _busyInfer = true;
      try {
        final normVec = EmgFeatureExtractor.computeNormalizedVector(
          w.samples,
          normalizer: emgNormalizer,
        );

        // MLへ渡す形に合わせる（EmgMlServiceがEmgFeaturesを受ける設計なら変更が必要）
        // ここでは MethodChannel 側が "features": [double] を受け取る前提で直接呼ぶAPIを追加するのが楽。
        // 既存の predict(EmgFeatures) を崩したくないなら、predictVector を EmgMlService に追加してください。
        final result = await ml.predictVector(normVec);

        if (!mounted) return;
        setState(() {
          _latestScores = result.scores;
          _latestLabelIndex = result.labelIndex;
          _latestTs = DateTime.now();
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _status = "error: $e";
        });
      } finally {
        _busyInfer = false;
      }
    });
  }

  Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    setState(() {
      _running = false;
      _status = "stopped";
    });
  }

  @override
  Widget build(BuildContext context) {
    final scores = _latestScores;

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Inference (Realtime)",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(_status, style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                ElevatedButton(
                  onPressed: _running ? null : _start,
                  child: const Text("START"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _running ? _stop : null,
                  child: const Text("STOP"),
                ),
                const Spacer(),
                Text("windows: $_totalWindows"),
              ],
            ),

            const SizedBox(height: 12),
            if (scores == null) ...[
              const Text("No prediction yet."),
            ] else ...[
              _buildTopLabel(),
              const SizedBox(height: 8),
              ...List.generate(labels.length, (i) {
                final v = scores[i];
                return _ScoreBar(label: labels[i], value: v);
              }),
              const SizedBox(height: 6),
              if (_latestTs != null)
                Text(
                  "updated: ${_latestTs!.toIso8601String()}",
                  style: const TextStyle(fontSize: 11),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopLabel() {
    final idx = _latestLabelIndex ?? -1;
    final name = (idx >= 0 && idx < labels.length) ? labels[idx] : "unknown";
    final conf = (_latestScores == null) ? 0.0 : _latestScores![idx].toDouble();

    return Row(
      children: [
        const Text("Top: ", style: TextStyle(fontWeight: FontWeight.bold)),
        Text(
          name.toUpperCase(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 12),
        Text("conf: ${conf.toStringAsFixed(3)}"),
      ],
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final double value;

  const _ScoreBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final v = value.isFinite ? value : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(label)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: v.clamp(0.0, 1.0),
                minHeight: 10,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 56, child: Text(v.toStringAsFixed(3))),
        ],
      ),
    );
  }
}
