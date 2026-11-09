import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/features/plan/domain/maintenance.dart';
import 'package:nosmoke/features/profile/domain/profile.dart';
import 'package:nosmoke/features/progress/domain/progress.dart';
import 'package:nosmoke/features/relapse/domain/relapse.dart';

import '../../helpers/fakes.dart';

void main() {
  final p = makeProfile(quitDate: DateTime(2026, 1, 1));

  test('switches on after 90 smoke-free days', () {
    expect(
      isMaintenance(computeProgress(p, [], DateTime(2026, 3, 31, 23))),
      isFalse,
    ); // 89 д
    expect(
      isMaintenance(computeProgress(p, [], DateTime(2026, 4, 1))),
      isTrue,
    ); // ровно 90
    expect(isMaintenance(computeProgress(p, [], DateTime(2027, 1, 1))), isTrue);
  });

  test('a relapse sends the user back to the regular mode', () {
    final r = [Relapse(at: DateTime(2026, 4, 10))];
    expect(
      isMaintenance(computeProgress(p, r, DateTime(2026, 4, 12))),
      isFalse,
    );
  });

  test('never active during the gradual ramp or before the start', () {
    final g = makeProfile(
      mode: QuitMode.gradual,
      quitDate: DateTime(2026, 1, 1),
    );
    expect(
      isMaintenance(computeProgress(g, [], DateTime(2026, 1, 20))),
      isFalse,
    );
    expect(
      isMaintenance(computeProgress(p, [], DateTime(2025, 12, 1))),
      isFalse,
    );
  });

  test('tips are not empty', () {
    expect(maintenanceTips, isNotEmpty);
    for (final t in maintenanceTips) {
      expect(t.title, isNotEmpty);
      expect(t.body, isNotEmpty);
    }
  });
}
