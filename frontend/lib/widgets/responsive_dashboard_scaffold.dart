import 'dart:math' as math;

import 'package:flutter/material.dart';

class ResponsiveDashboardScaffold extends StatelessWidget {
  final Widget sideNavigation;
  final Widget topNavigation;
  final Widget mainContent;
  final Color backgroundColor;
  final double desktopBreakpoint;
  final double mobileMinContentWidth;

  const ResponsiveDashboardScaffold({
    super.key,
    required this.sideNavigation,
    required this.topNavigation,
    required this.mainContent,
    this.backgroundColor = const Color(0xFF1A1F2E),
    this.desktopBreakpoint = 1200,
    this.mobileMinContentWidth = 900,
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
              Expanded(
                child: Column(
                  children: [
                    _wrapForCompact(
                      constraints.maxWidth,
                      topNavigation,
                    ),
                    Expanded(
                      child: _wrapForCompact(
                        constraints.maxWidth,
                        mainContent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _wrapForCompact(double availableWidth, Widget child) {
    final targetWidth = math.max(mobileMinContentWidth, availableWidth);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: targetWidth,
        child: child,
      ),
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
      alignment: Alignment.centerLeft,
      child: IconButton(
        icon: const Icon(Icons.menu, color: Colors.white),
        tooltip: 'Open navigation',
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
    );
  }
}
