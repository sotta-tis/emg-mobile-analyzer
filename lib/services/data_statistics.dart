import 'ble_service.dart';

class DataStatistics {
  final int maxPoints;

  // 統計情報
  int _packetCount = 0;
  int _sampleCount = 0;
  double _minValue = double.infinity;
  double _maxValue = double.negativeInfinity;
  double _avgValue = 0.0;
  int? _lastSeq;
  DateTime? _startTime;

  // データ履歴
  final List<double> _dataHistory = [];

  // エラー統計
  int _emptyDataCount = 0;
  int _packetLossCount = 0;

  DataStatistics({this.maxPoints = 500});

  void reset() {
    _packetCount = 0;
    _sampleCount = 0;
    _minValue = double.infinity;
    _maxValue = double.negativeInfinity;
    _avgValue = 0.0;
    _lastSeq = null;
    _startTime = DateTime.now();
    _dataHistory.clear();
    _emptyDataCount = 0;
    _packetLossCount = 0;
  }

  void addPacket(BleDataPacket packet) {
    _startTime ??= DateTime.now();

    _packetCount++;
    _sampleCount += packet.samples.length;

    // データ履歴に追加
    _dataHistory.addAll(packet.samples);

    // バッファサイズ制限
    while (_dataHistory.length > maxPoints) {
      _dataHistory.removeAt(0);
    }

    // 統計計算
    final minSample = packet.samples.reduce((a, b) => a < b ? a : b);
    final maxSample = packet.samples.reduce((a, b) => a > b ? a : b);

    if (minSample < _minValue) _minValue = minSample;
    if (maxSample > _maxValue) _maxValue = maxSample;

    // 全体平均を計算
    if (_dataHistory.isNotEmpty) {
      _avgValue = _dataHistory.reduce((a, b) => a + b) / _dataHistory.length;
    }

    // シーケンス番号チェック
    if (_lastSeq != null) {
      final expectedSeq = (_lastSeq! + 1) & 0xFFFF;
      if (packet.seq != expectedSeq) {
        _packetLossCount++;
      }
    }
    _lastSeq = packet.seq;
  }

  void incrementEmptyDataCount() {
    _emptyDataCount++;
  }

  void resetEmptyDataCount() {
    _emptyDataCount = 0;
  }

  // レート計算
  double get packetRate {
    if (_startTime == null) return 0.0;
    final elapsed =
        DateTime.now().difference(_startTime!).inMilliseconds / 1000.0;
    return elapsed > 0 ? _packetCount / elapsed : 0.0;
  }

  double get sampleRate {
    if (_startTime == null) return 0.0;
    final elapsed =
        DateTime.now().difference(_startTime!).inMilliseconds / 1000.0;
    return elapsed > 0 ? _sampleCount / elapsed : 0.0;
  }

  // ゲッター
  int get packetCount => _packetCount;
  int get sampleCount => _sampleCount;
  double get minValue => _minValue == double.infinity ? 0.0 : _minValue;
  double get maxValue => _maxValue == double.negativeInfinity ? 0.0 : _maxValue;
  double get avgValue => _avgValue;
  int? get lastSeq => _lastSeq;
  List<double> get dataHistory => List.unmodifiable(_dataHistory);
  int get emptyDataCount => _emptyDataCount;
  int get packetLossCount => _packetLossCount;

  bool get hasData => _dataHistory.isNotEmpty;

  String getStatusString(BleDataPacket packet) {
    final samples = packet.samples;
    final minSample = samples.reduce((a, b) => a < b ? a : b);
    final maxSample = samples.reduce((a, b) => a > b ? a : b);
    final avgSample = samples.reduce((a, b) => a + b) / samples.length;

    String seqInfo = '';
    if (_lastSeq != null) {
      final expectedSeq = (_lastSeq! + 1) & 0xFFFF;
      if (packet.seq != expectedSeq) {
        seqInfo = ' (⚠️ 欠損: $_lastSeq → ${packet.seq})';
      }
    }

    return '📊 Seq:${packet.seq} | Samples:${samples.length} | '
        'Min:${minSample.toStringAsFixed(4)} Max:${maxSample.toStringAsFixed(4)} '
        'Avg:${avgSample.toStringAsFixed(4)} | '
        'PKT:${packetRate.toStringAsFixed(1)}Hz SPL:${sampleRate.toStringAsFixed(0)}Hz$seqInfo';
  }
}
