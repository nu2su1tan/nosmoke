import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_type.dart';
import 'haptics.dart';

/// Капсула-переключатель: выбранная — залитая, обычная — с тонкой рамкой.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptics.selection();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: ShapeDecoration(
            color: selected ? c.ink : Colors.transparent,
            shape: StadiumBorder(
              side: BorderSide(
                color: selected ? c.ink : c.hairline,
                width: 1.2,
              ),
            ),
          ),
          child: Text(
            label,
            style: context.type.callout.copyWith(
              color: selected ? c.bg : c.ink,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
