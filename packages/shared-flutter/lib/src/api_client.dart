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

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  /// Called once when the sign-in has ended: a signed-in request came back
  /// 401 and the refresh token could not renew it (30 days unused, revoked by
  /// a password reset or logout elsewhere, or never stored). Both tokens are
  /// already deleted by then; each app sends the user to login. Several
  /// screens load at once, so later 401s are ignored until a new sign-in.
  void Function()? onSessionExpired;
  bool _expiryReported = false;

  // One renewal at a time: screens that hit the expired access token together
  // all wait on the same refresh call, since each refresh token works once.
  Future<bool?>? _renewing;

  // Login, signup and refresh answers carry an access token, and from login
  // and refresh a refresh token too.
  Future<void> _saveTokens(Map<String, dynamic> body) async {
    _expiryReported = false;
    await _storage.write(key: _accessKey, value: body['accessToken'] as String);
    final refresh = body['refreshToken'];
    if (refresh is String) await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<String?> get token => _storage.read(key: _accessKey);

  /// True when the access token was renewed, false when the API refused the
  /// refresh token (the sign-in is over), null when the API could not be
  /// reached (the sign-in may be fine, so it is kept).
  Future<bool?> _renew() =>
      _renewing ??= _doRenew().whenComplete(() => _renewing = null);

  Future<bool?> _doRenew() async {
    final refresh = await _storage.read(key: _refreshKey);
    if (refresh == null) return false;
    final http.Response res;
    try {
      res = await _http.post(Uri.parse('$baseUrl/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refresh}));
    } catch (_) {
      return null;
    }
    final body = _decode(res.body);
    if (res.statusCode < 400 &&
        body is Map<String, dynamic> &&
        body['accessToken'] is String) {
      await _saveTokens(body);
      return true;
    }
    return res.statusCode >= 500 ? null : false;
  }

  // A signed-in call was refused with [res]: renew and send it again once
  // through [again]. When the sign-in is over, forget it and tell the app.
  Future<http.Response> _retryAfter401(
      http.Response res, Future<http.Response> Function() again) async {
    final renewed = await _renew();
    if (renewed == true) {
      final retried = await again();
      if (retried.statusCode == 401) await _expire();
      return retried;
    }
    if (renewed == false) await _expire();
    return res;
  }

  Future<void> _expire() async {
    if (_expiryReported) return;
    _expiryReported = true;
    await _forget();
    onSessionExpired?.call();
  }

  Future<void> _forget() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  /// Ends this sign-in: asks the API to revoke the refresh token, then forgets
  /// both tokens. Revoking is best effort, so logging out offline still signs
  /// out on this device.
  Future<void> logout() async {
    final refresh = await _storage.read(key: _refreshKey);
    if (refresh != null) {
      try {
        await _http.post(Uri.parse('$baseUrl/auth/logout'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refresh}));
      } catch (_) {}
    }
    await _forget();
  }

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
    Future<http.Response> once() async {
      final headers = {'Content-Type': 'application/json'};
      if (auth) {
        final t = await token;
        if (t != null) headers['Authorization'] = 'Bearer $t';
      }
      return method(Uri.parse('$baseUrl$path'), headers: headers, body: jsonEncode(body));
    }

    var res = await once();
    // Only signed-in calls renew: a 401 from login itself means a wrong
    // password, not an expired sign-in.
    if (res.statusCode == 401 && auth) res = await _retryAfter401(res, once);
    final raw = _decode(res.body);
    final decoded = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, decoded['message']?.toString() ?? 'request failed');
    }
    if (decoded['accessToken'] is String) await _saveTokens(decoded);
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
    Future<http.Response> once() async {
      final t = await token;
      return _http.get(
        Uri.parse('$baseUrl$path'),
        headers: {if (t != null) 'Authorization': 'Bearer $t'},
      );
    }

    var res = await once();
    // Every GET is a signed-in call or a public one that never answers 401,
    // so a 401 here means the access token needs renewing, token or not.
    if (res.statusCode == 401) res = await _retryAfter401(res, once);
    final decoded = _decode(res.body);
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
