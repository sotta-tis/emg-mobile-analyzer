import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:csv/csv.dart';
import 'package:archive/archive.dart';
import 'package:share_plus/share_plus.dart';

class RecordingSession {
  final String sessionId;
  final DateTime startTime;
  final Directory sessionDir;
  final Directory samplesDir;
  final File manifestFile;
  int sampleCounter = 0;

  RecordingSession({
    required this.sessionId,
    required this.startTime,
    required this.sessionDir,
    required this.samplesDir,
    required this.manifestFile,
  });
}

class DataSample {
  final int packetTimestamp;
  final int seqPacket;
  final int sampleIdx;
  final double valueNorm;

  DataSample({
    required this.packetTimestamp,
    required this.seqPacket,
    required this.sampleIdx,
    required this.valueNorm,
  });

  List<dynamic> toCsvRow() {
    return [packetTimestamp, seqPacket, sampleIdx, valueNorm];
  }
}

class DataSaverService {
  static const List<String> defaultLabels = [
    'tripod',
    'fist',
    'open',
    'pinch',
    'point',
    'rest',
  ];

  RecordingSession? _currentSession;

  // セッション開始
  Future<RecordingSession> startSession() async {
    final now = DateTime.now();
    final sessionId = 'session_${_formatIso8601(now)}';

    // ディレクトリ作成
    final appDir = await getApplicationDocumentsDirectory();
    final emgDataDir = Directory(path.join(appDir.path, 'emg_data'));
    await emgDataDir.create(recursive: true);

    final sessionDir = Directory(path.join(emgDataDir.path, sessionId));
    await sessionDir.create();

    final samplesDir = Directory(path.join(sessionDir.path, 'samples'));
    await samplesDir.create();

    // manifest.json作成
    final manifestFile = File(path.join(sessionDir.path, 'manifest.json'));
    await _createManifest(manifestFile, sessionId);

    _currentSession = RecordingSession(
      sessionId: sessionId,
      startTime: now,
      sessionDir: sessionDir,
      samplesDir: samplesDir,
      manifestFile: manifestFile,
    );

    return _currentSession!;
  }

  // 5秒間のデータサンプルを保存
  Future<String> saveSample(String label, List<DataSample> samples) async {
    if (_currentSession == null) {
      throw Exception('セッションが開始されていません');
    }

    _currentSession!.sampleCounter++;
    final sampleNumber = _currentSession!.sampleCounter.toString().padLeft(
      4,
      '0',
    );
    final startTime = _formatIso8601(DateTime.now());
    final filename = '${startTime}_${label}_s$sampleNumber.csv';

    final csvFile = File(path.join(_currentSession!.samplesDir.path, filename));

    // CSVデータ作成
    final csvData = [
      ['t_ms_packet', 'seq_packet', 'sample_idx', 'value_norm'], // ヘッダ
      ...samples.map((sample) => sample.toCsvRow()),
    ];

    final csvString = const ListToCsvConverter().convert(csvData);
    await csvFile.writeAsString(csvString);

    return filename;
  }

  // manifest.json更新
  Future<void> updateManifest() async {
    if (_currentSession == null) return;

    await _createManifest(
      _currentSession!.manifestFile,
      _currentSession!.sessionId,
    );
  }

  // セッション終了
  void endSession() {
    _currentSession = null;
  }

  // セッションデータをZIP化して共有
  Future<void> exportSessionData() async {
    if (_currentSession == null) {
      throw Exception('アクティブなセッションがありません');
    }

    final archive = Archive();

    // セッションディレクトリ内のすべてのファイルをアーカイブに追加
    await _addDirectoryToArchive(archive, _currentSession!.sessionDir, '');

    // ZIPファイル作成
    final zipData = ZipEncoder().encode(archive);

    // 一時ファイルに保存
    final tempDir = await getTemporaryDirectory();
    final zipFile = File(
      path.join(tempDir.path, '${_currentSession!.sessionId}.zip'),
    );
    await zipFile.writeAsBytes(zipData!);

    // 共有
    await Share.shareXFiles([
      XFile(zipFile.path),
    ], text: 'EMGデータ: ${_currentSession!.sessionId}');
  }

  // ゲッター
  RecordingSession? get currentSession => _currentSession;
  bool get hasActiveSession => _currentSession != null;

  // プライベートメソッド
  Future<void> _createManifest(File manifestFile, String sessionId) async {
    final manifest = {
      'schema_version': '1.0',
      'session_id': sessionId,
      'sampling': {
        'sample_rate_hz': 1000,
        'samples_per_packet': 10,
        'time_base': 'unix_epoch_ms',
      },
      'preprocess': {
        'normalize': {'method': 'minmax', 'min': 0.0, 'max': 1.0},
      },
      'sample_duration_ms': 5000,
      'labels': defaultLabels,
    };

    await manifestFile.writeAsString(json.encode(manifest));
  }

  Future<void> _addDirectoryToArchive(
    Archive archive,
    Directory dir,
    String basePath,
  ) async {
    await for (final entity in dir.list()) {
      final relativePath = path.relative(entity.path, from: dir.path);
      final archivePath =
          basePath.isEmpty ? relativePath : path.join(basePath, relativePath);

      if (entity is File) {
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
      } else if (entity is Directory) {
        await _addDirectoryToArchive(archive, entity, archivePath);
      }
    }
  }

  String _formatIso8601(DateTime dateTime) {
    return dateTime
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
  }
}
