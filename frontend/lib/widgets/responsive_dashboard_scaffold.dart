import 'package:flutter/material.dart';

class ResponsiveDashboardScaffold extends StatelessWidget {
  final Widget sideNavigation;
  final Widget topNavigation;
  final Widget mainContent;
  final Color backgroundColor;
  final double desktopBreakpoint;

  const ResponsiveDashboardScaffold({
    super.key,
    required this.sideNavigation,
    required this.topNavigation,
    required this.mainContent,
    this.backgroundColor = const Color(0xFF1A1F2E),
    this.desktopBreakpoint = 1200,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= desktopBreakpoint;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: backgroundColor,
            body: Row(
              children: [
                sideNavigation,
                Expanded(
                  child: Column(
                    children: [
                      topNavigation,
                      Expanded(child: mainContent),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Tablet / compact mode: use drawer for navigation,
        // let content fill available width naturally.
        return Scaffold(
          backgroundColor: backgroundColor,
          drawer: Drawer(
            width: 260,
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: SafeArea(
              child: sideNavigation,
            ),
          ),
          body: Column(
            children: [
              _CompactMenuBar(),
              topNavigation,
              Expanded(child: mainContent),
            ],
          ),
        );
      },
    );
  }
}

class _CompactMenuBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        color: Color(0xFF252A3A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF37404F), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            tooltip: 'Open navigation',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Text(
            'SafeArms',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
