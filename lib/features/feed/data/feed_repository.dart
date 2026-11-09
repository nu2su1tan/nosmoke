import '../../../core/network/api_client.dart';
import '../domain/feed_models.dart';

abstract class FeedRepository {
  Future<List<FeedPost>> posts();
  Future<FeedPost> create(String text);
  Future<({int likes, bool liked})> toggleLike(String postId);
  Future<void> report(String postId);
  Future<void> delete(String postId);
  Future<List<FeedComment>> comments(String postId);
  Future<FeedComment> addComment(String postId, String text);
}

class RemoteFeedRepository implements FeedRepository {
  RemoteFeedRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<FeedPost>> posts() async {
    final j = await _api.get('/posts', query: {'limit': '50'});
    return [
      for (final p in j['posts'] as List)
        FeedPost.fromJson(p as Map<String, dynamic>),
    ];
  }

  @override
  Future<FeedPost> create(String text) async =>
      FeedPost.fromJson(await _api.post('/posts', {'text': text}));

  @override
  Future<({int likes, bool liked})> toggleLike(String postId) async {
    final j = await _api.post('/posts/$postId/like');
    return (likes: j['likes'] as int, liked: j['liked'] as bool);
  }

  @override
  Future<void> report(String postId) async {
    await _api.post('/posts/$postId/report');
  }

  @override
  Future<void> delete(String postId) async {
    await _api.delete('/posts/$postId');
  }

  @override
  Future<List<FeedComment>> comments(String postId) async {
    final j = await _api.get('/posts/$postId/comments');
    return [
      for (final c in j['comments'] as List)
        FeedComment.fromJson(c as Map<String, dynamic>),
    ];
  }

  @override
  Future<FeedComment> addComment(String postId, String text) async =>
      FeedComment.fromJson(
        await _api.post('/posts/$postId/comments', {'text': text}),
      );
}
