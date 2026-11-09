import 'dart:async';

import 'package:flutter/foundation.dart';

import '../features/home_widget/data/widget_service.dart';
import '../features/home_widget/domain/widget_snapshot.dart';
import '../features/plan/domain/entitlements.dart';
import '../features/plan/presentation/plan_controller.dart';
import '../features/profile/domain/profile.dart';
import '../features/progress/domain/progress.dart';
import '../features/relapse/presentation/relapse_controller.dart';
import '../features/smoked/presentation/smoked_controller.dart';
import '../features/supporters/presentation/supporters_controller.dart';

/// Держит в актуальном состоянии то, что живёт вне экрана приложения:
/// сводку для близких и виджет. Обновляется при срывах, записях «выкурил(а)»
/// и раз в [interval].
class LiveSync {
  LiveSync({
    required this.profile,
    required this.relapses,
    required this.smoked,
    required this.supporters,
    required this.plan,
    required this.widgets,
    this.interval = const Duration(minutes: 15),
  }) {
    relapses.addListener(sync);
    smoked.addListener(sync);
    _timer = Timer.periodic(interval, (_) => sync());
  }

  final Profile profile;
  final RelapseController relapses;
  final SmokedController smoked;
  final SupportersController supporters;
  final PlanController plan;
  final WidgetService widgets;
  final Duration interval;

  Timer? _timer;
  bool _disposed = false;
  WidgetSnapshot? _lastWidget;

  Future<void> sync() async {
    if (_disposed) return;
    final now = DateTime.now();
    final s = computeProgress(
      profile,
      relapses.items,
      now,
      smoked: smoked.items,
    );
    try {
      await supporters.syncProgress(s);
      if (plan.can(PremiumFeature.widgets)) {
        final snap = buildWidgetSnapshot(profile, s, now);
        if (snap != _lastWidget) {
          _lastWidget = snap;
          await widgets.update(snap);
        }
      }
    } catch (e) {
      debugPrint('Live sync failed: $e');
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    relapses.removeListener(sync);
    smoked.removeListener(sync);
  }
}
