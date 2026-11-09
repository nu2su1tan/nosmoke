import '../../../core/storage/json_list_store.dart';
import '../domain/craving_entry.dart';

JsonListStore<CravingEntry> diaryStore() => JsonListStore<CravingEntry>(
  key: 'diary_v1',
  fromJson: CravingEntry.fromJson,
  toJson: (e) => e.toJson(),
);
