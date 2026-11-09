import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/features/diary/data/diary_store.dart';
import 'package:nosmoke/features/diary/domain/craving_entry.dart';
import 'package:nosmoke/features/diary/domain/diary_insights.dart';
import 'package:nosmoke/features/diary/presentation/diary_controller.dart';
import 'package:nosmoke/features/profile/domain/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

CravingEntry _e(String id, int hour, Trigger? t) =>
    CravingEntry(id: id, at: DateTime(2026, 1, 1, hour), trigger: t);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('insights', () {
    test('too few entries -> no insights', () {
      final i = computeInsights([_e('1', 9, Trigger.coffee)]);
      expect(i.topTrigger, isNull);
      expect(i.peakHour, isNull);
    });

    test('top trigger and peak hour', () {
      final i = computeInsights([
        _e('1', 9, Trigger.coffee),
        _e('2', 9, Trigger.coffee),
        _e('3', 15, Trigger.stress),
      ]);
      expect(i.topTrigger, Trigger.coffee);
      expect(i.peakHour, 9);
      expect(i.total, 3);
    });

    test('entries without trigger still give a peak hour', () {
      final i = computeInsights([
        _e('1', 8, null),
        _e('2', 8, null),
        _e('3', 8, null),
      ]);
      expect(i.topTrigger, isNull);
      expect(i.peakHour, 8);
    });
  });

  group('controller', () {
    test('add persists and reloads, newest first', () async {
      final c = DiaryController(diaryStore());
      await c.add(_e('old', 8, Trigger.coffee));
      await c.add(_e('new', 18, Trigger.stress));
      expect(c.entries.map((e) => e.id), ['new', 'old']);

      final c2 = DiaryController(diaryStore());
      await c2.load();
      expect(c2.entries.map((e) => e.id), ['new', 'old']);
      expect(c2.entries.first.trigger, Trigger.stress);
    });

    test('remove and clear', () async {
      final c = DiaryController(diaryStore());
      await c.add(_e('a', 8, null));
      await c.add(_e('b', 9, null));
      await c.remove('a');
      expect(c.entries.map((e) => e.id), ['b']);
      await c.clear();
      expect(c.entries, isEmpty);
    });

    test('corrupted storage does not crash', () async {
      SharedPreferences.setMockInitialValues({'diary_v1': 'not json'});
      final c = DiaryController(diaryStore());
      await c.load();
      expect(c.entries, isEmpty);
    });
  });
}
