import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/features/health/domain/health_milestones.dart';

void main() {
  test('milestones are sorted ascending', () {
    for (var i = 1; i < healthMilestones.length; i++) {
      expect(
        healthMilestones[i].after,
        greaterThan(healthMilestones[i - 1].after),
      );
    }
  });

  test('next milestone', () {
    expect(nextMilestone(Duration.zero)!.title, '20 минут');
    expect(nextMilestone(const Duration(hours: 25))!.title, '48 часов');
    expect(nextMilestone(const Duration(days: 400)), isNull);
  });

  test('milestone progress', () {
    expect(milestoneProgress(const Duration(minutes: 10)), 0.5);
    expect(milestoneProgress(Duration.zero), 0);
    expect(milestoneProgress(const Duration(days: 400)), 1);
  });
}
