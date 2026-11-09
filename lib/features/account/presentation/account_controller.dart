import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../data/account_store.dart';

/// Адрес сервера по умолчанию (для продакшена):
/// flutter build ... --dart-define=SERVER_URL=https://api.example.com
const defaultServerUrl = String.fromEnvironment('SERVER_URL');

enum ConnectError { invalidUrl, network, server }

/// Подключение к серверу сообщества. Работает анонимно: сервер выдаёт
/// псевдоним и токен, никаких личных данных не нужно.
class AccountController extends ChangeNotifier {
  AccountController(
    this._store, {
    http.Client Function()? clientFactory,
    this.initialUrl = defaultServerUrl,
  }) : _clientFactory = clientFactory ?? http.Client.new;

  final AccountStore _store;
  final http.Client Function() _clientFactory;
  final String initialUrl;

  /// Один HTTP-клиент на всё время жизни: соединения переиспользуются.
  late final http.Client _http = _clientFactory();

  RemoteAccount? _account;
  bool _busy = false;
  ConnectError? _error;

  RemoteAccount? get account => _account;
  bool get connected => _account != null;
  bool get busy => _busy;
  ConnectError? get error => _error;

  /// Клиент для запросов или null, если сервер не подключён.
  ApiClient? get api {
    final a = _account;
    if (a == null) return null;
    return ApiClient(baseUrl: a.baseUrl, token: a.token, client: _http);
  }

  Future<void> load() async {
    _account = await _store.load();
    notifyListeners();
    if (_account == null && initialUrl.isNotEmpty) await connect(initialUrl);
  }

  /// Подключается к серверу [url]. Если уже есть учётка на этом адресе, она
  /// сохраняется. Возвращает true при успехе.
  Future<bool> connect(String url) async {
    final base = normalizeServerUrl(url);
    if (base == null) {
      _error = ConnectError.invalidUrl;
      notifyListeners();
      return false;
    }
    if (_account?.baseUrl == base) return true;
    _busy = true;
    _error = null;
    notifyListeners();
    final client = ApiClient(baseUrl: base, client: _http);
    try {
      final j = await client.post('/register');
      _account = RemoteAccount(
        baseUrl: base,
        userId: j['userId'] as String,
        token: j['token'] as String,
        nick: j['nick'] as String,
      );
      await _store.save(_account!);
      return true;
    } on ApiException catch (e) {
      _error = e.isNetwork ? ConnectError.network : ConnectError.server;
      return false;
    } catch (_) {
      _error = ConnectError.server;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Удаляет данные пользователя на сервере (если получится) и локальную
  /// учётку. Сбой сети не мешает локальному сбросу.
  Future<void> deleteRemote() async {
    final client = api;
    if (client != null) {
      try {
        await client.delete('/account');
      } on ApiException {
        // сервер недоступен: локальные данные всё равно очищаем
      }
    }
    await disconnect();
  }

  @override
  void dispose() {
    _http.close();
    super.dispose();
  }

  Future<void> disconnect() async {
    _account = null;
    _error = null;
    notifyListeners();
    await _store.clear();
  }
}
