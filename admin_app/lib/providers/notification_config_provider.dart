import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';

/// Backend notification config: emailEnabled, smsEnabled, pushEnabled, channels.
class NotificationConfigModel {
  const NotificationConfigModel({
    this.emailEnabled = true,
    this.smsEnabled = false,
    this.pushEnabled = false,
    this.channels = const {},
  });

  final bool emailEnabled;
  final bool smsEnabled;
  final bool pushEnabled;
  final Map<String, dynamic> channels;

  factory NotificationConfigModel.fromJson(Map<String, dynamic> json) {
    return NotificationConfigModel(
      emailEnabled: (json['emailEnabled'] ?? json['email_enabled']) as bool? ?? true,
      smsEnabled: (json['smsEnabled'] ?? json['sms_enabled']) as bool? ?? false,
      pushEnabled: (json['pushEnabled'] ?? json['push_enabled']) as bool? ?? false,
      channels: json['channels'] is Map ? Map<String, dynamic>.from(json['channels'] as Map) : {},
    );
  }

  Map<String, dynamic> toJson() => {
        'emailEnabled': emailEnabled,
        'smsEnabled': smsEnabled,
        'pushEnabled': pushEnabled,
        'channels': channels,
      };
}

final notificationConfigProvider =
    FutureProvider<NotificationConfigModel?>((ref) async {
  try {
    final client = ref.watch(apiClientProvider);
    final res = await client.get('/notifications/config');
    if (res.statusCode == 200 && res.data != null) {
      return NotificationConfigModel.fromJson(res.data as Map<String, dynamic>);
    }
    return null;
  } catch (_) {
    return null;
  }
});
