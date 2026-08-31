import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'revenuecat_service.dart';

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
    } catch (_) {}

    return error.message;
  }

  return error.toString().isNotEmpty ? error.toString() : 'Can\'t reach the server. Check your connection and try again.';
  // return 'Can\'t reach the server. Check your connection and try again.';
}

class Api {
  Api._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api-handover.fvlabs.org',
  );

  static final Uri _parsedBaseUrl = Uri.parse(baseUrl);

  static const String _tokenKey = 'handover_token';

  static String? _token;
  static int? currentUserId;
  static double? currentLat;
  static double? currentLng;

  static bool get hasToken => _token != null;

  static Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    if (_token == null) return;
    try {
      final me = await get('/api/users/me');
      final data = me as Map<String, dynamic>;
      currentUserId = data['id'] as int;
      currentLat = (data['lat'] as num?)?.toDouble();
      currentLng = (data['lng'] as num?)?.toDouble();
    } catch (e) {
      if (e is ApiException && e.statusCode == 401) {
        _token = null;
        currentUserId = null;
        currentLat = null;
        currentLng = null;
        await prefs.remove(_tokenKey);
      }
    }
  }

  static Future<void> storeSession(String token, int userId,
      {double? lat, double? lng}) async {
    _token = token;
    currentUserId = userId;
    currentLat = lat;
    currentLng = lng;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    try {
      await RevenueCatService.setUserId(userId.toString());
    } catch (_) {}
  }

  static Future<void> clearSession() async {
    try {
      await post('/api/auth/logout');
    } catch (_) {}
    _token = null;
    currentUserId = null;
    currentLat = null;
    currentLng = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    try {
      await RevenueCatService.logOut();
    } catch (_) {}
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(baseUrl);
    // Release guard: https required in release; http allowed for any host in debug/profile (LAN IPs like 10.236.9.56)
    assert(!kReleaseMode || base.scheme == 'https',
        'API_BASE_URL must be https:// in production (got $baseUrl)');
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

  static Uri get notificationWebSocketUri {
    final apiUri = Uri.parse(baseUrl);
    return apiUri.replace(
      scheme: apiUri.scheme == 'https' ? 'wss' : 'ws',
      path: '/api/notifications',
      queryParameters: {'token': _token ?? ''},
    );
  }

  static String? get token => _token;

  static Future<bool> get isConnected async {
    try {
      final socket = await Socket.connect(
        _parsedBaseUrl.host,
        _parsedBaseUrl.port,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
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
    } else if (res.statusCode == 401) {
      detail = 'Session expired. Please sign in again.';
    } else if (res.statusCode == 404) {
      detail = 'Resource not found.';
    } else if (res.statusCode >= 500) {
      detail = 'Something went wrong on our end. Please try again later.';
    } else {
      detail = 'Something went wrong. Please try again.';
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
      String detail;
      try {
        final body = jsonDecode(response.body);
        detail = body is Map && body['detail'] is String
            ? body['detail']
            : 'Upload failed. Please try again.';
      } catch (_) {
        detail = 'Upload failed. Please try again.';
      }
      throw ApiException(detail, statusCode: response.statusCode);
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

  static Future<Map<String, dynamic>> getLegal() async {
    final res = await get('/api/legal');
    return res as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> exportMyData() async {
    final res = await get('/api/users/me/export');
    return res as Map<String, dynamic>;
  }

  static Future<void> deleteAccount() async {
    await delete('/api/users/me');
  }
}
