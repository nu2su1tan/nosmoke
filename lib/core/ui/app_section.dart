import 'package:flutter/cupertino.dart';

import 'app_colors.dart';
import 'app_type.dart';

/// Тонкая линия-разделитель.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: indent),
    child: SizedBox(
      height: 0.5,
      width: double.infinity,
      child: ColoredBox(color: context.colors.hairline),
    ),
  );
}

/// Секция списка в швейцарском стиле: жирная линия сверху, подпись капителью,
/// строки, разделённые тонкими линиями.
class AppSection extends StatelessWidget {
  const AppSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 28, 20, 0),
  });

  final String? header;
  final String? footer;
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 1, color: c.hairline),
          if (header != null) ...[
            const SizedBox(height: 14),
            Text(header!, style: t.label.copyWith(color: c.ink, fontSize: 16)),
            const SizedBox(height: 2),
          ],
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Hairline(),
            children[i],
          ],
          if (footer != null) ...[
            const SizedBox(height: 8),
            Text(footer!, style: t.caption),
          ],
        ],
      ),
    );
  }
}

/// Строка списка: заголовок, подпись, ведущий и замыкающий элементы.
class AppRow extends StatelessWidget {
  const AppRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.dimmed = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 14)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.body.copyWith(
                    color: destructive
                        ? c.accent
                        : (dimmed ? c.inkTertiary : c.ink),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: t.callout.copyWith(
                      color: dimmed ? c.inkTertiary : c.inkSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
    if (onTap == null) return row;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      alignment: Alignment.centerLeft,
      onPressed: onTap,
      child: SizedBox(width: double.infinity, child: row),
    );
  }
}

/// Маленькая цветная точка-статус.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.size = 10});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
