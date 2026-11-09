import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../domain/supporters_models.dart';

abstract class SupportersRepository {
  Future<String> createInvite();
  Future<String> acceptInvite(String code); // возвращает псевдоним владельца
  Future<void> pushProgress(ProgressSummary s);
  Future<void> sos();
  Future<List<SupportedOwner>> supporting();
  Future<List<SupporterInfo>> supporters();
  Future<void> cheer(String ownerId, String text);
  Future<List<CheerMessage>> messages({String? since});
  Future<void> unlink(String otherId);
}

class RemoteSupportersRepository implements SupportersRepository {
  RemoteSupportersRepository(this._api);

  final ApiClient _api;

  @override
  Future<String> createInvite() async =>
      (await _api.post('/invites'))['code'] as String;

  @override
  Future<String> acceptInvite(String code) async =>
      (await _api.post('/invites/accept', {'code': code}))['ownerNick']
          as String;

  @override
  Future<void> pushProgress(ProgressSummary s) async {
    await _api.put('/progress', s.toJson());
  }

  @override
  Future<void> sos() async {
    await _api.post('/sos');
  }

  @override
  Future<List<SupportedOwner>> supporting() async => [
    for (final o in (await _api.get('/supporting'))['owners'] as List)
      SupportedOwner.fromJson(o as Map<String, dynamic>),
  ];

  @override
  Future<List<SupporterInfo>> supporters() async => [
    for (final s in (await _api.get('/supporters'))['supporters'] as List)
      SupporterInfo.fromJson(s as Map<String, dynamic>),
  ];

  @override
  Future<void> cheer(String ownerId, String text) async {
    await _api.post('/cheers', {'ownerId': ownerId, 'text': text});
  }

  @override
  Future<List<CheerMessage>> messages({String? since}) async => [
    for (final m
        in (await _api.get(
              '/messages',
              query: since == null ? null : {'since': since},
            ))['messages']
            as List)
      CheerMessage.fromJson(m as Map<String, dynamic>),
  ];

  @override
  Future<void> unlink(String otherId) async {
    await _api.delete('/links/$otherId');
  }
}

/// Запоминает, какие сообщения поддержки уже показаны.
class SeenMarker {
  const SeenMarker();

  static const _key = 'messages_seen_v1';

  Future<String?> load() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  Future<void> save(String iso) async =>
      (await SharedPreferences.getInstance()).setString(_key, iso);

  Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(_key);
}
