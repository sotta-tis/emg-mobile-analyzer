import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emg_mobile_analyzer/services/emg_window_buffer.dart';

/// EMG の生データを蓄積し、ウィンドウに切り出すバッファ
final emgWindowBufferProvider = Provider<EmgWindowBuffer>((ref) {
  // サンプリング 1kHz, 150ms ウィンドウ, 50ms ホップの例
  final buffer = EmgWindowBuffer(
    windowSize: 150, // 150 samples
    hopSize: 50, // 50 samples
  );

  ref.onDispose(() {
    buffer.clear();
  });

  return buffer;
});
