import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emg_mobile_analyzer/services/ble_service.dart';

final bleServiceProvider = Provider<BleService>((ref) {
  final service = BleService();
  ref.onDispose(service.dispose);
  return service;
});

final blePacketProvider = StreamProvider<BleDataPacket>((ref) {
  final service = ref.watch(bleServiceProvider);
  return service.packetStream;
});
