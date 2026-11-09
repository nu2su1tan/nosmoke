import 'package:flutter/cupertino.dart';

import 'app_colors.dart';
import 'app_type.dart';
import 'haptics.dart';

/// Нативный сегмент-переключатель iOS.
class AppSegmented extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: index,
        backgroundColor: c.fill,
        thumbColor: c.bg,
        onValueChanged: (v) {
          if (v == null) return;
          Haptics.selection();
          onChanged(v);
        },
        children: {
          for (var i = 0; i < labels.length; i++)
            i: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                labels[i],
                style: t.callout.copyWith(
                  color: c.ink,
                  fontWeight: i == index ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
        },
      ),
    );
  }
}
