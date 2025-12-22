import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emg_mobile_analyzer/widgets/dev/ffi_sample.dart';
import 'package:emg_mobile_analyzer/widgets/dev/model_load.dart';
import 'package:emg_mobile_analyzer/widgets/dev/demo_dataset_inference.dart';

class DevScreen extends ConsumerStatefulWidget {
  const DevScreen({super.key});

  @override
  ConsumerState<DevScreen> createState() => _DevScreenState();
}

class _DevScreenState extends ConsumerState<DevScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dev')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // モデルロード単体テスト
            const ModelLoadTestWidget(),

            const SizedBox(height: 12),

            const SizedBox(height: 12),

            // データセット推論テスト
            const DemoDatasetInferenceCard(),

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
