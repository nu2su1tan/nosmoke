import 'package:flutter/services.dart';

/// Тактильный отклик, как в нативных iOS-приложениях.
class Haptics {
  const Haptics._();

  static void selection() => HapticFeedback.selectionClick();
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
  static void success() => HapticFeedback.heavyImpact();
}
