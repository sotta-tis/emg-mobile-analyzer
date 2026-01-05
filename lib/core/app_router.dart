import 'package:go_router/go_router.dart';
import 'package:emg_mobile_analyzer/shells/template_shell.dart';
import 'package:emg_mobile_analyzer/screens/home_screen.dart';
import 'package:emg_mobile_analyzer/screens/emg_screen.dart';
import 'package:emg_mobile_analyzer/screens/dev_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder:
          (context, state, child) =>
              TemplateShell(currentPath: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomeScreen()),

        GoRoute(path: '/emg', builder: (_, __) => const EmgScreen()),

        GoRoute(path: '/dev', builder: (_, __) => const DevScreen()),
      ],
    ),
  ],
);
