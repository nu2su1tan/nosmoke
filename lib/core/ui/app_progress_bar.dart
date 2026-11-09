import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Тонкая прогресс-линия без скруглённых «пилюль»: строгая и лёгкая.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({super.key, required this.value, this.color});

  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: c.hairline)),
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value.clamp(0.0, 1.0),
                child: ColoredBox(color: color ?? c.positive),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
