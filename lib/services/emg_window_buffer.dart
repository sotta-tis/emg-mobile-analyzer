class EmgWindow {
  /// このウィンドウに含まれるサンプル列
  final List<double> samples;

  /// ウィンドウ先頭のおおよその時刻
  final DateTime startTime;

  EmgWindow({required this.samples, required this.startTime});
}

class EmgWindowBuffer {
  /// ウィンドウ長 [サンプル数]（例: 150ms @ 1kHz → 150）
  final int windowSize;

  /// ホップ長 [サンプル数]（例: 50ms @ 1kHz → 50）
  final int hopSize;

  final List<double> _buffer = [];
  DateTime? _firstTimestamp;

  EmgWindowBuffer({required this.windowSize, required this.hopSize});

  /// 生サンプルを追加
  void addSamples(List<double> samples, DateTime timestamp) {
    if (_buffer.isEmpty) {
      _firstTimestamp = timestamp;
    }
    _buffer.addAll(samples);
  }

  /// 切り出し可能なウィンドウをすべて返し、内部バッファを進める
  List<EmgWindow> popReadyWindows() {
    final windows = <EmgWindow>[];

    while (_buffer.length >= windowSize) {
      final winSamples = List<double>.unmodifiable(
        _buffer.sublist(0, windowSize),
      );

      windows.add(
        EmgWindow(
          samples: winSamples,
          startTime: _firstTimestamp ?? DateTime.now(),
        ),
      );

      final removeCount = hopSize.clamp(1, windowSize);
      _buffer.removeRange(0, removeCount);
      // startTime を厳密に扱いたければここで補正する
    }

    return windows;
  }

  void clear() {
    _buffer.clear();
    _firstTimestamp = null;
  }
}
