import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class ResponseHandler {
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('$message ✓')),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showError(
    BuildContext context,
    dynamic error, {
    String? fallback,
  }) {
    if (!context.mounted) return;

    String rawMessage = fallback ?? 'An unexpected error occurred';

    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final apiMessage = data['message'];
        if (apiMessage is String) {
          rawMessage = apiMessage;
        } else if (apiMessage is List) {
          rawMessage = apiMessage.join('\n');
        }
      } else if (error.type == DioExceptionType.connectionTimeout) {
        rawMessage = 'Connection timed out. Please check your network.';
      }
    } else if (error is String) {
      rawMessage = error;
    } else {
      rawMessage = error.toString();
    }

    // Map technical messages to non-technical versions
    String message = _mapToFriendlyMessage(rawMessage);

    // Clean up excessively long messages
    if (message.length > 150) {
      message = '${message.substring(0, 147)}...';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static String _mapToFriendlyMessage(String technical) {
    final lower = technical.toLowerCase();

    if (lower.contains('snapshotid should not be empty') ||
        lower.contains('no premium calculation (snapshot) found')) {
      return 'Please calculate the premium first before issuing the policy.';
    }

    if (lower.contains('product version not found')) {
      return 'The selected product version could not be found. Please check the setup.';
    }

    if (lower.contains('forbidden resource') ||
        lower.contains('unauthorized')) {
      return 'You do not have permission to perform this action.';
    }

    if (lower.contains('internal server error')) {
      return 'Something went wrong on our end. Please try again in a moment.';
    }

    if (lower.contains('already exists')) {
      return 'This record already exists in the system.';
    }

    // If it's already a clean message or no mapping found, return as is
    return technical;
  }
}
