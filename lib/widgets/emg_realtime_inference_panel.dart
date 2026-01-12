import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'package:emg_mobile_analyzer/ble_providers.dart';
import 'package:emg_mobile_analyzer/services/ble_service.dart';
import 'package:emg_mobile_analyzer/services/emg_window_buffer.dart';
import 'package:emg_mobile_analyzer/services/emg_feature_extractor.dart';
import 'package:emg_mobile_analyzer/services/emg_ml_service.dart';
import 'package:emg_mobile_analyzer/emg_normalizer_const.dart';
import 'package:emg_mobile_analyzer/emg_prediction.dart';

final emgMlServiceProvider = Provider<EmgMlService>((ref) {
  return EmgMlService();
});

class EmgRealtimeInferencePanel extends ConsumerStatefulWidget {
  const EmgRealtimeInferencePanel({
    super.key,
    this.labels = const ['paper', 'cizer', 'rock', 'pinch'],
  });

  final List<String> labels;

  @override
  ConsumerState<EmgRealtimeInferencePanel> createState() =>
      _EmgRealtimeInferencePanelState();
}

class _EmgRealtimeInferencePanelState
    extends ConsumerState<EmgRealtimeInferencePanel> {
  late final EmgWindowBuffer _buffer;
  StreamSubscription<BleDataPacket>? _sub;

  EmgPrediction? _latest;
  bool _busy = false;
  String _status = 'waiting';

  // FPS計測用
  int _inferenceCount = 0;
  double _fps = 0.0;
  Timer? _fpsTimer;

  // 精度測定用
  final Map<String, double> _accuracies = {};
  final Map<String, double> _stabilities = {}; // Stability mode
  final Map<String, double> _confidences = {}; // Confidence stability
  bool _measuring = false;
  String? _measuringLabel;
  int _correctCount = 0;
  int _totalCount = 0;
  final List<String> _predictedLabels = []; // 測定中の予測ラベル履歴
  final List<double> _maxConfidences = []; // 測定中の最大確率履歴
  static const measureDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();

    _buffer = EmgWindowBuffer(windowSize: 150, hopSize: 50);

    // FPS計測タイマー（1秒ごとに更新）
    _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _fps = _inferenceCount.toDouble();
          _inferenceCount = 0;
        });
      }
    });

    final ble = ref.read(bleServiceProvider);
    final ml = ref.read(emgMlServiceProvider);

    _sub = ble.packetStream.listen((pkt) async {
      _buffer.addSamples(pkt.samples, pkt.timestamp);
      final windows = _buffer.popReadyWindows();
      if (windows.isEmpty || _busy) return;

      _busy = true;
      try {
        final w = windows.last;

        // ===== 特徴量 → 正規化 =====
        final normalized = EmgFeatureExtractor.computeNormalizedVector(
          w.samples,
          normalizer: emgNormalizer,
        );

        // ===== 推論 =====
        final pred = await ml.predictVector(normalized.toList(growable: false));

        if (!mounted) return;
        _inferenceCount++;
        setState(() {
          _latest = pred;
          _status = 'ok';

          // 精度測定中の場合、一致判定と統計収集
          if (_measuring && _measuringLabel != null) {
            _totalCount++;
            final predictedLabel =
                (pred.labelIndex >= 0 && pred.labelIndex < widget.labels.length)
                    ? widget.labels[pred.labelIndex]
                    : null;
            if (predictedLabel == _measuringLabel) {
              _correctCount++;
            }

            // 予測ラベル履歴を保存
            if (predictedLabel != null) {
              _predictedLabels.add(predictedLabel);
            }

            // 最大確率を保存
            if (pred.scores.isNotEmpty) {
              final maxConf = pred.scores.reduce((a, b) => a > b ? a : b);
              _maxConfidences.add(maxConf);
            }
          }
        });
      } on PlatformException catch (e) {
        setState(() {
          _status = "PlatformException: ${e.code} ${e.message} ${e.details}";
        });
      } catch (e) {
        setState(() {
          _status = "error: $e";
        });
      } finally {
        _busy = false;
      }
    });
  }

  @override
  void dispose() {
    _fpsTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  Widget _buildMetricRow(String name, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(name, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 6,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            child: Text(
              '${value.toStringAsFixed(1)}%',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _measureAccuracy(String label) async {
    if (_measuring) return;

    setState(() {
      _measuring = true;
      _measuringLabel = label;
      _correctCount = 0;
      _totalCount = 0;
      _predictedLabels.clear();
      _maxConfidences.clear();
      _status = 'Measuring "$label"...';
    });

    await Future.delayed(measureDuration);

    if (!mounted) return;

    final accuracy =
        _totalCount > 0 ? (_correctCount / _totalCount) * 100 : 0.0;

    // Stability mode: 最頻値（モード）の出現割合
    double stability = 0.0;
    if (_predictedLabels.isNotEmpty) {
      final labelCounts = <String, int>{};
      for (final lbl in _predictedLabels) {
        labelCounts[lbl] = (labelCounts[lbl] ?? 0) + 1;
      }
      final maxCount = labelCounts.values.reduce((a, b) => a > b ? a : b);
      stability = (maxCount / _predictedLabels.length) * 100;
    }

    // Confidence stability: 最大確率の平均
    double confidence = 0.0;
    if (_maxConfidences.isNotEmpty) {
      final sum = _maxConfidences.reduce((a, b) => a + b);
      confidence = (sum / _maxConfidences.length) * 100;
    }

    setState(() {
      _measuring = false;
      _accuracies[label] = accuracy;
      _stabilities[label] = stability;
      _confidences[label] = confidence;
      _status =
          'Measured "$label": Acc=${accuracy.toStringAsFixed(1)}% Stab=${stability.toStringAsFixed(1)}% Conf=${confidence.toStringAsFixed(1)}%';
      _measuringLabel = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pred = _latest;

    final label =
        (pred == null ||
                pred.labelIndex < 0 ||
                pred.labelIndex >= widget.labels.length)
            ? '-'
            : widget.labels[pred.labelIndex];

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  'EMG Inference (CoreML)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _fps > 0 ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_fps.toStringAsFixed(1)} fps',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                const Text('Label: ', style: TextStyle(fontSize: 16)),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(_status),
              ],
            ),

            const SizedBox(height: 8),

            if (pred != null)
              Column(
                children: List.generate(pred.scores.length, (i) {
                  final name = widget.labels[i];
                  final s = pred.scores[i].clamp(0.0, 1.0);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(width: 70, child: Text(name)),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: s,
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 48,
                          child: Text(
                            s.toStringAsFixed(2),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            const Text(
              'Accuracy Measurement',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  widget.labels
                      .map(
                        (label) => ElevatedButton(
                          onPressed:
                              _measuring ? null : () => _measureAccuracy(label),
                          child: Text(label.toUpperCase()),
                        ),
                      )
                      .toList(),
            ),

            const SizedBox(height: 12),

            ...widget.labels.map((label) {
              final accuracy = _accuracies[label] ?? 0.0;
              final stability = _stabilities[label] ?? 0.0;
              final confidence = _confidences[label] ?? 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),

                    // Accuracy
                    _buildMetricRow('Accuracy', accuracy, Colors.blue),

                    // Stability mode
                    _buildMetricRow('Stability', stability, Colors.green),

                    // Confidence
                    _buildMetricRow('Confidence', confidence, Colors.orange),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
