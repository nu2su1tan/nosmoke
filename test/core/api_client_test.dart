import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nosmoke/core/network/api_client.dart';
import 'package:nosmoke/core/utils/formatters.dart';

void main() {
  group('normalizeServerUrl', () {
    test('accepts and cleans typical input', () {
      expect(
        normalizeServerUrl('https://api.example.com'),
        'https://api.example.com',
      );
      expect(
        normalizeServerUrl('https://api.example.com/'),
        'https://api.example.com',
      );
      expect(
        normalizeServerUrl('  api.example.com  '),
        'https://api.example.com',
      );
      expect(
        normalizeServerUrl('http://192.168.1.5:8080'),
        'http://192.168.1.5:8080',
      );
      expect(
        normalizeServerUrl('https://example.com/api/'),
        'https://example.com/api',
      );
    });

    test('drops query and fragment', () {
      expect(
        normalizeServerUrl('https://example.com/?a=1#x'),
        'https://example.com',
      );
    });

    test('rejects garbage', () {
      expect(normalizeServerUrl(''), isNull);
      expect(normalizeServerUrl('   '), isNull);
      expect(normalizeServerUrl('ftp://example.com'), isNull);
      expect(normalizeServerUrl('https://'), isNull);
    });
  });

  group('ApiClient', () {
    ApiClient client(MockClient m, {String? token}) =>
        ApiClient(baseUrl: 'https://x.test', token: token, client: m);

    test('sends token, json body and query; parses utf-8', () async {
      late http.Request seen;
      final c = client(
        MockClient((req) async {
          seen = req;
          return http.Response.bytes(
            utf8.encode(jsonEncode({'ok': true, 'text': 'Привет'})),
            200,
          );
        }),
        token: 'tok',
      );
      final r = await c.post('/posts', {'text': 'Привет'});
      expect(r['text'], 'Привет');
      expect(seen.method, 'POST');
      expect(seen.url.toString(), 'https://x.test/posts');
      expect(seen.headers['x-user-token'], 'tok');
      expect(seen.headers['content-type'], contains('application/json'));
      expect(jsonDecode(seen.body), {'text': 'Привет'});

      await client(
        MockClient((req) async {
          seen = req;
          return http.Response('{}', 200);
        }),
      ).get('/posts', query: {'limit': '5'});
      expect(seen.url.query, 'limit=5');
      expect(seen.headers.containsKey('x-user-token'), isFalse);
    });

    test('maps server errors to codes', () async {
      final c = client(
        MockClient((_) async => http.Response('{"error":"too_long"}', 422)),
      );
      expect(
        () => c.post('/posts', {}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'too_long')
              .having((e) => e.status, 'status', 422),
        ),
      );
    });

    test('non-json error body still produces an ApiException', () async {
      final c = client(MockClient((_) async => http.Response('<html>', 502)));
      expect(
        () => c.get('/x'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'http_502')),
      );
    });

    test('connection problems become a network error', () async {
      final c = client(
        MockClient((_) async => throw http.ClientException('down')),
      );
      expect(
        () => c.get('/x'),
        throwsA(
          isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', isTrue),
        ),
      );
    });

    test('empty 200 response is an empty map', () async {
      final c = client(MockClient((_) async => http.Response('', 200)));
      expect(await c.delete('/x'), isEmpty);
    });
  });

  group('formatAgo', () {
    final now = DateTime(2026, 11, 9, 12);
    test('relative times', () {
      expect(formatAgo(now, now), 'только что');
      expect(
        formatAgo(now.subtract(const Duration(seconds: 30)), now),
        'только что',
      );
      expect(
        formatAgo(now.subtract(const Duration(minutes: 5)), now),
        '5 мин назад',
      );
      expect(
        formatAgo(now.subtract(const Duration(hours: 3)), now),
        '3 ч назад',
      );
      expect(formatAgo(DateTime(2026, 11, 8, 9), now), 'вчера');
      expect(formatAgo(DateTime(2026, 10, 1), now), '01.10.2026');
    });

    test('a timestamp from the future is not shown as negative', () {
      expect(formatAgo(now.add(const Duration(minutes: 2)), now), 'только что');
    });
  });
}
