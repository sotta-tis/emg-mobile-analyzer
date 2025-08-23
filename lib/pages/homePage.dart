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
      appBar: AppBar(title: const Text('Home')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.psychology),
                title: const Text('Core ML モデル'),
                subtitle: const Text('Appleの組み込みAIモデルを使用'),
                onTap: () => context.go('/core-ml'),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const FfiTestWidget(), // FFIテスト用ウィジェットを表示
          ],
        ),
      ),
    );
  }
}
