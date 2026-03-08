import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_provider.dart';
import '../auth/role_access.dart';
import '../navigation/app_router.dart';
import '../theme/app_theme.dart';

/// Sidebar with nav destinations. Only shows routes the current user can access.
class SidebarNavigation extends ConsumerWidget {
  const SidebarNavigation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final route = GoRouterState.of(context).uri.path;
    ref.watch(authVersionProvider);
    final auth = ref.watch(authNotifierProvider);
    final user = auth.user;
    if (user == null) {
      return const SizedBox.shrink();
    }
    final visible = <SidebarDestination>[];
    for (final d in AppRouter.sidebarDestinations) {
      if (d.children != null) {
        final visibleChildren = d.children!
            .where((c) => c.route != null && canAccessRoute(c.route!, user))
            .toList();
        if (visibleChildren.isNotEmpty) {
          visible.add(
            SidebarDestination(
              label: d.label,
              icon: d.icon,
              children: visibleChildren,
            ),
          );
        }
      } else if (d.route != null && canAccessRoute(d.route!, user)) {
        visible.add(d);
      }
    }

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          children: [
            _Logo(),
            const SizedBox(height: 16),
            ...visible.map((d) {
              if (d.children != null) {
                return _NavGroupTile(group: d, currentRoute: route);
              }
              return _NavTile(
                destination: d,
                selected:
                    route == d.route ||
                    (d.route != '/' && route.startsWith(d.route!)),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: AppTheme.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'InsureAdmin',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatefulWidget {
  const _NavTile({required this.destination, required this.selected});

  final SidebarDestination destination;
  final bool selected;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = widget.selected;
    final destination = widget.destination;
    final bgColor = selected
        ? AppTheme.primaryColor.withValues(alpha: 0.1)
        : _hovered
        ? AppTheme.primaryColor.withValues(alpha: 0.12)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              if (destination.route != null) {
                context.go(destination.route!);
              }
              if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
                Navigator.of(context).pop();
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  if (destination.icon != null) ...[
                    Icon(
                      destination.icon,
                      size: 22,
                      color: selected
                          ? AppTheme.primaryColor
                          : theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Text(
                      destination.label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: selected
                            ? AppTheme.primaryColor
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavGroupTile extends StatelessWidget {
  const _NavGroupTile({required this.group, required this.currentRoute});

  final SidebarDestination group;
  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasActiveChild = group.children!.any(
      (c) =>
          currentRoute == c.route ||
          (c.route != null &&
              c.route != '/' &&
              currentRoute.startsWith(c.route!)),
    );

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: hasActiveChild,
        iconColor: AppTheme.primaryColor,
        collapsedIconColor: theme.colorScheme.onSurface,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.only(left: 12),
        leading: group.icon != null
            ? Icon(
                group.icon,
                size: 22,
                color: hasActiveChild
                    ? AppTheme.primaryColor
                    : theme.colorScheme.onSurface,
              )
            : null,
        title: Text(
          group.label,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: hasActiveChild
                ? AppTheme.primaryColor
                : theme.colorScheme.onSurface,
          ),
        ),
        children: group.children!.map((c) {
          return _NavTile(
            destination: c,
            selected:
                currentRoute == c.route ||
                (c.route != null &&
                    c.route != '/' &&
                    currentRoute.startsWith(c.route!)),
          );
        }).toList(),
      ),
    );
  }
}
