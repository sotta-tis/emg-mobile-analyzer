import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emg_mobile_analyzer/ble_providers.dart';
import 'package:emg_mobile_analyzer/services/emg_window_buffer.dart';
import 'package:emg_mobile_analyzer/services/emg_dataset_recoder.dart';

final emgWindowBufferProvider = Provider<EmgWindowBuffer>((ref) {
  final buffer = EmgWindowBuffer(windowSize: 150, hopSize: 50);
  ref.onDispose(buffer.clear);
  return buffer;
});

final emgDatasetRecorderProvider = Provider<EmgDatasetRecorder>((ref) {
  final ble = ref.watch(bleServiceProvider);
  final buf = ref.watch(emgWindowBufferProvider);
  return EmgDatasetRecorder(ble: ble, windowBuffer: buf);
});
