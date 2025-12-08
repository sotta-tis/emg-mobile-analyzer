import 'package:flutter/material.dart';
import 'package:emg_mobile_analyzer/features/recording/services/data_saver_service.dart';
import 'package:emg_mobile_analyzer/features/recording/services/recording_buffer.dart';

class RecordingWidget extends StatefulWidget {
  final RecordingBuffer recordingBuffer;
  final DataSaverService dataSaver;
  final bool isConnected;

  const RecordingWidget({
    Key? key,
    required this.recordingBuffer,
    required this.dataSaver,
    required this.isConnected,
  }) : super(key: key);

  @override
  State<RecordingWidget> createState() => _RecordingWidgetState();
}

class _RecordingWidgetState extends State<RecordingWidget>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  String _statusText = '';
  int _remainingMs = 0;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 5000),
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.linear),
    );

    // コールバック設定
    widget.recordingBuffer.onRecordingProgress = (remainingMs) {
      setState(() {
        _remainingMs = remainingMs;
        _isRecording = true;
      });
    };

    widget.recordingBuffer.onRecordingComplete = (label, samples) async {
      setState(() {
        _isRecording = false;
        _remainingMs = 0;
        _statusText = '保存中...';
      });

      _progressController.reset();

      try {
        final filename = await widget.dataSaver.saveSample(label, samples);
        setState(() {
          _statusText = '保存完了: $filename';
        });

        // 3秒後にステータスをクリア
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _statusText = '';
            });
          }
        });
      } catch (e) {
        setState(() {
          _statusText = '保存エラー: $e';
        });
      }
    };

    widget.recordingBuffer.onError = (error) {
      setState(() {
        _statusText = 'エラー: $error';
        _isRecording = false;
        _remainingMs = 0;
      });
      _progressController.reset();
    };
  }

  void _startRecording(String label) {
    if (!widget.isConnected) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('BLEデバイスに接続してください')));
      return;
    }

    if (!widget.dataSaver.hasActiveSession) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('セッションを開始してください')));
      return;
    }

    widget.recordingBuffer.startRecording(label);
    _progressController.forward();

    setState(() {
      _statusText = '$label を録画中...';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Row(
              children: [
                const Icon(Icons.fiber_manual_record, color: Colors.red),
                const SizedBox(width: 8),
                const Text(
                  'データ録画',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (widget.dataSaver.hasActiveSession)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'セッション開始済み',
                      style: TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // 進行状況表示
            if (_isRecording) ...[
              Text(
                '残り時間: ${(_remainingMs / 1000).toStringAsFixed(1)}秒',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return LinearProgressIndicator(
                    value: _progressAnimation.value,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            // ステータス表示
            if (_statusText.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_statusText, style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(height: 16),
            ],

            // ラベルボタン
            const Text(
              'ラベルを選択 (5秒間録画)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children:
                  DataSaverService.defaultLabels.map((label) {
                    return ElevatedButton.icon(
                      onPressed:
                          _isRecording ? null : () => _startRecording(label),
                      icon: _getIconForLabel(label),
                      label: Text(label.toUpperCase()),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Icon _getIconForLabel(String label) {
    switch (label.toLowerCase()) {
      case 'tripod':
        return const Icon(Icons.touch_app);
      case 'fist':
        return const Icon(Icons.sports_mma);
      case 'open':
        return const Icon(Icons.pan_tool);
      case 'pinch':
        return const Icon(Icons.gesture);
      case 'point':
        return const Icon(Icons.touch_app);
      case 'rest':
        return const Icon(Icons.airline_seat_recline_normal);
      default:
        return const Icon(Icons.radio_button_checked);
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }
}
