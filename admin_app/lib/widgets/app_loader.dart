import 'package:flutter/material.dart';

/// Single consistent loading indicator across the app: circular spinner.
/// Use this everywhere instead of LinearProgressIndicator or ad-hoc CircularProgressIndicator.
/// [size] defaults to 40; use a smaller value (e.g. 20) for buttons or inline.
/// [center] when true (default) wraps in Center; set false when used inside a button or row.
class AppLoader extends StatelessWidget {
  const AppLoader({
    super.key,
    this.size = 40,
    this.center = true,
    this.strokeWidth,
  });

  final double size;
  final bool center;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    final stroke = strokeWidth ?? (size <= 24 ? 2.0 : 2.5);
    final indicator = SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: stroke),
    );
    if (center) return Center(child: indicator);
    return indicator;
  }
}
