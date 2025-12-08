import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// 1パケット分のセンサーデータ
class BleDataPacket {
  final int seq;
  final List<double> samples;
  final DateTime timestamp;

  BleDataPacket({
    required this.seq,
    required this.samples,
    required this.timestamp,
  });
}

/// BLE 経由で EMG データを受け取るサービス
class BleService {
  static const String targetDeviceName = 'picow_temp';
  static const String serviceUuidString =
      '12345678-1234-5678-1234-56789abcdef0';
  static const String charUuidString = '12345678-1234-5678-1234-56789abcdef1';
  static const int samplesPerPacket = 10;
  static const int expectedPacketBytes =
      2 + samplesPerPacket * 4; // seq(2B) + 10 floats

  final Guid serviceUuid = Guid(serviceUuidString);
  final Guid charUuid = Guid(charUuidString);

  BluetoothDevice? _targetDevice;
  BluetoothCharacteristic? _characteristic;

  bool _isConnected = false;
  bool _isScanning = false;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _notifySub;

  final _statusController = StreamController<String>.broadcast();
  final _packetController = StreamController<BleDataPacket>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<String> get statusStream => _statusController.stream;
  Stream<BleDataPacket> get packetStream => _packetController.stream;
  Stream<String> get errorStream => _errorController.stream;

  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  BluetoothDevice? get targetDevice => _targetDevice;

  /// スキャン開始（対象デバイスを見つけたら自動で接続）
  Future<void> startScan() async {
    final available = await FlutterBluePlus.isSupported;
    final isOn = await FlutterBluePlus.isOn;

    if (!available || !isOn) {
      _errorController.add('Bluetooth が未初期化か OFF です');
      return;
    }

    _statusController.add('BLE デバイスをスキャン中...');
    _isScanning = true;

    // 既存のリスナーをクリア
    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen(_onScanResults);

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
  }

  /// スキャン結果の処理
  void _onScanResults(List<ScanResult> results) {
    for (final r in results) {
      if (r.device.name == targetDeviceName) {
        _statusController.add('${r.device.name} に接続中...');
        _stopScanInternal();
        connectToDevice(r.device);
        break;
      }
    }
  }

  Future<void> _stopScanInternal() async {
    if (_isScanning) {
      _isScanning = false;
      await FlutterBluePlus.stopScan();
      await _scanSub?.cancel();
      _scanSub = null;
    }
  }

  Future<void> stopScan() async {
    await _stopScanInternal();
    _statusController.add('スキャン停止');
  }

  /// 対象デバイスに接続し、通知を購読
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      _targetDevice = device;

      final services = await device.discoverServices();
      BluetoothCharacteristic? targetChar;

      for (final service in services) {
        if (service.uuid == serviceUuid) {
          for (final characteristic in service.characteristics) {
            if (characteristic.uuid == charUuid) {
              targetChar = characteristic;
              break;
            }
          }
        }
      }

      if (targetChar == null) {
        _errorController.add('対象サービス/キャラクタリスティックが見つかりません');
        await disconnect();
        return;
      }

      _characteristic = targetChar;

      if (_characteristic!.properties.notify) {
        await _characteristic!.setNotifyValue(true);

        // 既存購読をクリア
        await _notifySub?.cancel();
        _notifySub = _characteristic!.lastValueStream.listen(_onNotifyData);

        _isConnected = true;
        _statusController.add('接続完了 - データ受信中');
      } else {
        _errorController.add('このキャラクタリスティックは notify に対応していません');
      }
    } catch (e) {
      _errorController.add('接続エラー: $e');
      await disconnect();
    }
  }

  /// 通知データの処理
  void _onNotifyData(List<int> value) {
    final packet = _parseData(value);
    if (packet != null) {
      _packetController.add(packet);
    }
  }

  /// 1 パケットをパースして BleDataPacket に変換
  BleDataPacket? _parseData(List<int> data) {
    try {
      if (data.length != expectedPacketBytes) {
        // 想定外のサイズは無視
        return null;
      }

      final buffer = Uint8List.fromList(data).buffer;
      final byteData = ByteData.view(buffer);

      final seq = byteData.getUint16(0, Endian.little);
      final samples = <double>[];

      for (int i = 0; i < samplesPerPacket; i++) {
        final sample = byteData.getFloat32(2 + (i * 4), Endian.little);
        samples.add(sample);
      }

      return BleDataPacket(
        seq: seq,
        samples: samples,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      _errorController.add('データ処理エラー: $e');
      return null;
    }
  }

  /// 手動読み取り（必要なら）
  Future<void> performManualRead() async {
    if (_characteristic == null) return;

    try {
      if (_characteristic!.properties.read) {
        final data = await _characteristic!.read();
        final packet = _parseData(data);
        if (packet != null) {
          _packetController.add(packet);
        }
      }
    } catch (e) {
      _errorController.add('手動読み取りエラー: $e');
    }
  }

  /// 切断
  Future<void> disconnect() async {
    await _notifySub?.cancel();
    _notifySub = null;

    if (_targetDevice != null) {
      await _targetDevice!.disconnect();
      _targetDevice = null;
    }

    _characteristic = null;
    _isConnected = false;
    _statusController.add('接続解除');
  }

  /// リソース解放
  Future<void> dispose() async {
    await _stopScanInternal();
    await disconnect();

    await _statusController.close();
    await _packetController.close();
    await _errorController.close();
  }
}
