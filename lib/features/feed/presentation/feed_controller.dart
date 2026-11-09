import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../data/feed_repository.dart';
import '../domain/feed_models.dart';

/// Состояние ленты. [repoFactory] возвращает null, если сервер не подключён.
class FeedController extends ChangeNotifier {
  FeedController(this._repoFactory);

  final FeedRepository? Function() _repoFactory;

  List<FeedPost> _posts = [];
  bool _loading = false;
  String? _error;
  final Set<String> _reported = {};

  List<FeedPost> get posts => List.unmodifiable(_posts);
  bool get loading => _loading;

  /// Код последней ошибки (для feedErrorText) или null.
  String? get error => _error;
  bool get available => _repoFactory() != null;

  Future<void> refresh() async {
    final repo = _repoFactory();
    if (repo == null) {
      _posts = [];
      notifyListeners();
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _posts = await repo.posts();
    } on ApiException catch (e) {
      _error = e.code;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Публикует пост. Возвращает код ошибки или null при успехе.
  Future<String?> publish(String text) async {
    final repo = _repoFactory();
    if (repo == null) return 'network';
    try {
      final post = await repo.create(text);
      _posts = [post, ..._posts];
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.code;
    }
  }

  /// Лайк с мгновенным откликом; при ошибке состояние возвращается.
  Future<void> toggleLike(String id) async {
    final repo = _repoFactory();
    final i = _posts.indexWhere((p) => p.id == id);
    if (repo == null || i < 0) return;
    final before = _posts[i];
    _posts = [..._posts]
      ..[i] = before.copyWith(
        liked: !before.liked,
        likes: before.likes + (before.liked ? -1 : 1),
      );
    notifyListeners();
    try {
      final r = await repo.toggleLike(id);
      final j = _posts.indexWhere((p) => p.id == id);
      if (j >= 0) {
        _posts = [..._posts]
          ..[j] = _posts[j].copyWith(likes: r.likes, liked: r.liked);
        notifyListeners();
      }
    } on ApiException {
      final j = _posts.indexWhere((p) => p.id == id);
      if (j >= 0) {
        _posts = [..._posts]..[j] = before;
        notifyListeners();
      }
    }
  }

  bool isReported(String id) => _reported.contains(id);

  /// Пожаловаться: пост сразу скрывается у автора жалобы.
  Future<void> report(String id) async {
    final repo = _repoFactory();
    if (repo == null) return;
    _reported.add(id);
    _posts = _posts.where((p) => p.id != id).toList();
    notifyListeners();
    try {
      await repo.report(id);
    } on ApiException {
      // жалоба не дошла: пост остаётся скрытым локально до обновления ленты
    }
  }

  Future<void> remove(String id) async {
    final repo = _repoFactory();
    if (repo == null) return;
    final before = _posts;
    _posts = _posts.where((p) => p.id != id).toList();
    notifyListeners();
    try {
      await repo.delete(id);
    } on ApiException {
      _posts = before;
      notifyListeners();
    }
  }

  Future<List<FeedComment>> comments(String id) async {
    final repo = _repoFactory();
    if (repo == null) return [];
    try {
      return await repo.comments(id);
    } on ApiException {
      return [];
    }
  }

  /// Возвращает код ошибки или null.
  Future<String?> addComment(String id, String text) async {
    final repo = _repoFactory();
    if (repo == null) return 'network';
    try {
      await repo.addComment(id, text);
      final i = _posts.indexWhere((p) => p.id == id);
      if (i >= 0) {
        _posts = [..._posts]
          ..[i] = _posts[i].copyWith(comments: _posts[i].comments + 1);
        notifyListeners();
      }
      return null;
    } on ApiException catch (e) {
      return e.code;
    }
  }
}
