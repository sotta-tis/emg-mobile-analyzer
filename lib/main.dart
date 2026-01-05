import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emg_mobile_analyzer/core/app_router.dart';
import 'package:emg_mobile_analyzer/core/theme.dart';
import 'package:emg_mobile_analyzer/emg_normalizer_const.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadEmgNormalizerFromAsset();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      routerConfig: router,
      themeMode: ThemeMode.system,
      theme: lightTheme,
      darkTheme: darkTheme,
    );
  }
}
