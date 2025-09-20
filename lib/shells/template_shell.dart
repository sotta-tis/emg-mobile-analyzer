import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TemplateShell extends StatelessWidget {
  final Widget child;
  final String currentPath;

  const TemplateShell({
    super.key,
    required this.child,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context) {
    int index = 0;
    if (currentPath.startsWith('/search')) index = 1;

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) {
          switch (i) {
            case 0:
              context.go('/home');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'add',
          ),
        ],
      ),
    );
  }
}
