import 'package:flutter/foundation.dart';

import '../../../core/storage/json_list_store.dart';
import '../../diary/presentation/diary_controller.dart';
import '../../relapse/presentation/relapse_controller.dart';
import '../domain/challenge.dart';

class ChallengeController extends ChangeNotifier {
  ChallengeController(this._store, this._diary, this._relapses) {
    _diary.addListener(evaluate);
    _relapses.addListener(evaluate);
  }

  final JsonListStore<JoinedChallenge> _store;
  final DiaryController _diary;
  final RelapseController _relapses;
  List<JoinedChallenge> _joined = [];

  List<JoinedChallenge> get joined => List.unmodifiable(_joined);

  JoinedChallenge? joinedFor(String id) {
    for (final j in _joined) {
      if (j.id == id) return j;
    }
    return null;
  }

  int progressOf(ChallengeDef def, [DateTime? now]) {
    final j = joinedFor(def.id);
    if (j == null) return 0;
    if (j.completedAt != null) return def.goal;
    return challengeProgress(
      def,
      j.joinedAt,
      _relapses.items,
      _diary.entries,
      now ?? DateTime.now(),
    );
  }

  Future<void> load() async {
    _joined = await _store.load();
    notifyListeners();
    await evaluate();
  }

  /// Вступить (или начать заново, если челлендж уже был).
  Future<void> join(String id, [DateTime? now]) async {
    _joined = [
      ..._joined.where((j) => j.id != id),
      JoinedChallenge(id: id, joinedAt: now ?? DateTime.now()),
    ];
    notifyListeners();
    await _store.save(_joined);
  }

  Future<void> leave(String id) async {
    _joined = _joined.where((j) => j.id != id).toList();
    notifyListeners();
    await _store.save(_joined);
  }

  /// Отмечает достигнутые цели. Выполненный челлендж остаётся выполненным,
  /// даже если потом случится срыв.
  Future<void> evaluate([DateTime? now]) async {
    final t = now ?? DateTime.now();
    var changed = false;
    _joined = [
      for (final j in _joined)
        if (j.completedAt == null && _isDone(j, t))
          () {
            changed = true;
            return j.copyWith(completedAt: t);
          }()
        else
          j,
    ];
    if (!changed) return;
    notifyListeners();
    await _store.save(_joined);
  }

  bool _isDone(JoinedChallenge j, DateTime now) {
    final def = challengeById(j.id);
    if (def == null) return false;
    return challengeProgress(
          def,
          j.joinedAt,
          _relapses.items,
          _diary.entries,
          now,
        ) >=
        def.goal;
  }

  Future<void> clear() async {
    _joined = [];
    notifyListeners();
    await _store.clear();
  }

  @override
  void dispose() {
    _diary.removeListener(evaluate);
    _relapses.removeListener(evaluate);
    super.dispose();
  }
}
