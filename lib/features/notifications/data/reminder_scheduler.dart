import 'package:flutter/foundation.dart';

import '../../diary/presentation/diary_controller.dart';
import '../../plan/domain/maintenance.dart';
import '../../profile/domain/profile.dart';
import '../../progress/domain/progress.dart';
import '../../relapse/presentation/relapse_controller.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../smoked/presentation/smoked_controller.dart';
import '../domain/reminder.dart';
import 'notification_service.dart';

/// Пересобирает расписание напоминаний при изменении дневника, срывов
/// или настроек. В режиме закрепления (90+ дней) напоминаний меньше.
class ReminderScheduler {
  ReminderScheduler({
    required this.profile,
    required this.diary,
    required this.settings,
    required this.relapses,
    required this.smoked,
    required this.service,
  }) {
    diary.addListener(refresh);
    settings.addListener(refresh);
    relapses.addListener(refresh);
  }

  final Profile profile;
  final DiaryController diary;
  final SettingsController settings;
  final RelapseController relapses;
  final SmokedController smoked;
  final NotificationService service;

  bool _disposed = false;

  List<Reminder> get currentPlan {
    final s = computeProgress(
      profile,
      relapses.items,
      DateTime.now(),
      smoked: smoked.items,
    );
    return planReminders(
      profile,
      diary.insights,
      maintenance: isMaintenance(s),
    );
  }

  Future<void> refresh() async {
    if (_disposed || !settings.notificationsEnabled) return;
    try {
      await service.schedule(currentPlan);
    } catch (e) {
      // Сбой уведомлений не должен ломать приложение.
      debugPrint('Reminder scheduling failed: $e');
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    diary.removeListener(refresh);
    settings.removeListener(refresh);
    relapses.removeListener(refresh);
  }
}
