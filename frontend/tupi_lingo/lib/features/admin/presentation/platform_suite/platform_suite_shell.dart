import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 768;

        final titles = [
          'World Builder CMS',
          'Developer Console',
          'Security & Observability',
        ];

        final activeConsole = IndexedStack(
          index: _currentIndex,
          children: const [
            WorldBuilderScreen(),
            DeveloperConsoleScreen(),
            SecurityConsoleScreen(),
          ],
        );

        if (isDesktop) {
          return Scaffold(
            backgroundColor: AppTheme.bg(context),
            body: Row(
              children: [
                // Barra de Navegação Lateral Desktop
                GlassSidebar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) {
                    setState(() => _currentIndex = index);
                  },
                  onBackToApp: () {
                    final nav = Navigator.of(context);
                    if (nav.canPop()) {
                      nav.pop();
                    } else {
                      nav.pushReplacementNamed('/home');
                    }
                  },
                ),

                // Console Ativo
                Expanded(child: activeConsole),
              ],
            ),
          );
        }

        // Layout Mobile (< 768px):
        return Scaffold(
          backgroundColor: AppTheme.bg(context),
          appBar: AppBar(
            backgroundColor: AppTheme.surface(context),
            elevation: 0,
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: Icon(Icons.menu_rounded, color: AppTheme.accent(context)),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                tooltip: 'Menu de Consoles',
              ),
            ),
            title: Text(
              titles[_currentIndex],
              style: TextStyle(
                color: AppTheme.textPrimary(context),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: AppTheme.textSecondary(context)),
                onPressed: () {
                  final nav = Navigator.of(context);
                  if (nav.canPop()) {
                    nav.pop();
                  } else {
                    nav.pushReplacementNamed('/home');
                  }
                },
                tooltip: 'Voltar ao App',
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1.0),
              child: Container(
                color: AppTheme.border(context),
                height: 1.0,
              ),
            ),
          ),
          drawer: Drawer(
            backgroundColor: AppTheme.surface(context),
            child: SafeArea(
              child: GlassSidebar(
                width: double.infinity,
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() => _currentIndex = index);
                  Navigator.of(context).pop();
                },
                onBackToApp: () {
                  Navigator.of(context).pop();
                  final nav = Navigator.of(context);
                  if (nav.canPop()) {
                    nav.pop();
                  } else {
                    nav.pushReplacementNamed('/home');
                  }
                },
              ),
            ),
          ),
          body: activeConsole,
        );
      },
    );
  }
}
