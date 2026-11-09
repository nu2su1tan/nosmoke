/// Простая автоматическая модерация текста. Это не замена живой модерации:
/// жалобы пользователей скрывают пост автоматически, а решение по ним
/// принимает человек.
class ModerationResult {
  const ModerationResult.ok() : error = null;
  const ModerationResult.rejected(this.error);

  final String? error;
  bool get isOk => error == null;
}

const maxPostLength = 500;
const maxCommentLength = 300;
const maxCheerLength = 140;

final _url = RegExp(
  r'(https?://|www\.|\.(com|ru|kz|net|org)\b)',
  caseSensitive: false,
);
final _blocked = RegExp(
  r'(хуй|хуе|пизд|ебан|ебат|бляд|блять|сука|мудак|гандон)',
  caseSensitive: false,
);

ModerationResult moderate(String? text, {int maxLength = maxPostLength}) {
  final t = (text ?? '').trim();
  if (t.isEmpty) return const ModerationResult.rejected('empty');
  if (t.length > maxLength) return const ModerationResult.rejected('too_long');
  if (_url.hasMatch(t)) {
    return const ModerationResult.rejected('links_not_allowed');
  }
  if (_blocked.hasMatch(t)) {
    return const ModerationResult.rejected('inappropriate');
  }
  return const ModerationResult.ok();
}

/// Пост скрывается автоматически после стольких жалоб.
const reportsToHide = 3;
