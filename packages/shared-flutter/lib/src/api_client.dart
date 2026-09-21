import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Thin wrapper around services/api's `/api/v1` routes. Both the customer and
// provider apps depend on this package instead of duplicating HTTP calls.
class ApiClient {
  final String baseUrl;
  final http.Client _http;
  final FlutterSecureStorage _storage;

  ApiClient({required this.baseUrl, http.Client? httpClient, FlutterSecureStorage? storage})
      : _http = httpClient ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  Future<void> _saveToken(String token) => _storage.write(key: 'access_token', value: token);
  Future<String?> get token => _storage.read(key: 'access_token');

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {bool auth = false}) =>
      _send(_http.post, path, body, auth);

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body, {bool auth = false}) =>
      _send(_http.patch, path, body, auth);

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function(Uri, {Map<String, String>? headers, Object? body}) method,
    String path,
    Map<String, dynamic> body,
    bool auth,
  ) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final t = await token;
      if (t != null) headers['Authorization'] = 'Bearer $t';
    }
    final res = await method(Uri.parse('$baseUrl$path'), headers: headers, body: jsonEncode(body));
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, decoded['message']?.toString() ?? 'request failed');
    }
    if (decoded.containsKey('accessToken')) {
      await _saveToken(decoded['accessToken'] as String);
    }
    return decoded;
  }

  Future<dynamic> get(String path) async {
    final t = await token;
    final res = await _http.get(
      Uri.parse('$baseUrl$path'),
      headers: {if (t != null) 'Authorization': 'Bearer $t'},
    );
    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      final message = decoded is Map ? decoded['message']?.toString() : 'request failed';
      throw ApiException(res.statusCode, message ?? 'request failed');
    }
    return decoded;
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
