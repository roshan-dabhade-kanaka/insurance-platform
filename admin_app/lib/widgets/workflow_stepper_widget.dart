import 'package:flutter/material.dart';

/// Single step in [WorkflowStepperWidget].
class WorkflowStep {
  const WorkflowStep({
    required this.title,
    this.subtitle,
    this.icon,
    this.isActive = false,
    this.isCompleted = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool isActive;
  final bool isCompleted;
}

/// Stepper for approval workflows and multi-step flows (e.g. risk profiling,
/// workflow configurator). Material 3 stepper style.
class WorkflowStepperWidget extends StatelessWidget {
  const WorkflowStepperWidget({
    super.key,
    required this.steps,
    this.currentIndex = 0,
    this.onStepTap,
  });

  final List<WorkflowStep> steps;
  final int currentIndex;
  final void Function(int)? onStepTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        steps.length * 2 - 1,
        (i) {
          if (i.isOdd) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.chevron_right, size: 20, color: colorScheme.outline),
            );
          }
          final idx = i ~/ 2;
          final step = steps[idx];
          final isActive = idx == currentIndex;
          final isCompleted = step.isCompleted || idx < currentIndex;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onStepTap != null ? () => onStepTap!(idx) : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? colorScheme.primary
                            : isActive
                                ? colorScheme.primary.withValues(alpha: 0.2)
                                : colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: isCompleted
                          ? Icon(Icons.check, size: 18, color: colorScheme.onPrimary)
                          : (step.icon != null
                              ? Icon(step.icon, size: 18, color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant)
                              : Center(
                                  child: Text(
                                    '${idx + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                )),
                    ),
                    const SizedBox(width: 8),
                    if (step.title.isNotEmpty)
                      Text(
                        step.title,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                          color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
