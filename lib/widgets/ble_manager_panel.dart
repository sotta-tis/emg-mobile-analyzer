import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:emg_mobile_analyzer/ble_providers.dart';
import 'package:emg_mobile_analyzer/services/ble_service.dart';

class BleManagerPanel extends ConsumerStatefulWidget {
  const BleManagerPanel({super.key, this.showPacketCounter = true});

  final bool showPacketCounter;

  @override
  ConsumerState<BleManagerPanel> createState() => _BleManagerPanelState();
}

class _BleManagerPanelState extends ConsumerState<BleManagerPanel> {
  StreamSubscription<String>? _statusSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<BleDataPacket>? _packetSub;

  String _statusText = '未接続';
  String? _errorText;

  int _packetCount = 0;
  int? _lastSeq;

  @override
  void initState() {
    super.initState();

    // initState では ref.read を使う（watch しない）
    final ble = ref.read(bleServiceProvider);

    _statusSub = ble.statusStream.listen((msg) {
      if (!mounted) return;
      setState(() {
        _statusText = msg;
      });
    });

    _errorSub = ble.errorStream.listen((msg) {
      if (!mounted) return;
      setState(() {
        _errorText = msg;
      });
    });

    if (widget.showPacketCounter) {
      _packetSub = ble.packetStream.listen((pkt) {
        if (!mounted) return;
        setState(() {
          _packetCount++;
          _lastSeq = pkt.seq;
        });
      });
    }
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _errorSub?.cancel();
    _packetSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ble = ref.watch(bleServiceProvider);

    final title =
        ble.isConnected
            ? '✅ Connected: ${ble.targetDevice?.name ?? "(unknown)"}'
            : ble.isScanning
            ? '🔎 Scanning...'
            : '🔌 Disconnected';

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),

            Text('Status: $_statusText'),
            if (_errorText != null) ...[
              const SizedBox(height: 6),
              Text(
                'Error: $_errorText',
                style: const TextStyle(color: Colors.red),
              ),
            ],

            if (widget.showPacketCounter) ...[
              const SizedBox(height: 8),
              Text('Packets: $_packetCount  (last seq: ${_lastSeq ?? "-"})'),
            ],

            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: ble.isScanning ? null : () => ble.startScan(),
                  icon: const Icon(Icons.bluetooth_searching),
                  label: const Text('Scan'),
                ),
                OutlinedButton.icon(
                  onPressed: ble.isScanning ? () => ble.stopScan() : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
                OutlinedButton.icon(
                  onPressed: ble.isConnected ? () => ble.disconnect() : null,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Disconnect'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      ble.isConnected ? () => ble.performManualRead() : null,
                  icon: const Icon(Icons.download),
                  label: const Text('Read'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
