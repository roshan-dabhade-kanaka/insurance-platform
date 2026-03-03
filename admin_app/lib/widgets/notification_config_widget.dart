import 'package:flutter/material.dart';

/// One notification channel for [NotificationConfigWidget].
class NotificationChannelItem {
  const NotificationChannelItem({
    required this.id,
    required this.name,
    this.enabled = true,
    this.channelType = 'Email',
  });

  final String id;
  final String name;
  final bool enabled;
  final String channelType;
}

/// Toggles and list for notification channels (email, SMS, in-app).
class NotificationConfigWidget extends StatelessWidget {
  const NotificationConfigWidget({
    super.key,
    required this.channels,
    this.onToggle,
    this.onEdit,
  });

  final List<NotificationChannelItem> channels;
  final void Function(String id, bool enabled)? onToggle;
  final void Function(String id)? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Channels',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...channels.map((c) => Card(
              child: SwitchListTile(
                secondary: Icon(
                  c.channelType == 'Email' ? Icons.email_outlined : Icons.sms_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: Text(c.name),
                subtitle: Text(c.channelType),
                value: c.enabled,
                onChanged: onToggle != null ? (v) => onToggle!(c.id, v) : null,
              ),
            )),
      ],
    );
  }
}
