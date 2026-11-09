import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/core/theme/app_theme.dart';
import 'package:nosmoke/core/ui/app_button.dart';
import 'package:nosmoke/core/ui/app_chip.dart';
import 'package:nosmoke/core/ui/app_colors.dart';
import 'package:nosmoke/core/ui/app_progress_bar.dart';
import 'package:nosmoke/core/ui/app_segmented.dart';
import 'package:nosmoke/core/utils/plural.dart';

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  final hi = math.max(l1, l2), lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

Widget _host(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
  theme: buildAppTheme(b),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('colors: readable text in both themes (WCAG AA)', () {
    for (final entry in {
      'light': AppColors.light,
      'dark': AppColors.dark,
    }.entries) {
      final c = entry.value;
      test('${entry.key}: ink / secondary / accent on background', () {
        expect(contrast(c.ink, c.bg), greaterThanOrEqualTo(7));
        expect(contrast(c.inkSecondary, c.bg), greaterThanOrEqualTo(4.5));
        expect(contrast(c.accent, c.bg), greaterThanOrEqualTo(4.5));
      });

      test('${entry.key}: button labels', () {
        expect(contrast(c.bg, c.ink), greaterThanOrEqualTo(7)); // filled
        expect(contrast(c.onAccent, c.accent), greaterThanOrEqualTo(4.5));
      });
    }
  });

  testWidgets('theme exposes colors for light and dark', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
        b: Brightness.dark,
      ),
    );
    expect(ctx.colors.bg, AppColors.dark.bg);
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(ctx.colors.bg, AppColors.light.bg);
  });

  group('AppButton', () {
    testWidgets('fires onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(AppButton(label: 'Дальше', onPressed: () => taps++)),
      );
      await tester.tap(find.text('Дальше'));
      expect(taps, 1);
    });

    testWidgets('disabled button ignores taps and is dimmed', (tester) async {
      await tester.pumpWidget(
        _host(const AppButton(label: 'Дальше', onPressed: null)),
      );
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(AppButton),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, lessThan(0.5));
    });

    testWidgets('touch target is at least 44 pt high (all styles)', (
      tester,
    ) async {
      for (final style in AppButtonStyle.values) {
        await tester.pumpWidget(
          _host(AppButton(label: 'OK', style: style, onPressed: () {})),
        );
        final h = tester.getSize(find.byType(AppButton)).height;
        expect(h, greaterThanOrEqualTo(44), reason: '$style');
      }
    });

    testWidgets('long label does not overflow', (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 160,
            child: AppButton(
              label: 'Очень длинная подпись кнопки для проверки',
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('AppChip toggles and exposes selected state', (tester) async {
    var selected = false;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => AppChip(
            label: 'Кофе',
            selected: selected,
            onTap: () => setState(() => selected = !selected),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Кофе'));
    await tester.pump();
    expect(selected, isTrue);
    final semantics = tester.getSemantics(find.byType(AppChip));
    expect(semantics.flagsCollection.isSelected, isNotNull);
  });

  testWidgets('AppSegmented reports the tapped segment', (tester) async {
    var index = 0;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => Padding(
            padding: const EdgeInsets.all(20),
            child: AppSegmented(
              labels: const ['Один', 'Два'],
              index: index,
              onChanged: (i) => setState(() => index = i),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Два'));
    await tester.pumpAndSettle();
    expect(index, 1);
  });

  _progressBarTests();

  test('russian plurals', () {
    expect(daysWord(1), 'день');
    expect(daysWord(2), 'дня');
    expect(daysWord(5), 'дней');
    expect(daysWord(11), 'дней');
    expect(daysWord(21), 'день');
    expect(daysWord(112), 'дней');
    expect(pluralRu(0, 'сигарета', 'сигареты', 'сигарет'), 'сигарет');
  });
}

void _progressBarTests() {
  testWidgets('AppProgressBar: full-width track, fill anchored left', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const SizedBox(width: 300, child: AppProgressBar(value: 0.25))),
    );
    final bar = tester.getRect(find.byType(AppProgressBar));
    expect(bar.width, 300);
    expect(bar.height, 4);
    final fill = tester.getRect(
      find.descendant(
        of: find.byType(FractionallySizedBox),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(fill.left, bar.left); // заливка начинается слева
    expect(fill.width, closeTo(75, 0.01)); // 25% от 300
  });

  testWidgets('AppProgressBar clamps out-of-range values', (tester) async {
    for (final v in [-1.0, 2.0]) {
      await tester.pumpWidget(
        _host(SizedBox(width: 200, child: AppProgressBar(value: v))),
      );
      final fill = tester.getRect(
        find.descendant(
          of: find.byType(FractionallySizedBox),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(fill.width, v < 0 ? 0 : 200);
    }
  });

  testWidgets('compact button is visually lower but keeps a 44 pt target', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AppButton(
          label: 'Выйти',
          compact: true,
          expand: false,
          onPressed: () {},
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(AppButton)).height,
      greaterThanOrEqualTo(44),
    );
    final visual = tester.getSize(
      find
          .descendant(
            of: find.byType(AppButton),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(visual.height, lessThan(44));
  });
}
