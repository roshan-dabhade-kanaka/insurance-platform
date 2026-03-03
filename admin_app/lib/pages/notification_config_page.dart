import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/widgets.dart';
import '../core/api_client.dart';
import '../providers/admin_providers.dart';

class NotificationConfigPage extends ConsumerStatefulWidget {
  const NotificationConfigPage({super.key});

  @override
  ConsumerState<NotificationConfigPage> createState() =>
      _NotificationConfigPageState();
}

class _NotificationConfigPageState
    extends ConsumerState<NotificationConfigPage> {
  List<NotificationChannelItem> _channels = [];
  bool _initialized = false;

  void _syncChannels(Map<String, dynamic> config) {
    _channels = [
      NotificationChannelItem(
        id: 'email',
        name: 'Email Notifications',
        channelType: 'Email',
        enabled: config['emailEnabled'] as bool? ?? true,
      ),
      NotificationChannelItem(
        id: 'sms',
        name: 'SMS Notifications',
        channelType: 'SMS',
        enabled: config['smsEnabled'] as bool? ?? false,
      ),
      NotificationChannelItem(
        id: 'push',
        name: 'Push Notifications',
        channelType: 'Push',
        enabled: config['pushEnabled'] as bool? ?? false,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(notificationConfigProvider);

    return configAsync.when(
      data: (config) {
        if (!_initialized) {
          _syncChannels(config);
          _initialized = true;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Notification Configuration',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage email and SMS triggers for various lifecycle events.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              NotificationConfigWidget(
                channels: _channels,
                onToggle: (id, enabled) {
                  setState(() {
                    final idx = _channels.indexWhere((c) => c.id == id);
                    if (idx != -1) {
                      final old = _channels[idx];
                      _channels[idx] = NotificationChannelItem(
                        id: old.id,
                        name: old.name,
                        channelType: old.channelType,
                        enabled: enabled,
                      );
                    }
                  });
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save),
                label: const Text('Save Settings'),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Future<void> _saveSettings() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final client = ref.read(apiClientProvider);
      final payload = {
        'emailEnabled': _channels.firstWhere((c) => c.id == 'email').enabled,
        'smsEnabled': _channels.firstWhere((c) => c.id == 'sms').enabled,
        'pushEnabled': _channels.firstWhere((c) => c.id == 'push').enabled,
      };

      // Real API call
      await client.post('/notifications/config', data: payload);

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
