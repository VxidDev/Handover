import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
}

class ApiService {
  static const String baseUrl = 'http://10.236.9.56:8000'; // local device IP

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> setToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    token == null ? prefs.remove('auth_token') : prefs.setString('auth_token', token);
  }

  static Future<void> logout() => setToken(null);

  static Map<String, String> _headers([String? token]) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static Map<String, dynamic> _handle(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isEmpty ? {} : jsonDecode(res.body) as Map<String, dynamic>;
    }
    var msg = 'Error ${res.statusCode}';
    try {
      final d = jsonDecode(res.body);
      if (d['detail'] is String) msg = d['detail'];
    } catch (_) {}
    throw ApiException(msg);
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final res = await http.post(Uri.parse('$baseUrl$path'),
        headers: _headers(), body: jsonEncode(body));
    return _handle(res);
  }

  static Future<void> register({
    required String name, required String email, required String password,
  }) async {
    final data = await _post('/auth/register',
        {'name': name, 'email': email, 'password': password});
    await setToken(data['access_token'] as String);
  }

  static Future<bool> login({required String email, required String password}) async {
    final data = await _post('/auth/login', {'email': email, 'password': password});
    final token = data['access_token'] as String?;
    if (token == null) return false;
    await setToken(token);
    return true;
  }

  static Future<Map<String, dynamic>> me() async {
    final token = await getToken();
    if (token == null) throw ApiException('Not logged in');
    final res = await http.get(Uri.parse('$baseUrl/auth/me'), headers: _headers(token));
    return _handle(res);
  }
}