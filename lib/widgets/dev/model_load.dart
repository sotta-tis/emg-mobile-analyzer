import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emg_mobile_analyzer/emg_ml_service_provider.dart';

class ModelLoadTestWidget extends ConsumerStatefulWidget {
  const ModelLoadTestWidget({super.key});

  @override
  ConsumerState<ModelLoadTestWidget> createState() =>
      _ModelLoadTestWidgetState();
}

class _ModelLoadTestWidgetState extends ConsumerState<ModelLoadTestWidget> {
  bool _loading = false;
  String _status = '未実行';

  Future<void> _loadModel() async {
    setState(() {
      _loading = true;
      _status = '読み込み中...';
    });

    final ml = ref.read(emgMlServiceProvider);
    try {
      await ml.initModel();
      setState(() {
        _status = 'OK: モデル読み込み成功';
      });
    } catch (e) {
      setState(() {
        _status = 'エラー: $e';
      });
    } finally {
      setState(() {
        _loading = false;
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
              'Core ML モデルロードテスト',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _loading ? null : _loadModel,
                  icon: const Icon(Icons.download_done),
                  label: const Text('モデルを読み込む'),
                ),
                const SizedBox(width: 12),
                if (_loading)
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
