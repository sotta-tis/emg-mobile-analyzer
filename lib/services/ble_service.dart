import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:typed_data';

class BleDataPacket {
  // パケットの順番
  final int seq;
  // センサーデータ
  final List<double> samples;
  final DateTime timestamp;

  BleDataPacket({
    required this.seq,
    required this.samples,
    required this.timestamp,
  });
}

class BleService {
  static const String targetDeviceName = 'picow_temp';
  static const String serviceUuidString =
      "12345678-1234-5678-1234-56789abcdef0";
  static const String charUuidString = "12345678-1234-5678-1234-56789abcdef1";
  static const int samplesPerPacket = 10;

  final Guid serviceUuid = Guid(serviceUuidString);
  final Guid charUuid = Guid(charUuidString);

  BluetoothDevice? _targetDevice;
  BluetoothCharacteristic? _characteristic;
  bool _isConnected = false;

  // コールバック
  Function(String)? onStatusUpdate;
  Function(BleDataPacket)? onDataReceived;
  Function(String)? onError;

  // スキャン開始
  Future<void> startScan() async {
    final available = await FlutterBluePlus.isSupported;
    final isOn = await FlutterBluePlus.isOn;

    if (!available || !isOn) {
      onError?.call('❌ Bluetooth未初期化またはOFF');
      return;
    }

    onStatusUpdate?.call('BLEデバイススキャン中...');
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
  }

  // スキャン結果を監視
  void listenToScanResults() {
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.name == targetDeviceName) {
          FlutterBluePlus.stopScan();
          onStatusUpdate?.call('${r.device.name} に接続中...');
          connectToDevice(r.device);
          return;
        }
      }
    });
  }

  // デバイスに接続
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      _targetDevice = device;
      final services = await device.discoverServices();

      for (var service in services) {
        if (service.uuid == serviceUuid) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid == charUuid) {
              _characteristic = characteristic;

              if (characteristic.properties.notify) {
                await characteristic.setNotifyValue(true);

                // データ受信リスナー
                characteristic.lastValueStream.listen((value) {
                  final packet = _parseData(value);
                  if (packet != null) {
                    onDataReceived?.call(packet);
                  }
                });

                _isConnected = true;
                onStatusUpdate?.call('✅ 接続完了 - データ受信中...');
                return;
              }
            }
          }
        }
      }

      onError?.call('❌ 対象サービス/キャラクタリスティックが見つかりません');
    } catch (e) {
      onError?.call('❌ 接続エラー: $e');
    }
  }

  // データパース
  BleDataPacket? _parseData(List<int> data) {
    try {
      if (data.length == 42) {
        // 正規化データ: seq(2B) + 10floats(4B each) = 42B
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
      }
    } catch (e) {
      onError?.call('データ処理エラー: $e');
    }
    return null;
  }

  // 手動読み取り
  Future<void> performManualRead() async {
    if (_characteristic == null) return;

    try {
      if (_characteristic!.properties.read) {
        final data = await _characteristic!.read();
        final packet = _parseData(data);
        if (packet != null) {
          onDataReceived?.call(packet);
        }
      }
    } catch (e) {
      onError?.call('手動読み取りエラー: $e');
    }
  }

  // 切断
  Future<void> disconnect() async {
    if (_targetDevice != null) {
      await _targetDevice!.disconnect();
      _targetDevice = null;
      _characteristic = null;
      _isConnected = false;
      onStatusUpdate?.call('接続解除');
    }
  }

  // ゲッター
  bool get isConnected => _isConnected;
  BluetoothDevice? get targetDevice => _targetDevice;
  BluetoothCharacteristic? get characteristic => _characteristic;
}
