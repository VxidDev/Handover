import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

String describeError(Object error) {
  if (error is ApiException) {
    try {
      final decoded = jsonDecode(error.message);

      final List<dynamic>? errorList = decoded is List
          ? decoded
          : (decoded is Map && decoded['detail'] is List
                ? decoded['detail']
                : null);

      if (errorList != null && errorList.isNotEmpty) {
        final messages = errorList.map((err) {
          String msg = err['msg']?.toString() ?? 'Invalid value';
          // Clean up standard Pydantic prefix if present
          if (msg.startsWith('Value error, ')) {
            msg = msg.replaceFirst('Value error, ', '');
          }
          return '• $msg';
        }).toSet();

        return messages.join('\n');
      }

      if (decoded is Map && decoded['detail'] is String) {
        return decoded['detail'];
      }
    } catch (_) {
      // Message wasn't JSON, return raw message as fallback
    }

    return error.message;
  }

  return 'Can\'t reach the server at ${Api.baseUrl}. Is the backend running?';
}

class Api {
  Api._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:9000',
  );

  static const String _tokenKey = 'handover_token';

  static const double demoLat = 37.7749;
  static const double demoLng = -122.4195;

  static String? _token;
  static int? currentUserId;

  static bool get hasToken => _token != null;

  /// Restores a stored token and validates it against the backend. Invalid or
  /// expired tokens are dropped.
  static Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    if (_token == null) return;
    try {
      final me = await get('/api/users/me');
      currentUserId = (me as Map<String, dynamic>)['id'] as int;
    } catch (_) {
      _token = null;
      await prefs.remove(_tokenKey);
    }
  }

  static Future<void> storeSession(String token, int userId) async {
    _token = token;
    currentUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> clearSession() async {
    _token = null;
    currentUserId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Uri _uri(String path, [Map<String, dynamic>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return uri;
    final q = query.map((k, v) => MapEntry(k, v.toString()));
    return uri.replace(queryParameters: q);
  }

  static Uri roomWebSocketUri(int requestId, String roomToken) {
    final apiUri = Uri.parse(baseUrl);
    return apiUri.replace(
      scheme: apiUri.scheme == 'https' ? 'wss' : 'ws',
      path: '/api/requests/$requestId/chat',
      queryParameters: {'token': roomToken},
    );
  }

  static Future<dynamic> _send(Future<http.Response> Function() request) async {
    final res = await request();
    dynamic body;
    try {
      body = res.body.isEmpty ? null : jsonDecode(res.body);
    } catch (_) {
      body = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    String detail;
    if (body is Map && body['detail'] != null) {
      final d = body['detail'];
      detail = d is String ? d : jsonEncode(d);
    } else {
      detail = 'Request failed (${res.statusCode})';
    }
    throw ApiException(detail, statusCode: res.statusCode);
  }

  static Future<Map<String, dynamic>> uploadFile(String path, File file) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $_token';
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 400) {
      throw Exception(response.body);
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  static Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => http.get(_uri(path, query), headers: _headers));

  static Future<dynamic> post(String path, {Object? body}) => _send(
    () =>
        http.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {})),
  );

  static Future<dynamic> patch(String path, {Object? body}) => _send(
    () =>
        http.patch(_uri(path), headers: _headers, body: jsonEncode(body ?? {})),
  );

  static Future<dynamic> delete(String path) =>
      _send(() => http.delete(_uri(path), headers: _headers));
}
