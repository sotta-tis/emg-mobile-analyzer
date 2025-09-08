import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:emg_mobile_analyzer/widgets/ffi_sample.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EMG Mobile Analyzer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // BLE高速データ取得セクション
            Card(
              child: ListTile(
                leading: const Icon(Icons.bluetooth),
                title: const Text('BLE高速データ取得'),
                subtitle: const Text('Pico Wからの1kHzサンプリングデータ'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => context.go('/ble'),
              ),
            ),

            const SizedBox(height: 16),

            // Core MLセクション
            Card(
              child: ListTile(
                leading: const Icon(Icons.psychology),
                title: const Text('Core ML モデル'),
                subtitle: const Text('Appleの組み込みAIモデルを使用'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => context.go('/core-ml'),
              ),
            ),

            const SizedBox(height: 16),

            // FFIテストセクション
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.code),
                        SizedBox(width: 8),
                        Text(
                          'Native FFI テスト',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    FfiTestWidget(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
