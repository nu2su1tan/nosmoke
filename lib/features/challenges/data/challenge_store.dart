import '../../../core/storage/json_list_store.dart';
import '../domain/challenge.dart';

JsonListStore<JoinedChallenge> challengeStore() =>
    JsonListStore<JoinedChallenge>(
      key: 'challenges_v1',
      fromJson: JoinedChallenge.fromJson,
      toJson: (c) => c.toJson(),
    );
