import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import '../../../core/utils/formatters.dart';
import '../domain/health_metrics.dart';

enum HealthAccess { granted, denied, unavailable }

abstract class HealthSource {
  Future<HealthAccess> connect();
  Future<List<DailyHealth>> daily(DateTime from, DateTime to);
}

/// Apple Health (iOS) и Health Connect (Android).
///
/// Android ограничивает чтение историей в 30 дней до первой выдачи доступа,
/// поэтому «до отказа» может не набраться, если человек подключается позже.
class PlatformHealthSource implements HealthSource {
  final Health _health = Health();
  bool _configured = false;

  static const _types = [
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.STEPS,
  ];

  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Future<HealthAccess> connect() async {
    if (!_supported) return HealthAccess.unavailable;
    try {
      if (!_configured) {
        await _health.configure();
        _configured = true;
      }
      final ok = await _health.requestAuthorization(
        _types,
        permissions: const [HealthDataAccess.READ, HealthDataAccess.READ],
      );
      return ok ? HealthAccess.granted : HealthAccess.denied;
    } on UnsupportedError {
      return HealthAccess.unavailable; // нет Health Connect
    } catch (e) {
      debugPrint('Health connect failed: $e');
      return HealthAccess.unavailable;
    }
  }

  @override
  Future<List<DailyHealth>> daily(DateTime from, DateTime to) async {
    if (!_supported) return [];
    try {
      final start = dateOnly(from);
      final end = dateOnly(to);
      final points = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.RESTING_HEART_RATE],
        startTime: start,
        endTime: end.add(const Duration(days: 1)),
      );
      final hrByDay = <DateTime, List<double>>{};
      for (final p in points) {
        final v = p.value;
        if (v is NumericHealthValue) {
          hrByDay
              .putIfAbsent(dateOnly(p.dateFrom), () => [])
              .add(v.numericValue.toDouble());
        }
      }
      final result = <DailyHealth>[];
      for (
        var d = start;
        !d.isAfter(end);
        d = DateTime(d.year, d.month, d.day + 1)
      ) {
        final steps = await _health.getTotalStepsInInterval(
          d,
          DateTime(d.year, d.month, d.day + 1),
        );
        final hr = hrByDay[d];
        result.add(
          DailyHealth(
            day: d,
            steps: steps,
            restingHr: hr == null
                ? null
                : hr.reduce((a, b) => a + b) / hr.length,
          ),
        );
      }
      return result;
    } catch (e) {
      debugPrint('Health read failed: $e');
      return [];
    }
  }
}
