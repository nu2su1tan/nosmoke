import 'package:flutter/foundation.dart';

import '../../../core/storage/json_list_store.dart';
import '../domain/smoked_entry.dart';

class SmokedController extends ChangeNotifier {
  SmokedController(this._store);

  final JsonListStore<SmokedEntry> _store;
  List<SmokedEntry> _items = [];

  List<SmokedEntry> get items => List.unmodifiable(_items);

  int countOn(DateTime day) => smokedOn(_items, day);

  Future<void> load() async {
    _items = await _store.load()
      ..sort((a, b) => a.at.compareTo(b.at));
    notifyListeners();
  }

  Future<void> add([DateTime? at]) async {
    _items = [..._items, SmokedEntry(at: at ?? DateTime.now())];
    notifyListeners();
    await _store.save(_items);
  }

  /// Отменяет последнюю запись за [day] (случайное нажатие).
  Future<void> undoLastOn(DateTime day) async {
    final idx = _items.lastIndexWhere((e) => smokedOn([e], day) == 1);
    if (idx < 0) return;
    _items = [..._items]..removeAt(idx);
    notifyListeners();
    await _store.save(_items);
  }

  Future<void> clear() async {
    _items = [];
    notifyListeners();
    await _store.clear();
  }
}
