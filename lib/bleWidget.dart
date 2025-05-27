import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fl_chart/fl_chart.dart';

class BleTempScannerWidget extends StatefulWidget {
  const BleTempScannerWidget({super.key});

  @override
  State<BleTempScannerWidget> createState() => _BleTempScannerWidgetState();
}

class _BleTempScannerWidgetState extends State<BleTempScannerWidget> {
  final String targetDeviceName = 'PicoTemp';
  final Guid serviceUuid = Guid("12345678-1234-5678-1234-56789abcdef0");
  final Guid charUuid = Guid("12345678-1234-5678-1234-56789abcdef1");

  BluetoothDevice? _targetDevice;
  BluetoothCharacteristic? _temperatureChar;
  String _temperatureText = '未接続';
  bool _isScanning = false;
  final List<double> _temperatureHistory = [];
  final int _maxPoints = 30;

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
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.name == targetDeviceName) {
          await FlutterBluePlus.stopScan();
          setState(() {
            _targetDevice = r.device;
            _temperatureText = '接続中...';
          });
          await _connectToDevice(r.device);
          break;
        }
      }
    });
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
              if (value.isNotEmpty) {
                final tempInt = value[0] + (value[1] << 8);
                final temp = tempInt / 100.0;
                setState(() {
                  _temperatureText = '🌡️ $temp °C';
                  _temperatureHistory.add(temp);
                  if (_temperatureHistory.length > _maxPoints) {
                    _temperatureHistory.removeAt(0);
                  }
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
              isCurved: true,
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

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('BLE温度: $_temperatureText', style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 20),
        _buildChart(),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _isScanning ? null : _startScan,
          child: const Text('スキャン開始'),
        ),
      ],
    );
  }
}
