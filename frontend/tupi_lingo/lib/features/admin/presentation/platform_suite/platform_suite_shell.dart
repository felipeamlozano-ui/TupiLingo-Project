import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'developer_console/developer_console_screen.dart';
import 'security_console/security_console_screen.dart';
import 'shared/glass_sidebar.dart';
import 'world_builder/world_builder_screen.dart';

/// Shell Mestre Integrado do TupiLingo Platform Suite (RFC-013 Enterprise).
/// Hospeda e sincroniza os 3 consoles:
/// 0: World Builder CMS
/// 1: Developer Console
/// 2: Security & Observability Console
class PlatformSuiteShell extends StatefulWidget {
  final int initialIndex;

  const PlatformSuiteShell({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<PlatformSuiteShell> createState() => _PlatformSuiteShellState();
}

class _PlatformSuiteShellState extends State<PlatformSuiteShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060B15),
      body: Row(
        children: [
          // Barra de Navegação Lateral
          GlassSidebar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            onBackToApp: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),

          // Console Ativo
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: const [
                WorldBuilderScreen(),
                DeveloperConsoleScreen(),
                SecurityConsoleScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
