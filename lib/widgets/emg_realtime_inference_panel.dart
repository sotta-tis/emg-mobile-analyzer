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

  // 精度測定用
  final Map<String, double> _accuracies = {};
  bool _measuring = false;
  String? _measuringLabel;
  int _correctCount = 0;
  int _totalCount = 0;
  static const measureDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();

    _buffer = EmgWindowBuffer(windowSize: 150, hopSize: 50);

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
        setState(() {
          _latest = pred;
          _status = 'ok';

          // 精度測定中の場合、一致判定
          if (_measuring && _measuringLabel != null) {
            _totalCount++;
            final predictedLabel =
                (pred.labelIndex >= 0 && pred.labelIndex < widget.labels.length)
                    ? widget.labels[pred.labelIndex]
                    : null;
            if (predictedLabel == _measuringLabel) {
              _correctCount++;
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
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _measureAccuracy(String label) async {
    if (_measuring) return;

    setState(() {
      _measuring = true;
      _measuringLabel = label;
      _correctCount = 0;
      _totalCount = 0;
      _status = 'Measuring "$label"...';
    });

    await Future.delayed(measureDuration);

    if (!mounted) return;

    final accuracy =
        _totalCount > 0 ? (_correctCount / _totalCount) * 100 : 0.0;

    setState(() {
      _measuring = false;
      _accuracies[label] = accuracy;
      _status =
          'Measured "$label": ${accuracy.toStringAsFixed(1)}% ($_correctCount/$_totalCount)';
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
            const Text(
              'EMG Inference (CoreML)',
              style: TextStyle(fontWeight: FontWeight.bold),
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
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 70, child: Text(label)),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: accuracy / 100,
                        minHeight: 8,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          accuracy >= 80
                              ? Colors.green
                              : accuracy >= 60
                              ? Colors.orange
                              : Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 56,
                      child: Text(
                        '${accuracy.toStringAsFixed(1)}%',
                        textAlign: TextAlign.right,
                      ),
                    ),
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
