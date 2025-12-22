import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:emg_mobile_analyzer/ble_providers.dart';
import 'package:emg_mobile_analyzer/emg_providers.dart';
import 'package:emg_mobile_analyzer/services/emg_feature_extractor.dart';

class EmgFeaturesPanel extends ConsumerStatefulWidget {
  const EmgFeaturesPanel({super.key});

  @override
  ConsumerState<EmgFeaturesPanel> createState() => _EmgFeaturesPanelState();
}

class _EmgFeaturesPanelState extends ConsumerState<EmgFeaturesPanel> {
  EmgFeatures? _latest;

  @override
  Widget build(BuildContext context) {
    final windowBuffer = ref.watch(emgWindowBufferProvider);

    // BLEパケットを購読して、windowを切って特徴量更新
    ref.listen(blePacketProvider, (prev, next) {
      next.whenData((packet) {
        // dispose後の更新防止
        if (!mounted) return;

        windowBuffer.addSamples(packet.samples, packet.timestamp);
        final windows = windowBuffer.popReadyWindows();
        if (windows.isEmpty) return;

        // 最後のウィンドウだけ使う（表示用）
        final w = windows.last;
        final feat = EmgFeatureExtractor.compute(
          w.samples,
          fs: 1000.0,
          lfoCutoffHz: 150.0,
        );

        setState(() => _latest = feat);
      });
    });

    final f = _latest;
    if (f == null) {
      return const Center(child: Text('特徴量計算待ち'));
    }

    // Columnをそのまま返すと親から高さ制約が渡らない場合にExpandedが使えずクラッシュする。
    // Card + Columnで自前で高さを決め、Wrapで横方向に折り返して表示するようにする。
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '最新ウィンドウの特徴量',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _row('MVA', f.mva),
                _row('CPS', f.cps),
                _row('LFO', f.lfo),
                _row('VAR', f.variance),
                _row('AW', f.aw),
                _row('COMP', f.complexity),
                _row('AR1', f.ar[0]),
                _row('AR2', f.ar[1]),
                _row('AR3', f.ar[2]),
                _row('AR4', f.ar[3]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String name, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 48, child: Text(name)),
          const SizedBox(width: 8),
          Text(value.toStringAsFixed(4)),
        ],
      ),
    );
  }
}
