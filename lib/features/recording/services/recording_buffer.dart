import 'dart:async';
import 'package:emg_mobile_analyzer/features/ble/services/ble_service.dart';
import 'package:emg_mobile_analyzer/features/recording/services/data_saver_service.dart';

class RecordingBuffer {
  static const int recordingDurationMs = 5000; // 5秒間

  final List<DataSample> _buffer = [];
  Timer? _recordingTimer;
  DateTime? _recordingStartTime;

  // コールバック
  Function(String label, List<DataSample> samples)? onRecordingComplete;
  Function(int remainingMs)? onRecordingProgress;
  Function(String error)? onError;

  bool _isRecording = false;
  String? _currentLabel;

  // 録画開始
  void startRecording(String label) {
    if (_isRecording) {
      onError?.call('既に録画中です');
      return;
    }

    _isRecording = true;
    _currentLabel = label;
    _recordingStartTime = DateTime.now();
    _buffer.clear();

    // プログレス更新タイマー
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }

      final elapsed =
          DateTime.now().difference(_recordingStartTime!).inMilliseconds;
      final remaining = recordingDurationMs - elapsed;

      if (remaining <= 0) {
        timer.cancel();
        _completeRecording();
      } else {
        onRecordingProgress?.call(remaining);
      }
    });
  }

  // BLEデータ受信時の処理
  void addBlePacket(BleDataPacket packet) {
    if (!_isRecording) return;

    final timestamp = packet.timestamp.millisecondsSinceEpoch;

    // パケット内の各サンプルをバッファに追加
    for (int i = 0; i < packet.samples.length; i++) {
      final sample = DataSample(
        packetTimestamp: timestamp,
        seqPacket: packet.seq,
        sampleIdx: i,
        valueNorm: packet.samples[i],
      );
      _buffer.add(sample);
    }
  }

  // 録画完了処理
  void _completeRecording() {
    if (!_isRecording) return;

    _isRecording = false;

    if (_buffer.isNotEmpty && _currentLabel != null) {
      onRecordingComplete?.call(_currentLabel!, List.from(_buffer));
    }

    _buffer.clear();
    _currentLabel = null;
    _recordingStartTime = null;
  }

  // 録画停止
  void stopRecording() {
    if (_isRecording) {
      _completeRecording();
    }
  }

  // ゲッター
  bool get isRecording => _isRecording;
  String? get currentLabel => _currentLabel;
  int get bufferSize => _buffer.length;

  double get progress {
    if (!_isRecording || _recordingStartTime == null) return 0.0;

    final elapsed =
        DateTime.now().difference(_recordingStartTime!).inMilliseconds;
    return (elapsed / recordingDurationMs).clamp(0.0, 1.0);
  }

  // リソース解放
  void dispose() {
    _recordingTimer?.cancel();
    _buffer.clear();
    _isRecording = false;
  }
}
