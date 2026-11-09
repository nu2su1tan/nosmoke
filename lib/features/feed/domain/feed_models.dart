class FeedPost {
  const FeedPost({
    required this.id,
    required this.nick,
    required this.text,
    required this.at,
    required this.likes,
    required this.liked,
    required this.comments,
    required this.mine,
  });

  final String id;
  final String nick;
  final String text;
  final DateTime at;
  final int likes;
  final bool liked;
  final int comments;
  final bool mine;

  FeedPost copyWith({int? likes, bool? liked, int? comments}) => FeedPost(
    id: id,
    nick: nick,
    text: text,
    at: at,
    likes: likes ?? this.likes,
    liked: liked ?? this.liked,
    comments: comments ?? this.comments,
    mine: mine,
  );

  factory FeedPost.fromJson(Map<String, dynamic> j) => FeedPost(
    id: j['id'] as String,
    nick: j['nick'] as String,
    text: j['text'] as String,
    at: DateTime.parse(j['at'] as String).toLocal(),
    likes: j['likes'] as int,
    liked: j['liked'] as bool,
    comments: j['comments'] as int,
    mine: j['mine'] as bool,
  );
}

class FeedComment {
  const FeedComment({
    required this.id,
    required this.nick,
    required this.text,
    required this.at,
    required this.mine,
  });

  final String id;
  final String nick;
  final String text;
  final DateTime at;
  final bool mine;

  factory FeedComment.fromJson(Map<String, dynamic> j) => FeedComment(
    id: j['id'] as String,
    nick: j['nick'] as String,
    text: j['text'] as String,
    at: DateTime.parse(j['at'] as String).toLocal(),
    mine: j['mine'] as bool,
  );
}

/// Понятный пользователю текст по коду ошибки сервера.
String feedErrorText(String code) => switch (code) {
  'empty' => 'Напиши хотя бы пару слов.',
  'too_long' => 'Слишком длинно, сократи текст.',
  'links_not_allowed' => 'Ссылки в сообщениях запрещены.',
  'inappropriate' => 'Сообщение нарушает правила сообщества.',
  'rate_limited' => 'Слишком часто. Подожди немного.',
  'network' || 'timeout' => 'Нет связи с сервером.',
  _ => 'Что-то пошло не так. Попробуй ещё раз.',
};
