import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.status, this.code);

  /// HTTP-статус; 0 — нет связи с сервером.
  final int status;
  final String code;

  bool get isNetwork => status == 0;

  @override
  String toString() => 'ApiException($status, $code)';
}

/// Приводит адрес сервера к виду «https://host:port» без хвостового слеша.
/// Возвращает null, если адрес некорректен.
String? normalizeServerUrl(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;
  if (!s.contains('://')) s = 'https://$s';
  final uri = Uri.tryParse(s);
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      uri.host.isEmpty) {
    return null;
  }
  final path = uri.path.endsWith('/')
      ? uri.path.substring(0, uri.path.length - 1)
      : uri.path;
  // Собираем вручную: Uri.replace оставляет «?#» после очистки query/fragment.
  return '${uri.scheme}://${uri.authority}$path';
}

/// Тонкая обёртка над http: JSON, токен, понятные ошибки.
class ApiClient {
  ApiClient({required this.baseUrl, this.token, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final String? token;
  final http.Client _client;

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<Map<String, dynamic>> post(String path, [Object? body]) =>
      _send('POST', path, body: body);

  Future<Map<String, dynamic>> put(String path, [Object? body]) =>
      _send('PUT', path, body: body);

  Future<Map<String, dynamic>> delete(String path) => _send('DELETE', path);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers['content-type'] = 'application/json; charset=utf-8';
    if (token != null) request.headers['x-user-token'] = token!;
    if (body != null) request.body = jsonEncode(body);

    final http.Response res;
    try {
      res = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 20)),
      );
    } on TimeoutException {
      throw const ApiException(0, 'timeout');
    } catch (_) {
      throw const ApiException(0, 'network');
    }

    Map<String, dynamic> json = {};
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {}
    if (res.statusCode >= 200 && res.statusCode < 300) return json;
    throw ApiException(
      res.statusCode,
      (json['error'] as String?) ?? 'http_${res.statusCode}',
    );
  }

  void close() => _client.close();
}
