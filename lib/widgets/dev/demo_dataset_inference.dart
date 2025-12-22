import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emg_mobile_analyzer/emg_ml_service_provider.dart';
import 'package:emg_mobile_analyzer/emg_normalizer_const.dart';

class DemoDatasetInferenceCard extends ConsumerStatefulWidget {
  const DemoDatasetInferenceCard({super.key});

  @override
  ConsumerState<DemoDatasetInferenceCard> createState() =>
      _DemoDatasetInferenceCardState();
}

class _DemoDatasetInferenceCardState
    extends ConsumerState<DemoDatasetInferenceCard> {
  bool _busy = false;
  String _status = '未実行';
  int _total = 0;
  int _correct = 0;

  static const _labels = ['paper', 'cizer', 'rock', 'pinch'];
  static final _labelToIndex = {
    for (var i = 0; i < _labels.length; i++) _labels[i]: i,
  };

  Future<void> _runDatasetTest() async {
    setState(() {
      _busy = true;
      _status = '実行中...';
      _total = 0;
      _correct = 0;
    });

    try {
      final ml = ref.read(emgMlServiceProvider);
      await ml.initModel();
      await loadEmgNormalizerFromAsset();

      final jsonStr = await DefaultAssetBundle.of(
        context,
      ).loadString('assets/model/demo_dataset.json');
      final List<dynamic> raw = json.decode(jsonStr) as List<dynamic>;

      int total = 0;
      int correct = 0;

      for (final entry in raw) {
        final map = entry as Map<String, dynamic>;
        final feats = (map['features'] as List<dynamic>)
            .map((e) => (e as num).toDouble())
            .toList(growable: false);
        final label = map['classLabel'] as String;

        // 正規化してから推論
        final norm = emgNormalizer.normalize10(feats);
        final pred = await ml.predictVector(norm.toList(growable: false));
        total++;
        final expectedIdx = _labelToIndex[label] ?? -1;
        if (expectedIdx == pred.labelIndex) correct++;
      }

      if (!mounted) return;
      setState(() {
        _busy = false;
        _total = total;
        _correct = correct;
        final acc = total == 0 ? 0.0 : correct / total * 100.0;
        _status = '完了: $correct / $total (acc ${acc.toStringAsFixed(1)}%)';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'エラー: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'データセット推論テスト（assets/emg_dataset.json）',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _busy ? null : _runDatasetTest,
                  icon: const Icon(Icons.analytics),
                  label: const Text('全件推論を実行'),
                ),
                const SizedBox(width: 12),
                if (_busy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('ステータス: $_status', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
