import 'package:flutter/material.dart';
import '../services/data_saver_service.dart';

class SessionControlWidget extends StatefulWidget {
  final DataSaverService dataSaver;

  const SessionControlWidget({Key? key, required this.dataSaver})
    : super(key: key);

  @override
  State<SessionControlWidget> createState() => _SessionControlWidgetState();
}

class _SessionControlWidgetState extends State<SessionControlWidget> {
  String _statusText = 'セッション未開始';
  bool _isProcessing = false;

  Future<void> _startSession() async {
    setState(() {
      _isProcessing = true;
      _statusText = 'セッション開始中...';
    });

    try {
      final session = await widget.dataSaver.startSession();
      setState(() {
        _statusText = 'セッション開始: ${session.sessionId}';
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _statusText = 'セッション開始エラー: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _endSession() async {
    setState(() {
      _isProcessing = true;
      _statusText = 'セッション終了中...';
    });

    try {
      widget.dataSaver.endSession();
      setState(() {
        _statusText = 'セッション終了';
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _statusText = 'セッション終了エラー: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _exportData() async {
    setState(() {
      _isProcessing = true;
      _statusText = 'データエクスポート中...';
    });

    try {
      await widget.dataSaver.exportSessionData();
      setState(() {
        _statusText = 'エクスポート完了';
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _statusText = 'エクスポートエラー: $e';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveSession = widget.dataSaver.hasActiveSession;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Row(
              children: [
                Icon(
                  hasActiveSession
                      ? Icons.play_circle_filled
                      : Icons.play_circle_outline,
                  color: hasActiveSession ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                const Text(
                  'セッション管理',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ステータス表示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    hasActiveSession
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    hasActiveSession ? Icons.check_circle : Icons.info_outline,
                    color: hasActiveSession ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusText,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // セッション情報
            if (hasActiveSession) ...[
              const Text(
                'セッション情報',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildInfoRow('ID', widget.dataSaver.currentSession!.sessionId),
              _buildInfoRow(
                '開始時刻',
                _formatDateTime(widget.dataSaver.currentSession!.startTime),
              ),
              _buildInfoRow(
                'サンプル数',
                '${widget.dataSaver.currentSession!.sampleCounter}',
              ),
              const SizedBox(height: 16),
            ],

            // コントロールボタン
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                ElevatedButton.icon(
                  onPressed:
                      (!hasActiveSession && !_isProcessing)
                          ? _startSession
                          : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('セッション開始'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed:
                      (hasActiveSession && !_isProcessing) ? _endSession : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('セッション終了'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed:
                      (hasActiveSession && !_isProcessing) ? _exportData : null,
                  icon: const Icon(Icons.share),
                  label: const Text('データ共有'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),

            // 処理中インジケーター
            if (_isProcessing) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }
}
