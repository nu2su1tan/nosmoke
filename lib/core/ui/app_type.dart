import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Шкала шрифтов: крупные цифры, плотный трекинг у заголовков и мелкие
/// капительные подписи, как в швейцарской типографике.
class AppType {
  const AppType(this.c);

  final AppColors c;

  static const _tabular = [FontFeature.tabularFigures()];

  /// Гигантские числа (счётчик дней).
  TextStyle get display => TextStyle(
    fontSize: 112,
    fontWeight: FontWeight.w700,
    letterSpacing: -5,
    height: 0.9,
    color: c.ink,
    fontFeatures: _tabular,
  );

  /// Крупные числа в сетке показателей.
  TextStyle get numeral => TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.2,
    height: 1,
    color: c.ink,
    fontFeatures: _tabular,
  );

  TextStyle get title => TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
    height: 1.05,
    color: c.ink,
  );

  TextStyle get headline => TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.2,
    color: c.ink,
  );

  TextStyle get body => TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.3,
    height: 1.3,
    color: c.ink,
  );

  TextStyle get bodyStrong => body.copyWith(fontWeight: FontWeight.w600);

  TextStyle get callout => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.2,
    height: 1.3,
    color: c.inkSecondary,
  );

  TextStyle get caption => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    height: 1.3,
    color: c.inkSecondary,
  );

  /// Подпись секции и показателя: обычный регистр, читается легче капители.
  TextStyle get label => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.25,
    color: c.inkSecondary,
  );

  TextStyle get button => const TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );
}

extension AppTypeContext on BuildContext {
  AppType get type => AppType(colors);
}
