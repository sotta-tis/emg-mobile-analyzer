import 'package:go_router/go_router.dart';
import './shells/template_shell.dart';
import './pages/home.dart';

final router = GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder:
          (context, state, child) =>
              TemplateShell(currentPath: state.uri.path, child: child),
      routes: [GoRoute(path: '/home', builder: (_, __) => const HomePage())],
    ),
  ],
);
