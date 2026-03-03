import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../widgets/widgets.dart';
import '../providers/notification_config_provider.dart';

/// Notification configuration: load from API, toggle channels via API.
class NotificationConfigurationPage extends ConsumerWidget {
  const NotificationConfigurationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(notificationConfigProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Notification channels',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 24),
          configAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Failed to load config: $e',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
            data: (config) {
              if (config == null) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Could not load notification config.'),
                  ),
                );
              }
              final channels = [
                NotificationChannelItem(
                  id: 'email',
                  name: 'Policy issued & Claim status (Email)',
                  enabled: config.emailEnabled,
                  channelType: 'Email',
                ),
                NotificationChannelItem(
                  id: 'sms',
                  name: 'SMS alerts',
                  enabled: config.smsEnabled,
                  channelType: 'SMS',
                ),
                NotificationChannelItem(
                  id: 'push',
                  name: 'Push notifications',
                  enabled: config.pushEnabled,
                  channelType: 'Push',
                ),
              ];
              return NotificationConfigWidget(
                channels: channels,
                onToggle: (id, enabled) async {
                  try {
                    Map<String, dynamic> patch = {};
                    if (id == 'email') patch['emailEnabled'] = enabled;
                    if (id == 'sms') patch['smsEnabled'] = enabled;
                    if (id == 'push') patch['pushEnabled'] = enabled;
                    if (patch.isNotEmpty) {
                      final client = ref.read(apiClientProvider);
                      await client.post('/notifications/config', data: patch);
                      ref.invalidate(notificationConfigProvider);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Config updated')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Update failed: $e')),
                      );
                    }
                  }
                },
                onEdit: (id) {},
              );
            },
          ),
        ],
      ),
    );
  }
}
