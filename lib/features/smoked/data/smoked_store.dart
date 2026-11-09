import '../../../core/storage/json_list_store.dart';
import '../domain/smoked_entry.dart';

JsonListStore<SmokedEntry> smokedStore() => JsonListStore<SmokedEntry>(
  key: 'smoked_v1',
  fromJson: SmokedEntry.fromJson,
  toJson: (e) => e.toJson(),
);
