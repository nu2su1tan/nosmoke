import 'package:flutter/foundation.dart';

import '../../../core/storage/json_list_store.dart';
import '../domain/savings_goal.dart';

class GoalController extends ChangeNotifier {
  GoalController(this._store);

  final JsonListStore<SavingsGoal> _store;
  SavingsGoal? _goal;

  SavingsGoal? get goal => _goal;

  Future<void> load() async {
    final list = await _store.load();
    _goal = list.isEmpty ? null : list.first;
    notifyListeners();
  }

  Future<void> set(SavingsGoal g) async {
    _goal = g;
    notifyListeners();
    await _store.save([g]);
  }

  Future<void> clear() async {
    _goal = null;
    notifyListeners();
    await _store.clear();
  }
}
