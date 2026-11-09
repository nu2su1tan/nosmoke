import 'package:flutter/foundation.dart';

import '../../../core/storage/json_list_store.dart';
import '../domain/craving_entry.dart';
import '../domain/diary_insights.dart';

class DiaryController extends ChangeNotifier {
  DiaryController(this._store);

  final JsonListStore<CravingEntry> _store;
  List<CravingEntry> _entries = [];

  /// Новые записи сверху.
  List<CravingEntry> get entries => List.unmodifiable(_entries);
  DiaryInsights get insights => computeInsights(_entries);

  Future<void> load() async {
    _entries = await _store.load()
      ..sort((a, b) => b.at.compareTo(a.at));
    notifyListeners();
  }

  Future<void> add(CravingEntry e) async {
    _entries = [e, ..._entries]..sort((a, b) => b.at.compareTo(a.at));
    notifyListeners();
    await _store.save(_entries);
  }

  Future<void> remove(String id) async {
    _entries = _entries.where((e) => e.id != id).toList();
    notifyListeners();
    await _store.save(_entries);
  }

  Future<void> clear() async {
    _entries = [];
    notifyListeners();
    await _store.clear();
  }
}
