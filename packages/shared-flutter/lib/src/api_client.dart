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

  /// Called once when a signed-in request comes back 401: the token expired
  /// (it lasts `JWT_EXPIRES_IN`, 7 days by default) or was never stored. The
  /// token is already deleted by then; each app sends the user to login.
  /// Several screens load at once, so later 401s from the same session are
  /// ignored until a new token is saved.
  void Function()? onSessionExpired;
  bool _expiryReported = false;

  Future<void> _saveToken(String token) {
    _expiryReported = false;
    return _storage.write(key: 'access_token', value: token);
  }

  Future<String?> get token => _storage.read(key: 'access_token');

  // Only signed-in calls count: a 401 from login itself means a wrong
  // password, not an expired session.
  Future<void> _checkSession(int statusCode, bool signedIn) async {
    if (statusCode != 401 || !signedIn || _expiryReported) return;
    _expiryReported = true;
    await logout();
    onSessionExpired?.call();
  }

  // Signs out locally by forgetting the stored token; there is no server-side
  // session to end, since requests authenticate with the bearer token alone.
  Future<void> logout() => _storage.delete(key: 'access_token');

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {bool auth = false}) =>
      _send(_http.post, path, body, auth);

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body, {bool auth = false}) =>
      _send(_http.put, path, body, auth);

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
    final raw = _decode(res.body);
    final decoded = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    if (res.statusCode >= 400) {
      await _checkSession(res.statusCode, auth);
      throw ApiException(res.statusCode, decoded['message']?.toString() ?? 'request failed');
    }
    if (decoded.containsKey('accessToken')) {
      await _saveToken(decoded['accessToken'] as String);
    }
    return decoded;
  }

  // An empty body is a valid answer, not an error: Nest sends nothing when a
  // handler returns null (e.g. "this job has no rating yet"), so it decodes to
  // null. A body that is not JSON, such as a proxy's HTML error page, also
  // decodes to null so the caller sees the HTTP status instead of a
  // FormatException.
  static dynamic _decode(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  Future<dynamic> get(String path) async {
    final t = await token;
    final res = await _http.get(
      Uri.parse('$baseUrl$path'),
      headers: {if (t != null) 'Authorization': 'Bearer $t'},
    );
    final decoded = _decode(res.body);
    if (res.statusCode >= 400) {
      // Every GET is a signed-in call or a public one that never answers 401,
      // so a 401 here means no valid session, token or not.
      await _checkSession(res.statusCode, true);
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
