import 'package:go_router/go_router.dart';
import 'shells/templateShell.dart';
import 'pages/homePage.dart';
import 'widgets/core_ml_widget.dart';

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
      ],
    ),
  ],
);
