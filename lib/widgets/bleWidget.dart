import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fl_chart/fl_chart.dart';

class BleTempScannerWidget extends StatefulWidget {
  const BleTempScannerWidget({super.key});

  @override
  State<BleTempScannerWidget> createState() => _BleTempScannerWidgetState();
}

class _BleTempScannerWidgetState extends State<BleTempScannerWidget> {
  final String targetDeviceName = 'PicoEMG';
  final Guid serviceUuid = Guid("12345678-1234-5678-1234-56789abcdef0");
  final Guid charUuid = Guid("12345678-1234-5678-1234-56789abcdef1");

  BluetoothDevice? _targetDevice;
  BluetoothCharacteristic? _temperatureChar;
  String _temperatureText = '未接続';
  bool _isScanning = false;
  final List<double> _temperatureHistory = [];
  final int _maxPoints = 100; // 最大表示点数

  final List<ScanResult> _scanResults = [];

  @override
  void initState() {
    super.initState();
    FlutterBluePlus.scanResults.listen(_onScanResults);
  }

  void _onScanResults(List<ScanResult> results) {
    setState(() {
      _scanResults.clear();
      _scanResults.addAll(results);
    });

    for (ScanResult r in results) {
      if (r.device.name == targetDeviceName) {
        FlutterBluePlus.stopScan();
        setState(() {
          _targetDevice = r.device;
          _temperatureText = '接続中...';
        });
        _connectToDevice(r.device);
        break;
      }
    }
  }

  void _startScan() async {
    final available = await FlutterBluePlus.isSupported;
    final isOn = await FlutterBluePlus.isOn;

    if (!available || !isOn) {
      setState(() {
        _temperatureText = '❌ Bluetooth未初期化またはOFF';
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _temperatureText = 'スキャン中...';
      _scanResults.clear();
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    setState(() => _isScanning = false);
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    await device.connect();
    final services = await device.discoverServices();
    for (var service in services) {
      if (service.uuid == serviceUuid) {
        for (var c in service.characteristics) {
          if (c.uuid == charUuid) {
            _temperatureChar = c;
            await c.setNotifyValue(true);
            c.lastValueStream.listen((value) {
              if (value.isNotEmpty && value.length % 2 == 0) {
                final emgList = <double>[];
                for (int i = 0; i < value.length; i += 2) {
                  final emg = value[i] + (value[i + 1] << 8);
                  emgList.add(emg.toDouble());
                }

                setState(() {
                  for (final emg in emgList) {
                    _temperatureHistory.add(emg);
                    if (_temperatureHistory.length > _maxPoints) {
                      _temperatureHistory.removeAt(0);
                    }
                  }
                  final last = emgList.last;
                  _temperatureText = '📊 EMG: $last';
                });
              }
            });
            return;
          }
        }
      }
    }
  }

  List<FlSpot> _buildSpots() {
    return _temperatureHistory
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
        .toList();
  }

  Widget _buildChart() {
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: _buildSpots(),
              isCurved: false,
              barWidth: 2,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
          titlesData: FlTitlesData(show: false),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        itemCount: _scanResults.length,
        itemBuilder: (context, index) {
          final device = _scanResults[index].device;
          final name = device.name.isNotEmpty ? device.name : '(名前なし)';
          return ListTile(
            title: Text(name),
            subtitle: Text(device.id.toString()),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'BLE温度: $_temperatureText',
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(height: 20),
          _buildChart(),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isScanning ? null : _startScan,
            child: const Text('スキャン開始'),
          ),
          const SizedBox(height: 10),
          const Text('周囲のデバイス一覧:', style: TextStyle(fontSize: 18)),
          _buildDeviceList(),
        ],
      ),
    );
  }
}
