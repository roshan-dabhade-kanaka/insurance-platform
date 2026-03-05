import 'package:flutter/material.dart';

/// A premium information box with a yellow theme, commonly used for tips or help text.
class InfoBox extends StatelessWidget {
  const InfoBox({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
    this.color,
    this.borderColor,
    this.textColor,
  });

  final String message;
  final IconData icon;
  final Color? color;
  final Color? borderColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = color ?? Colors.amber.shade50;
    final strokeColor = borderColor ?? Colors.amber.shade200;
    final contentColor = textColor ?? Colors.amber.shade900;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: strokeColor),
        boxShadow: [
          BoxShadow(
            color: strokeColor.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: contentColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: contentColor,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
