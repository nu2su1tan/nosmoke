import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/features/relapse/data/relapse_store.dart';
import 'package:nosmoke/features/relapse/domain/relapse.dart';
import 'package:nosmoke/features/relapse/presentation/relapse_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('add keeps items sorted and persists', () async {
    final c = RelapseController(relapseStore());
    await c.add(Relapse(at: DateTime(2026, 2, 1), count: 2, note: 'стресс'));
    await c.add(Relapse(at: DateTime(2026, 1, 1)));
    expect(c.items.first.at, DateTime(2026, 1, 1));

    final c2 = RelapseController(relapseStore());
    await c2.load();
    expect(c2.items, hasLength(2));
    expect(c2.items.last.count, 2);
    expect(c2.items.last.note, 'стресс');
  });

  test('clear', () async {
    final c = RelapseController(relapseStore());
    await c.add(Relapse(at: DateTime(2026, 1, 1)));
    await c.clear();
    expect(c.items, isEmpty);
  });
}
