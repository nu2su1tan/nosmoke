import 'package:flutter/cupertino.dart';

import 'app_colors.dart';
import 'app_type.dart';

/// Поле ввода: подпись капителью сверху и мягкая подложка, как в iOS.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    this.placeholder,
    this.keyboardType,
    this.maxLength,
    this.maxLines = 1,
    this.onChanged,
    this.errorText,
    this.textCapitalization = TextCapitalization.none,
    this.fieldKey,
  });

  final TextEditingController controller;
  final String? label;
  final String? placeholder;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final TextCapitalization textCapitalization;

  /// Ключ самого поля (для тестов и фокуса).
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: t.label),
          const SizedBox(height: 8),
        ],
        CupertinoTextField(
          key: fieldKey,
          controller: controller,
          placeholder: placeholder,
          keyboardType: keyboardType,
          maxLength: maxLength,
          maxLines: maxLines,
          minLines: maxLines > 1 ? 2 : 1,
          onChanged: onChanged,
          textCapitalization: textCapitalization,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          style: t.body,
          placeholderStyle: t.body.copyWith(color: c.inkTertiary),
          cursorColor: c.ink,
          decoration: BoxDecoration(
            color: c.fill,
            borderRadius: BorderRadius.circular(14),
            border: errorText == null
                ? null
                : Border.all(color: c.accent, width: 1.2),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(errorText!, style: t.caption.copyWith(color: c.accent)),
        ],
      ],
    );
  }
}
