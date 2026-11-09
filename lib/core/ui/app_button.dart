import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_type.dart';
import 'haptics.dart';

enum AppButtonStyle {
  /// Чёрная капсула (основное действие).
  filled,

  /// Капсула с тонкой рамкой.
  outlined,

  /// Красная капсула (SOS, опасное действие).
  danger,

  /// Просто текст.
  text,
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = AppButtonStyle.filled,
    this.icon,
    this.expand = true,
    this.compact = false,
    this.height,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final IconData? icon;
  final bool expand;

  /// Низкая кнопка для строк списка (зона нажатия всё равно не меньше 44 pt).
  final bool compact;

  /// Явная высота, если нужна нестандартная.
  final double? height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null;
    final (Color bg, Color fg, BorderSide border) = switch (style) {
      AppButtonStyle.filled => (c.ink, c.bg, BorderSide.none),
      AppButtonStyle.outlined => (
        Colors.transparent,
        c.ink,
        BorderSide(color: c.ink, width: 1.2),
      ),
      AppButtonStyle.danger => (c.accent, c.onAccent, BorderSide.none),
      AppButtonStyle.text => (
        Colors.transparent,
        c.inkSecondary,
        BorderSide.none,
      ),
    };

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.type.button.copyWith(
              color: fg,
              fontSize: compact ? 15 : null,
            ),
          ),
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: enabled
            ? () {
                Haptics.light();
                onPressed!();
              }
            : null,
        child: Container(
          height:
              height ??
              (compact ? 38 : (style == AppButtonStyle.text ? 44 : 54)),
          padding: EdgeInsets.symmetric(
            horizontal: style == AppButtonStyle.text ? 8 : (compact ? 18 : 24),
          ),
          decoration: ShapeDecoration(
            color: bg,
            shape: StadiumBorder(side: border),
          ),
          child: content,
        ),
      ),
    );
  }
}
