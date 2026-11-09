import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/core/network/api_client.dart';
import 'package:nosmoke/features/account/data/account_store.dart';
import 'package:nosmoke/features/account/presentation/account_controller.dart';
import 'package:nosmoke/features/feed/data/feed_repository.dart';
import 'package:nosmoke/features/feed/domain/feed_models.dart';
import 'package:nosmoke/features/feed/presentation/feed_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/in_process_server.dart';

void main() {
  late InProcessServer server;
  late AccountController account;
  late FeedController feed;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    server = InProcessServer();
    account = AccountController(
      AccountStore(),
      clientFactory: server.clientFactory,
    );
    await account.connect(InProcessServer.baseUrl);
    feed = FeedController(() {
      final api = account.api;
      return api == null ? null : RemoteFeedRepository(api);
    });
  });

  test('publish shows the post first and it is mine', () async {
    expect(await feed.publish('Первый день без сигарет'), isNull);
    await feed.publish('Второй день');
    expect(feed.posts.first.text, 'Второй день');
    expect(feed.posts.every((p) => p.mine), isTrue);

    await feed.refresh();
    expect(feed.posts.map((p) => p.text).toSet(), {
      'Первый день без сигарет',
      'Второй день',
    });
  });

  test('moderation errors come back as readable codes', () async {
    expect(await feed.publish('  '), 'empty');
    expect(
      await feed.publish('смотри http://spam.example'),
      'links_not_allowed',
    );
    expect(feedErrorText('links_not_allowed'), contains('Ссылки'));
    expect(feedErrorText('rate_limited'), contains('Слишком часто'));
    expect(feedErrorText('network'), contains('Нет связи'));
    expect(feedErrorText('whatever'), contains('Что-то пошло не так'));
  });

  test('like is optimistic and matches the server', () async {
    await feed.publish('Пост');
    final id = feed.posts.single.id;
    final future = feed.toggleLike(id);
    expect(feed.posts.single.liked, isTrue); // мгновенно, до ответа
    expect(feed.posts.single.likes, 1);
    await future;
    expect(feed.posts.single.likes, 1);
    await feed.toggleLike(id);
    expect(feed.posts.single.liked, isFalse);
    expect(feed.posts.single.likes, 0);
  });

  test('a failed like is rolled back', () async {
    await feed.publish('Пост');
    final id = feed.posts.single.id;
    final broken = FeedController(
      () => _FailingRepo(RemoteFeedRepository(account.api!)),
    );
    await broken.refresh();
    final before = broken.posts.single;
    await broken.toggleLike(id);
    expect(broken.posts.single.liked, before.liked);
    expect(broken.posts.single.likes, before.likes);
  });

  test('report hides the post locally and counts on the server', () async {
    final other = await server.registerUser();
    await server.as(other.token, 'POST', '/posts', '{"text":"спорный пост"}');
    await feed.refresh();
    final id = feed.posts.single.id;
    expect(feed.posts.single.mine, isFalse);

    await feed.report(id);
    expect(feed.posts, isEmpty);
    expect(feed.isReported(id), isTrue);
    expect(
      (server.db.posts.single['reports'] as List),
      contains(account.account!.userId),
    );
  });

  test('remove deletes my post', () async {
    await feed.publish('удалить');
    await feed.remove(feed.posts.single.id);
    expect(feed.posts, isEmpty);
    expect(server.db.posts, isEmpty);
  });

  test('comments are added and counted', () async {
    await feed.publish('Пост');
    final id = feed.posts.single.id;
    expect(await feed.addComment(id, 'Держись!'), isNull);
    expect(await feed.addComment(id, 'http://x.com'), 'links_not_allowed');
    expect(feed.posts.single.comments, 1);
    final list = await feed.comments(id);
    expect(list.single.text, 'Держись!');
    expect(list.single.mine, isTrue);
  });

  test('without a server everything is a safe no-op', () async {
    final none = FeedController(() => null);
    expect(none.available, isFalse);
    await none.refresh();
    expect(none.posts, isEmpty);
    expect(await none.publish('x'), 'network');
    expect(await none.addComment('1', 'x'), 'network');
    expect(await none.comments('1'), isEmpty);
    await none.toggleLike('1');
    await none.report('1');
    await none.remove('1');
  });

  test('network failure during refresh is reported, not thrown', () async {
    final offline = AccountController(
      AccountStore(),
      clientFactory: () => throw StateError('unused'),
    );
    expect(offline.api, isNull);
    final f = FeedController(() => _AlwaysFails());
    await f.refresh();
    expect(f.error, 'network');
    expect(f.loading, isFalse);
  });
}

class _FailingRepo implements FeedRepository {
  _FailingRepo(this._real);

  final FeedRepository _real;

  @override
  Future<List<FeedPost>> posts() => _real.posts();

  @override
  Future<({int likes, bool liked})> toggleLike(String postId) async =>
      throw const ApiException(0, 'network');

  @override
  Future<FeedPost> create(String text) => _real.create(text);

  @override
  Future<void> report(String postId) => _real.report(postId);

  @override
  Future<void> delete(String postId) => _real.delete(postId);

  @override
  Future<List<FeedComment>> comments(String postId) => _real.comments(postId);

  @override
  Future<FeedComment> addComment(String postId, String text) =>
      _real.addComment(postId, text);
}

class _AlwaysFails extends _FailingRepo {
  _AlwaysFails() : super(_Never());

  @override
  Future<List<FeedPost>> posts() async =>
      throw const ApiException(0, 'network');
}

class _Never implements FeedRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
