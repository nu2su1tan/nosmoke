import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../ui/app_colors.dart';
import '../ui/app_type.dart';

ThemeData buildAppTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final t = AppType(c);
  final base = ThemeData(brightness: brightness, useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: c.ink,
      onPrimary: c.bg,
      secondary: c.accent,
      onSecondary: c.onAccent,
      error: c.accent,
      onError: c.onAccent,
      surface: c.bg,
      onSurface: c.ink,
    ),
    extensions: [c],
    // Без Material-ряби: нативное нажатие iOS работает через прозрачность.
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    dividerColor: c.hairline,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    textTheme: base.textTheme.apply(bodyColor: c.ink, displayColor: c.ink),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.ink,
      contentTextStyle: t.body.copyWith(color: c.bg, fontSize: 15),
      shape: const RoundedSuperellipseBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      elevation: 0,
    ),
    textSelectionTheme: TextSelectionThemeData(cursorColor: c.ink),
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: brightness,
      primaryColor: c.ink,
      scaffoldBackgroundColor: c.bg,
      barBackgroundColor: c.bg.withValues(alpha: 0.9),
      textTheme: CupertinoTextThemeData(
        primaryColor: c.ink,
        textStyle: t.body,
        navTitleTextStyle: t.bodyStrong,
        navLargeTitleTextStyle: t.title,
        navActionTextStyle: t.body,
      ),
    ),
  );
}
