import 'package:flutter/material.dart';

class TruncatedText extends StatelessWidget {
  final String text;
  final int maxLength;
  final TextStyle? style;
  final TextAlign? textAlign;
  final bool useEllipsis;
  final String? tooltipLabel;

  const TruncatedText(
    this.text, {
    super.key,
    this.maxLength = 12,
    this.style,
    this.textAlign,
    this.useEllipsis = true,
    this.tooltipLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (text.length <= maxLength) {
      return Text(text, style: style, textAlign: textAlign);
    }

    final truncated = useEllipsis
        ? '${text.substring(0, maxLength)}…'
        : text.substring(0, maxLength);

    return Tooltip(
      message: tooltipLabel != null ? '$tooltipLabel: $text' : text,
      preferBelow: false,
      child: Text(truncated, style: style, textAlign: textAlign),
    );
  }
}
