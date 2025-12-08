import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:emg_mobile_analyzer/shells/template_shell.dart';
import 'package:emg_mobile_analyzer/pages/home_page.dart';
import 'package:emg_mobile_analyzer/features/core_ml/widgets/core_ml_widget.dart';
import 'package:emg_mobile_analyzer/features/ble/widgets/ble_widget.dart';
import 'package:emg_mobile_analyzer/features/audio_analysis/widgets/audio_analysis_widget.dart';

final router = GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder:
          (context, state, child) =>
              TemplateShell(currentPath: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(path: '/core-ml', builder: (_, __) => const CoreMLWidget()),
        GoRoute(
          path: '/audio-analysis',
          builder: (_, __) => const AudioAnalysisWidget(),
        ),
        GoRoute(
          path: '/ble',
          builder:
              (_, __) => Scaffold(
                appBar: AppBar(title: const Text('DEV-BLE')),
                body: const BleTempScannerWidget(),
              ),
        ),
      ],
    ),
  ],
);
