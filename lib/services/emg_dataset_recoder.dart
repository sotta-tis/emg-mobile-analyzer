// lib/services/emg_dataset_recorder.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:emg_mobile_analyzer/services/ble_service.dart';
import 'package:emg_mobile_analyzer/services/emg_window_buffer.dart';
import 'package:emg_mobile_analyzer/services/emg_feature_extractor.dart';

class EmgDatasetRecorder {
  final BleService ble;
  final EmgWindowBuffer windowBuffer;

  EmgDatasetRecorder({required this.ble, required this.windowBuffer});

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  StreamSubscription<BleDataPacket>? _sub;

  final List<Map<String, dynamic>> _dataset = [];
  List<Map<String, dynamic>> get dataset => List.unmodifiable(_dataset);

  void clearDataset() => _dataset.clear();

  /// labelで duration 秒分だけ記録して、メモリ(_dataset)に追加
  Future<void> recordForLabelToMemory({
    required String label,
    required Duration duration,
    double fs = 1000.0,
    double lfoCutoffHz = 150.0,
  }) async {
    if (_isRecording) throw StateError('Already recording');

    _isRecording = true;
    windowBuffer.clear();

    final end = DateTime.now().add(duration);

    await _sub?.cancel();
    _sub = ble.packetStream.listen((pkt) {
      windowBuffer.addSamples(pkt.samples, pkt.timestamp);
      final windows = windowBuffer.popReadyWindows();

      for (final w in windows) {
        if (DateTime.now().isAfter(end)) break;

        final f = EmgFeatureExtractor.compute(
          w.samples,
          fs: fs,
          lfoCutoffHz: lfoCutoffHz,
        );

        _dataset.add({
          "features": f.toVector(), // 10次元
          "classLabel": label,
          // 解析用メタ（学習スクリプトは無視してOK）
          "ts": w.startTime.toIso8601String(),
        });
      }
    });

    await Future.delayed(duration);

    await _sub?.cancel();
    _sub = null;
    _isRecording = false;
  }

  Future<File> saveDatasetOverwrite({
    String fileName = 'emg_dataset.json',
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');

    final jsonText = const JsonEncoder.withIndent('  ').convert(_dataset);
    await file.writeAsString(jsonText, flush: true);
    return file;
  }

  /// 読み込み（必要なら）
  Future<void> loadDataset({String fileName = 'emg_dataset.json'}) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    if (!await file.exists()) return;

    final txt = await file.readAsString();
    final decoded = jsonDecode(txt);
    if (decoded is List) {
      _dataset
        ..clear()
        ..addAll(decoded.cast<Map<String, dynamic>>());
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _isRecording = false;
  }
}
