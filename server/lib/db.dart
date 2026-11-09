import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Всё состояние сервера. Хранится в памяти и (если задан путь) сохраняется
/// в JSON-файл после каждого изменения. Для продакшена с большой нагрузкой
/// замени на настоящую БД: интерфейс остальных модулей не изменится.
class Db {
  Db({this.path});

  final String? path;

  final Map<String, Map<String, dynamic>> users = {};
  final List<Map<String, dynamic>> posts = [];
  final Map<String, List<Map<String, dynamic>>> comments = {};
  final Map<String, Map<String, dynamic>> invites = {};
  final List<Map<String, dynamic>> links = [];
  final Map<String, Map<String, dynamic>> progress = {};
  final List<Map<String, dynamic>> messages = [];

  /// Журнал действий для ограничения частоты: ключ -> метки времени (мс).
  final Map<String, List<int>> actions = {};

  static Db load(String? path) {
    final db = Db(path: path);
    if (path == null) return db;
    final file = File(path);
    if (!file.existsSync()) return db;
    try {
      final j = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      Map<String, Map<String, dynamic>> m(String k) => {
        for (final e in (j[k] as Map? ?? {}).entries)
          e.key as String: Map<String, dynamic>.from(e.value as Map),
      };
      List<Map<String, dynamic>> l(String k) => [
        for (final e in (j[k] as List? ?? []))
          Map<String, dynamic>.from(e as Map),
      ];
      db.users.addAll(m('users'));
      db.posts.addAll(l('posts'));
      for (final e in (j['comments'] as Map? ?? {}).entries) {
        db.comments[e.key as String] = [
          for (final c in e.value as List) Map<String, dynamic>.from(c as Map),
        ];
      }
      db.invites.addAll(m('invites'));
      db.links.addAll(l('links'));
      db.progress.addAll(m('progress'));
      db.messages.addAll(l('messages'));
    } catch (_) {
      // Повреждённый файл: стартуем с пустой базой, не теряя сам файл
      // (он будет перезаписан при первом изменении).
    }
    return db;
  }

  void save() {
    final p = path;
    if (p == null) return;
    final tmp = File('$p.tmp');
    tmp.writeAsStringSync(
      jsonEncode({
        'users': users,
        'posts': posts,
        'comments': comments,
        'invites': invites,
        'links': links,
        'progress': progress,
        'messages': messages,
      }),
    );
    tmp.renameSync(p); // атомарная замена, чтобы файл не остался половинным
  }

  /// true, если действие [key] за последний [window] выполнено меньше [limit]
  /// раз; при этом записывает его.
  bool allow(String key, int limit, Duration window, DateTime now) {
    final cutoff = now.subtract(window).millisecondsSinceEpoch;
    final list = actions.putIfAbsent(key, () => []);
    list.removeWhere((t) => t < cutoff);
    if (list.length >= limit) return false;
    list.add(now.millisecondsSinceEpoch);
    return true;
  }
}

const _adjectives = [
  'Тихий',
  'Смелый',
  'Ясный',
  'Добрый',
  'Стойкий',
  'Лёгкий',
  'Бодрый',
  'Мудрый',
];
const _nouns = [
  'кедр',
  'ветер',
  'ручей',
  'маяк',
  'сокол',
  'рассвет',
  'камень',
  'парус',
];

String randomNick(Random r) =>
    '${_adjectives[r.nextInt(_adjectives.length)]} '
    '${_nouns[r.nextInt(_nouns.length)]} ${100 + r.nextInt(900)}';

String randomToken(Random r, [int bytes = 24]) => base64UrlEncode(
  List<int>.generate(bytes, (_) => r.nextInt(256)),
).replaceAll('=', '');

String randomId(Random r) => randomToken(r, 9);

/// Код приглашения без похожих символов (0/O, 1/I).
String randomInviteCode(Random r) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  return List.generate(6, (_) => alphabet[r.nextInt(alphabet.length)]).join();
}
