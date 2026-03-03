import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

/// Code-view style panel for JSON (rule payloads, config). Read-only by default.
class JsonPreviewPanel extends StatelessWidget {
  const JsonPreviewPanel({
    super.key,
    required this.data,
    this.title,
    this.maxLines = 24,
    this.copyable = true,
  });

  /// Either a [Map]/[List] (encoded to JSON) or a [String] (shown as-is if valid JSON).
  final dynamic data;
  final String? title;
  final int maxLines;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String text;
    try {
      text = data is String ? data as String : const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      text = data.toString();
    }
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.code, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(title!, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (copyable)
                    TextButton.icon(
                      onPressed: () => _copyToClipboard(context, text),
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: Container(
                width: 600,
                constraints: BoxConstraints(maxHeight: maxLines * 20.0),
                padding: const EdgeInsets.all(16),
                alignment: Alignment.topLeft,
                child: SelectableText(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }
}
