import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../domain/widget_snapshot.dart';

/// Обновление виджета и переход из него в приложение.
abstract class WidgetService {
  Future<void> update(WidgetSnapshot s);

  /// Адрес, по которому нажали в виджете (nosmoke://sos), пока приложение
  /// открыто.
  Stream<Uri?> get clicks;

  /// Адрес, по которому приложение было запущено из виджета.
  Future<Uri?> launchUri();
}

class HomeWidgetService implements WidgetService {
  static const androidProvider = 'NoSmokeWidgetProvider';
  static const iosWidget = 'NoSmokeWidget';

  @override
  Future<void> update(WidgetSnapshot s) async {
    try {
      for (final e in s.toMap().entries) {
        await HomeWidget.saveWidgetData<String>(e.key, e.value);
      }
      await HomeWidget.updateWidget(
        androidName: androidProvider,
        iOSName: iosWidget,
      );
    } catch (e) {
      // Платформа без виджетов или виджет не добавлен: это не ошибка.
      debugPrint('Widget update skipped: $e');
    }
  }

  @override
  Stream<Uri?> get clicks {
    try {
      return HomeWidget.widgetClicked;
    } catch (_) {
      return const Stream.empty();
    }
  }

  @override
  Future<Uri?> launchUri() async {
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (_) {
      return null;
    }
  }
}

class NoWidgetService implements WidgetService {
  @override
  Stream<Uri?> get clicks => const Stream.empty();

  @override
  Future<Uri?> launchUri() async => null;

  @override
  Future<void> update(WidgetSnapshot s) async {}
}
