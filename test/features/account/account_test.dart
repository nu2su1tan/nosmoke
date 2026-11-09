import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/features/account/data/account_store.dart';
import 'package:nosmoke/features/account/presentation/account_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/in_process_server.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late InProcessServer server;
  AccountController make({String initialUrl = ''}) => AccountController(
    AccountStore(),
    clientFactory: server.clientFactory,
    initialUrl: initialUrl,
  );

  setUp(() => server = InProcessServer());

  test('connect registers an anonymous account and persists it', () async {
    final a = make();
    expect(a.connected, isFalse);
    expect(await a.connect(InProcessServer.baseUrl), isTrue);
    expect(a.connected, isTrue);
    expect(a.account!.nick, isNotEmpty);
    expect(server.db.users, hasLength(1));

    final b = make();
    await b.load();
    expect(b.account!.userId, a.account!.userId);
    expect(b.api, isNotNull);
  });

  test('connecting to the same server again does not register twice', () async {
    final a = make();
    await a.connect(InProcessServer.baseUrl);
    await a.connect('${InProcessServer.baseUrl}/');
    expect(server.requests.where((r) => r == 'POST /register'), hasLength(1));
  });

  test('invalid address', () async {
    final a = make();
    expect(await a.connect('ftp://x'), isFalse);
    expect(a.error, ConnectError.invalidUrl);
    expect(server.requests, isEmpty);
  });

  test('server unreachable', () async {
    final a = AccountController(AccountStore(), clientFactory: offlineClient);
    expect(await a.connect('https://nowhere.test'), isFalse);
    expect(a.error, ConnectError.network);
    expect(a.connected, isFalse);
    expect(a.busy, isFalse);
  });

  test('default server url connects automatically on load', () async {
    final a = make(initialUrl: InProcessServer.baseUrl);
    await a.load();
    expect(a.connected, isTrue);
  });

  test('deleteRemote erases the server data and the local account', () async {
    final a = make();
    await a.connect(InProcessServer.baseUrl);
    await a.api!.post('/posts', {'text': 'временный пост'});
    expect(server.db.posts, hasLength(1));

    await a.deleteRemote();
    expect(a.connected, isFalse);
    expect(server.db.users, isEmpty);
    expect(server.db.posts, isEmpty);
    expect(await AccountStore().load(), isNull);
  });

  test('deleteRemote works even when the server is down', () async {
    final a = AccountController(
      AccountStore(),
      clientFactory: server.clientFactory,
    );
    await a.connect(InProcessServer.baseUrl);
    final offline = AccountController(
      AccountStore(),
      clientFactory: offlineClient,
    );
    await offline.load();
    await offline.deleteRemote();
    expect(offline.connected, isFalse);
    expect(await AccountStore().load(), isNull);
  });

  test('corrupted stored account is ignored', () async {
    SharedPreferences.setMockInitialValues({'account_v1': 'not json'});
    final a = make();
    await a.load();
    expect(a.connected, isFalse);
  });
}
