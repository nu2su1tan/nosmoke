import '../../../core/storage/json_list_store.dart';
import '../domain/relapse.dart';

JsonListStore<Relapse> relapseStore() => JsonListStore<Relapse>(
  key: 'relapses_v1',
  fromJson: Relapse.fromJson,
  toJson: (r) => r.toJson(),
);
