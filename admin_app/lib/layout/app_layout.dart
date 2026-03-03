import 'package:flutter/material.dart';
import 'sidebar_navigation.dart';
import 'top_header.dart';

/// Root layout: sidebar + top header + main content.
/// Responsive: narrow width shows drawer instead of permanent sidebar.
class AppLayout extends StatelessWidget {
  const AppLayout({super.key, required this.child, this.title, this.actions});

  final Widget child;
  final String? title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    // Wrap in Builder so Scaffold.of(context) in _openDrawer has a
    // descendant context that has the Scaffold as an ancestor.
    return Scaffold(
      drawer: isWide ? null : const _DrawerSidebar(),
      body: Builder(
        builder: (innerContext) => Row(
          children: [
            if (isWide) const SidebarNavigation(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TopHeader(
                    title: title,
                    actions: actions,
                    onMenuTap: isWide ? null : () => _openDrawer(innerContext),
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDrawer(BuildContext context) {
    Scaffold.of(context).openDrawer();
  }
}

class _DrawerSidebar extends StatelessWidget {
  const _DrawerSidebar();

  @override
  Widget build(BuildContext context) {
    return Drawer(child: const SidebarNavigation());
  }
}
