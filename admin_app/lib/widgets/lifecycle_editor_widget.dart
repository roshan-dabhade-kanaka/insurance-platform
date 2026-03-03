import 'package:flutter/material.dart';

/// Single state node for [LifecycleEditorWidget].
class LifecycleStateNode {
  const LifecycleStateNode({
    required this.id,
    required this.label,
    this.subtitle,
    this.isActive = false,
    this.isInitial = false,
  });

  final String id;
  final String label;
  final String? subtitle;
  final bool isActive;
  final bool isInitial;
}

/// Visual workflow/lifecycle editor: states as nodes with connectors.
/// Used in lifecycle state editor and workflow configurator.
class LifecycleEditorWidget extends StatelessWidget {
  const LifecycleEditorWidget({
    super.key,
    required this.states,
    this.onAddState,
    this.onTapState,
  });

  final List<LifecycleStateNode> states;
  final VoidCallback? onAddState;
  final void Function(String id)? onTapState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      children: [
        ...states.asMap().entries.map((e) {
          final i = e.key;
          final s = e.value;
          final isLast = i == states.length - 1;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: onTapState != null ? () => onTapState!(s.id) : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 200,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: s.isActive ? colorScheme.primaryContainer : colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: s.isActive ? colorScheme.primary : colorScheme.outlineVariant,
                      width: s.isActive ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: s.isInitial ? Colors.green : (s.isActive ? colorScheme.primary : colorScheme.outline),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              s.label,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: s.isActive ? FontWeight.w700 : FontWeight.w600,
                              ),
                            ),
                            if (s.subtitle != null)
                              Text(
                                s.subtitle!,
                                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Icon(Icons.arrow_downward, size: 20, color: colorScheme.outline),
                ),
            ],
          );
        }),
        if (onAddState != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onAddState,
            icon: const Icon(Icons.add),
            label: const Text('Add state'),
          ),
        ],
      ],
    );
  }
}
