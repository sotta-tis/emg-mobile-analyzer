import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emg_mobile_analyzer/emg_ml_service_provider.dart';
import 'package:emg_mobile_analyzer/emg_prediction.dart';
import 'package:emg_mobile_analyzer/emg_normalizer_const.dart';

/// demo_dataset.json を使って on-device 学習を試すための簡易ウィジェット
class DemoTrainCard extends ConsumerStatefulWidget {
  const DemoTrainCard({super.key});

  @override
  ConsumerState<DemoTrainCard> createState() => _DemoTrainCardState();
}

class _DemoTrainCardState extends ConsumerState<DemoTrainCard> {
  bool _busy = false;
  String _status = '未実行';

  Future<void> _runTraining() async {
    setState(() {
      _busy = true;
      _status = '学習中...';
    });

    try {
      final ml = ref.read(emgMlServiceProvider);
      await ml.initModel();
      await loadEmgNormalizerFromAsset();

      // デモデータセットを読み込み
      final jsonStr = await DefaultAssetBundle.of(
        context,
      ).loadString('assets/model/demo_dataset.json');
      final List<dynamic> raw = json.decode(jsonStr) as List<dynamic>;

      final samples = <LabeledEmgSample>[];
      int skipped = 0;

      for (final entry in raw) {
        final map = entry as Map<String, dynamic>;
        final feats = (map['features'] as List<dynamic>)
            .map((e) => (e as num).toDouble())
            .toList(growable: false);
        final label = map['classLabel'] as String? ?? '';

        // ラベルを index に変換
        final labelIndex = EmgLabels.names.indexOf(label);
        if (labelIndex < 0) {
          skipped++;
          continue;
        }

        // モデルと同じ正規化を適用して学習データを作成
        final normalized = emgNormalizer.normalize10(feats);
        samples.add(
          LabeledEmgSample(
            features: normalized.toList(growable: false),
            labelIndex: labelIndex,
          ),
        );
      }

      if (samples.isEmpty) {
        throw StateError('データセットから有効なサンプルを取得できませんでした');
      }

      final result = await ml.train(samples);
      final updatedPath =
          result['updatedModelPath'] as String? ?? '(path unknown)';
      final count = result['sampleCount'] as int? ?? samples.length;

      if (!mounted) return;
      setState(() {
        _busy = false;
        _status =
            '完了: $count サンプルで学習。保存先: $updatedPath${skipped > 0 ? ' / スキップ: $skipped' : ''}';
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
              'デモデータセット学習テスト',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'assets/model/demo_dataset.json を使って EmgMlService.train を呼び出します。',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _busy ? null : _runTraining,
                  icon: const Icon(Icons.school),
                  label: const Text('データセットで学習'),
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
