import 'package:flutter/cupertino.dart';

import 'app_colors.dart';
import 'app_type.dart';

/// Информационный блок: цветная полоса слева, заголовок и текст.
class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.title,
    this.body,
    this.accent = false,
    this.onTap,
    this.onClose,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 0),
  });

  final String title;
  final String? body;

  /// Красная полоса (предупреждение) вместо чёрной.
  final bool accent;
  final VoidCallback? onTap;
  final VoidCallback? onClose;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final content = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 3, color: accent ? c.accent : c.ink),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.bodyStrong),
                  if (body != null) ...[
                    const SizedBox(height: 4),
                    Text(body!, style: t.callout),
                  ],
                ],
              ),
            ),
          ),
          if (onClose != null)
            CupertinoButton(
              padding: const EdgeInsets.only(left: 12),
              minimumSize: Size.zero,
              onPressed: onClose,
              child: Icon(CupertinoIcons.xmark, size: 16, color: c.inkTertiary),
            ),
        ],
      ),
    );
    return Padding(
      padding: padding,
      child: onTap == null
          ? content
          : CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              alignment: Alignment.centerLeft,
              onPressed: onTap,
              child: SizedBox(width: double.infinity, child: content),
            ),
    );
  }
}
