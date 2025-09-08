import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_service.dart';
import '../services/data_statistics.dart';
import 'ble_chart_widget.dart';
import 'ble_statistics_widget.dart';

class BleTempScannerWidget extends StatefulWidget {
  const BleTempScannerWidget({super.key});

  @override
  State<BleTempScannerWidget> createState() => _BleTempScannerWidgetState();
}

class _BleTempScannerWidgetState extends State<BleTempScannerWidget> {
  late final BleService _bleService;
  late final DataStatistics _statistics;

  String _statusText = '未接続';
  bool _isScanning = false;
  List<ScanResult> _scanResults = [];

  @override
  void initState() {
    super.initState();
    _statistics = DataStatistics(maxPoints: 500);
    _bleService = BleService();

    // コールバック設定
    _bleService.onStatusUpdate = (status) {
      setState(() {
        _statusText = status;
      });
    };

    _bleService.onDataReceived = (packet) {
      setState(() {
        _statistics.addPacket(packet);
        _statusText = _statistics.getStatusString(packet);
      });
    };

    _bleService.onError = (error) {
      setState(() {
        _statusText = error;
      });
    };
  }

  void _startScan() async {
    setState(() {
      _isScanning = true;
      _scanResults.clear();
    });

    _statistics.reset();
    await _bleService.startScan();
    _bleService.listenToScanResults();

    // スキャン結果の監視
    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        _scanResults = results;
      });
    });

    // 10秒後にスキャン終了
    Future.delayed(const Duration(seconds: 10), () {
      if (_isScanning) {
        setState(() {
          _isScanning = false;
          _statusText = 'スキャン完了 - ${_scanResults.length}個のデバイス発見';
        });
      }
    });
  }

  void _connectToSelectedDevice(BluetoothDevice device) async {
    await _bleService.connectToDevice(device);
  }

  void _performManualRead() async {
    await _bleService.performManualRead();
  }

  void _disconnect() async {
    await _bleService.disconnect();
    setState(() {
      _statusText = '接続解除';
      _statistics.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ステータス表示
          _buildStatusCard(),

          const SizedBox(height: 16),

          // デバイス一覧
          if (_scanResults.isNotEmpty) ...[
            _buildDeviceListCard(),
            const SizedBox(height: 16),
          ],

          // 統計情報
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: BleStatisticsWidget(statistics: _statistics),
            ),
          ),

          const SizedBox(height: 16),

          // グラフ
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'リアルタイムデータ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

          // デバッグ情報
          if (_statistics.emptyDataCount > 0) ...[
            _buildDebugCard(),
            const SizedBox(height: 16),
          ],

          // コントロールボタン
          _buildControlButtons(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BLE高速データ取得',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'デバイス: ${BleService.targetDeviceName}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              'データ形式: 正規化(0.0-1.0)',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(_statusText, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceListCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '発見されたBLEデバイス (${_scanResults.length}個)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _scanResults.length,
                itemBuilder: (context, index) {
                  final result = _scanResults[index];
                  final device = result.device;
                  final isTarget = device.name == BleService.targetDeviceName;

                  return Card(
                    color: isTarget ? Colors.blue.withOpacity(0.1) : null,
                    child: ListTile(
                      leading: Icon(
                        Icons.bluetooth,
                        color: isTarget ? Colors.blue : Colors.grey,
                      ),
                      title: Text(
                        device.name.isNotEmpty ? device.name : '(No name)',
                        style: TextStyle(
                          fontWeight:
                              isTarget ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${device.id}'),
                          Text('RSSI: ${result.rssi} dBm'),
                        ],
                      ),
                      trailing:
                          isTarget
                              ? const Icon(Icons.star, color: Colors.blue)
                              : null,
                      onTap: () => _connectToSelectedDevice(device),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugCard() {
    return Card(
      color: Colors.orange.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'デバッグ情報',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('空データ受信回数: ${_statistics.emptyDataCount}'),
            Text('接続状態: ${_bleService.targetDevice?.state}'),
            Text(
              'Characteristic: ${_bleService.characteristic != null ? "設定済み" : "未設定"}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      alignment: WrapAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: _isScanning ? null : _startScan,
          icon: Icon(_isScanning ? Icons.bluetooth_searching : Icons.bluetooth),
          label: Text(_isScanning ? 'スキャン中...' : '接続開始'),
        ),
        ElevatedButton.icon(
          onPressed:
              _bleService.characteristic != null ? _performManualRead : null,
          icon: const Icon(Icons.refresh),
          label: const Text('手動読み取り'),
        ),
        ElevatedButton.icon(
          onPressed: _bleService.isConnected ? _disconnect : null,
          icon: const Icon(Icons.bluetooth_disabled),
          label: const Text('切断'),
        ),
      ],
    );
  }
}
