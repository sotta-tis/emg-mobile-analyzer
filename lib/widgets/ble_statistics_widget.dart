import 'package:flutter/material.dart';
import 'package:emg_mobile_analyzer/services/data_statistics.dart';

class BleStatisticsWidget extends StatelessWidget {
  final DataStatistics statistics;

  BleStatisticsWidget({Key? key, required this.statistics}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!statistics.hasData) {
      return const Text('統計データなし');
    }

    return Column(
      children: [
        const Text(
          '統計情報',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem('Min', statistics.minValue.toStringAsFixed(4)),
            _buildStatItem('Max', statistics.maxValue.toStringAsFixed(4)),
            _buildStatItem('Avg', statistics.avgValue.toStringAsFixed(4)),
            _buildStatItem('Samples', '${statistics.sampleCount}'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem(
              'PKT Rate',
              '${statistics.packetRate.toStringAsFixed(1)}Hz',
            ),
            _buildStatItem(
              'SPL Rate',
              '${statistics.sampleRate.toStringAsFixed(0)}Hz',
            ),
            _buildStatItem('Packets', '${statistics.packetCount}'),
            _buildStatItem('Loss', '${statistics.packetLossCount}'),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Text(value, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}
