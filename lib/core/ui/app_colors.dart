import 'package:flutter/material.dart';

/// Палитра в духе швейцарского стиля: белый/чёрный, серые для второстепенного
/// и один сигнальный красный. Зелёный только для «успеха».
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.ink,
    required this.inkSecondary,
    required this.inkTertiary,
    required this.hairline,
    required this.fill,
    required this.accent,
    required this.onAccent,
    required this.positive,
  });

  final Color bg;
  final Color ink;
  final Color inkSecondary;
  final Color inkTertiary;
  final Color hairline;

  /// Лёгкая подложка для полей ввода и сегментов.
  final Color fill;

  /// Сигнальный красный: SOS, срыв, удаление.
  final Color accent;

  /// Цвет текста и иконок на красном фоне (в тёмной теме чёрный: так контрастнее).
  final Color onAccent;
  final Color positive;

  static const light = AppColors(
    bg: Color(0xFFFBF8F4),
    ink: Color(0xFF1C1B1A),
    inkSecondary: Color(0xFF6B655E),
    inkTertiary: Color(0xFFA9A29A),
    hairline: Color(0xFFE6E0D7),
    fill: Color(0xFFF1ECE4),
    accent: Color(0xFFE3112B),
    onAccent: Color(0xFFFFFFFF),
    positive: Color(0xFF2E9E5B),
  );

  static const dark = AppColors(
    bg: Color(0xFF110F0E),
    ink: Color(0xFFF5F1EC),
    inkSecondary: Color(0xFFA09A92),
    inkTertiary: Color(0xFF6E6862),
    hairline: Color(0xFF332F2B),
    fill: Color(0xFF1F1C1A),
    accent: Color(0xFFFF453A),
    onAccent: Color(0xFF000000),
    positive: Color(0xFF30D158),
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? ink,
    Color? inkSecondary,
    Color? inkTertiary,
    Color? hairline,
    Color? fill,
    Color? accent,
    Color? onAccent,
    Color? positive,
  }) => AppColors(
    bg: bg ?? this.bg,
    ink: ink ?? this.ink,
    inkSecondary: inkSecondary ?? this.inkSecondary,
    inkTertiary: inkTertiary ?? this.inkTertiary,
    hairline: hairline ?? this.hairline,
    fill: fill ?? this.fill,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    positive: positive ?? this.positive,
  );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      inkTertiary: Color.lerp(inkTertiary, other.inkTertiary, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      fill: Color.lerp(fill, other.fill, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
