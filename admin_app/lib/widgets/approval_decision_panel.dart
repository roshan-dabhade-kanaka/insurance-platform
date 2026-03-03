import 'package:flutter/material.dart';

/// Actions for [ApprovalDecisionPanel]: Approve / Reject / Request info.
enum ApprovalAction { approve, reject, requestInfo }

/// Panel for underwriting/finance approval: show summary and Approve/Reject actions.
class ApprovalDecisionPanel extends StatelessWidget {
  const ApprovalDecisionPanel({
    super.key,
    required this.title,
    this.subtitle,
    this.detailWidget,
    this.onApprove,
    this.onReject,
    this.onRequestInfo,
    this.approveLabel = 'Approve',
    this.rejectLabel = 'Reject',
  });

  final String title;
  final String? subtitle;
  final Widget? detailWidget;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onRequestInfo;
  final String approveLabel;
  final String rejectLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
            if (detailWidget != null) ...[
              const SizedBox(height: 16),
              detailWidget!,
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                if (onApprove != null)
                  FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: Text(approveLabel),
                  ),
                if (onApprove != null && onReject != null) const SizedBox(width: 12),
                if (onReject != null)
                  FilledButton.tonal(
                    onPressed: onReject,
                    style: FilledButton.styleFrom(foregroundColor: theme.colorScheme.error),
                    child: Text(rejectLabel),
                  ),
                if (onRequestInfo != null) ...[
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: onRequestInfo,
                    child: const Text('Request info'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
