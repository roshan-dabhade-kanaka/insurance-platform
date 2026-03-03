import 'package:flutter/material.dart';

/// Single audit log entry for [AuditLogTable].
class AuditLogEntry {
  const AuditLogEntry({
    required this.timestamp,
    required this.eventType,
    required this.description,
    this.userRole,
    this.ipAddress,
    this.icon,
    this.iconColor,
  });

  final String timestamp;
  final String eventType;
  final String description;
  final String? userRole;
  final String? ipAddress;
  final IconData? icon;
  final Color? iconColor;
}

/// Table/list of audit entries (compliance, activity logs).
class AuditLogTable extends StatelessWidget {
  const AuditLogTable({
    super.key,
    required this.entries,
    this.title,
    this.emptyMessage = 'No entries',
  });

  final List<AuditLogEntry> entries;
  final String? title;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(emptyMessage, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(title!, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
        ...entries.map((e) => _AuditRow(entry: e)),
      ],
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});

  final AuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = entry.iconColor ?? theme.colorScheme.primary;
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(entry.icon ?? Icons.history, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.eventType, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(entry.description, style: theme.textTheme.bodySmall),
                  if (entry.userRole != null || entry.ipAddress != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      [if (entry.userRole != null) entry.userRole, if (entry.ipAddress != null) entry.ipAddress].join(' • '),
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            Text(entry.timestamp, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
