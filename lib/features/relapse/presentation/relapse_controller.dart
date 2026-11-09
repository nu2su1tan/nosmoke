import 'package:flutter/foundation.dart';

import '../../../core/storage/json_list_store.dart';
import '../domain/relapse.dart';

class RelapseController extends ChangeNotifier {
  RelapseController(this._store);

  final JsonListStore<Relapse> _store;
  List<Relapse> _items = [];

  List<Relapse> get items => List.unmodifiable(_items);

  Future<void> load() async {
    _items = await _store.load();
    notifyListeners();
  }

  Future<void> add(Relapse r) async {
    _items = [..._items, r]..sort((a, b) => a.at.compareTo(b.at));
    notifyListeners();
    await _store.save(_items);
  }

  Future<void> clear() async {
    _items = [];
    notifyListeners();
    await _store.clear();
  }
}
