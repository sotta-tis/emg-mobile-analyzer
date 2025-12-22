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
              context.go('/');
              break;
            case 1:
              context.go('/emg');
              break;
            case 2:
              context.go('/dev');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '/'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'EMG'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Dev'),
        ],
      ),
    );
  }
}
