import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'shells/template_shell.dart';
import 'pages/home_page.dart';
import 'widgets/core_ml_widget.dart';
import 'widgets/ble_widget.dart';

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
