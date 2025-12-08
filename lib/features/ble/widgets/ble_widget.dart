import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emg_mobile_analyzer/features/ble/services/ble_service.dart';
import 'package:emg_mobile_analyzer/features/ble/services/data_statistics.dart';
import 'package:emg_mobile_analyzer/features/ble/widgets/ble_chart_widget.dart';
import 'package:emg_mobile_analyzer/features/ble/widgets/ble_statistics_widget.dart';
import 'package:emg_mobile_analyzer/features/recording/services/data_saver_service.dart';
import 'package:emg_mobile_analyzer/features/recording/services/recording_buffer.dart';
import 'package:emg_mobile_analyzer/features/recording/widgets/recording_widget.dart';
import 'package:emg_mobile_analyzer/features/recording/widgets/session_control_widget.dart';

class BleTempScannerWidget extends ConsumerStatefulWidget {
  const BleTempScannerWidget({super.key});

  @override
  ConsumerState<BleTempScannerWidget> createState() =>
      _BleTempScannerWidgetState();
}

class _BleTempScannerWidgetState extends ConsumerState<BleTempScannerWidget> {
  final BleService _bleService = BleService();
  final DataStatistics _statistics = DataStatistics(maxPoints: 500);
  final DataSaverService _dataSaver = DataSaverService();
  final RecordingBuffer _recordingBuffer = RecordingBuffer();

  String _statusText = 'BLEデバイスをスキャン中...';
  String _lastPacketInfo = '';
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();

    // BLEサービスのコールバック設定
    _bleService.onStatusUpdate = (status) {
      setState(() {
        _statusText = status;
      });
    };

    _bleService.onDataReceived = (packet) {
      setState(() {
        _statistics.addPacket(packet);
        _lastPacketInfo = _statistics.getStatusString(packet);
        _isConnected = true;
      });

      // 録画中の場合、バッファに追加
      _recordingBuffer.addBlePacket(packet);
    };

    _bleService.onError = (error) {
      setState(() {
        _statusText = error;
      });
    };

    // スキャン開始
    _bleService.startScan();
    _bleService.listenToScanResults();
  }

  @override
  void dispose() {
    _bleService.dispose();
    _recordingBuffer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ステータスカード
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isConnected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_searching,
                        color: _isConnected ? Colors.green : Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_statusText)),
                    ],
                  ),
                  if (_lastPacketInfo.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _lastPacketInfo,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 統計情報
          if (_statistics.hasData)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: BleStatisticsWidget(statistics: _statistics),
              ),
            ),

          const SizedBox(height: 16),

          // チャート
          if (_statistics.hasData)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'リアルタイムデータ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    BleChartWidget(
                      dataHistory: _statistics.dataHistory,
                      maxPoints: 500,
                      normalizeData: true,
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // セッション管理
          SessionControlWidget(dataSaver: _dataSaver),

          const SizedBox(height: 16),

          // 録画コントロール
          RecordingWidget(
            recordingBuffer: _recordingBuffer,
            dataSaver: _dataSaver,
            isConnected: _isConnected,
          ),

          const SizedBox(height: 16),

          // コントロールボタン
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          _statistics.reset();
                          setState(() {
                            _lastPacketInfo = '';
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('統計リセット'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _bleService.disconnect();
                          setState(() {
                            _isConnected = false;
                            _statusText = '切断しました';
                          });
                        },
                        icon: const Icon(Icons.bluetooth_disabled),
                        label: const Text('切断'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      _bleService.startScan();
                      _bleService.listenToScanResults();
                      setState(() {
                        _statusText = '再スキャン中...';
                      });
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('再スキャン'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
