import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/features/challenges/data/challenge_store.dart';
import 'package:nosmoke/features/challenges/domain/challenge.dart';
import 'package:nosmoke/features/challenges/presentation/challenge_controller.dart';
import 'package:nosmoke/features/diary/data/diary_store.dart';
import 'package:nosmoke/features/diary/domain/craving_entry.dart';
import 'package:nosmoke/features/diary/presentation/diary_controller.dart';
import 'package:nosmoke/features/relapse/data/relapse_store.dart';
import 'package:nosmoke/features/relapse/domain/relapse.dart';
import 'package:nosmoke/features/relapse/presentation/relapse_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

CravingEntry _e(String id, DateTime at, {bool overcame = true}) =>
    CravingEntry(id: id, at: at, overcame: overcame);

void main() {
  final week = challengeById('week')!;
  final cravings = challengeById('cravings_10')!;
  final joined = DateTime(2026, 1, 1);

  group('challengeProgress', () {
    test('days without relapse count from joining', () {
      expect(challengeProgress(week, joined, [], [], DateTime(2026, 1, 4)), 3);
    });

    test('a relapse restarts the streak', () {
      final r = [Relapse(at: DateTime(2026, 1, 3))];
      expect(challengeProgress(week, joined, r, [], DateTime(2026, 1, 5)), 2);
    });

    test('relapse before joining is ignored', () {
      final r = [Relapse(at: DateTime(2025, 12, 20))];
      expect(challengeProgress(week, joined, r, [], DateTime(2026, 1, 3)), 2);
    });

    test('progress is capped at the goal', () {
      expect(challengeProgress(week, joined, [], [], DateTime(2026, 3, 1)), 7);
    });

    test('cravings: only overcome entries after joining', () {
      final d = [
        _e('a', DateTime(2025, 12, 31)),
        _e('b', DateTime(2026, 1, 2)),
        _e('c', DateTime(2026, 1, 2), overcame: false),
        _e('d', DateTime(2026, 1, 3)),
      ];
      expect(
        challengeProgress(cravings, joined, [], d, DateTime(2026, 1, 5)),
        2,
      );
    });
  });

  group('controller', () {
    late DiaryController diary;
    late RelapseController relapses;
    late ChallengeController c;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      diary = DiaryController(diaryStore());
      relapses = RelapseController(relapseStore());
      c = ChallengeController(challengeStore(), diary, relapses);
      await c.load();
    });

    test('join, persist, leave', () async {
      await c.join('week', joined);
      expect(c.joinedFor('week')!.joinedAt, joined);

      final c2 = ChallengeController(challengeStore(), diary, relapses);
      await c2.load();
      expect(c2.joinedFor('week'), isNotNull);

      await c.leave('week');
      expect(c.joinedFor('week'), isNull);
    });

    test('completion is remembered even after a later relapse', () async {
      await c.join('week', joined);
      await c.evaluate(DateTime(2026, 1, 9));
      expect(c.joinedFor('week')!.completedAt, isNotNull);

      await relapses.add(Relapse(at: DateTime(2026, 1, 10)));
      await c.evaluate(DateTime(2026, 1, 11));
      expect(c.joinedFor('week')!.completedAt, isNotNull);
      expect(c.progressOf(week, DateTime(2026, 1, 11)), 7);
    });

    test('not completed before the goal', () async {
      await c.join('week', joined);
      await c.evaluate(DateTime(2026, 1, 5));
      expect(c.joinedFor('week')!.completedAt, isNull);
      expect(c.progressOf(week, DateTime(2026, 1, 5)), 4);
    });

    test('rejoining restarts a completed challenge', () async {
      await c.join('week', joined);
      await c.evaluate(DateTime(2026, 1, 9));
      await c.join('week', DateTime(2026, 2, 1));
      expect(c.joinedFor('week')!.completedAt, isNull);
      expect(c.joinedFor('week')!.joinedAt, DateTime(2026, 2, 1));
    });

    test('progress of a challenge the user has not joined is 0', () {
      expect(c.progressOf(week), 0);
    });

    test('ids of the definitions are unique', () {
      expect(
        challengeDefs.map((d) => d.id).toSet(),
        hasLength(challengeDefs.length),
      );
    });
  });
}
