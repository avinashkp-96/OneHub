import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onehub_customer/core/api.dart' as core;
import 'package:onehub_shared/onehub_shared.dart';

/// An error response for [FakeApi] routes.
class FakeError {
  final int status;
  final String message;
  const FakeError(this.status, [this.message = 'request failed']);
}

/// A fake backend for widget tests. Routes are keyed `'METHOD /path'` and map
/// to a function returning the JSON body (or a [FakeError]); anything not
/// listed answers 404. Every request is recorded in [calls].
class FakeApi {
  final Map<String, Object? Function(http.Request request)> routes;
  final List<String> calls = [];
  final List<Map<String, dynamic>> bodies = [];

  FakeApi(this.routes);

  ApiClient get client => ApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          if (request.method != 'GET' && request.body.isNotEmpty) {
            bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          }
          final handler = routes['${request.method} ${request.url.path}'];
          if (handler == null) {
            return http.Response(jsonEncode({'message': 'not found'}), 404);
          }
          final result = handler(request);
          if (result is FakeError) {
            return http.Response(
                jsonEncode({'message': result.message}), result.status);
          }
          return http.Response(jsonEncode(result), 200);
        }),
      );
}

/// Installs [fake] as the app's global `api` for the current test and puts the
/// original back afterwards. Also answers the secure-storage channel with
/// "no token", since [ApiClient] reads it and no plugin exists in widget tests.
FakeApi installFakeApi(
    Map<String, Object? Function(http.Request request)> routes) {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async => null,
  );
  final original = core.api;
  final fake = FakeApi(routes);
  core.api = fake.client;
  addTearDown(() => core.api = original);
  return fake;
}

Map<String, dynamic> requirementJson(
  String id,
  String description,
  String status, {
  List<Map<String, dynamic>> bids = const [],
  List<String> photos = const [],
}) =>
    {
      'id': id,
      'subServiceId': 'sub-1',
      'description': description,
      'photoUrls': photos,
      'status': status,
      'bids': bids,
    };

Map<String, dynamic> bidJson(
  String id, {
  double min = 500,
  double max = 900,
  double? refinedMin,
  double? refinedMax,
  bool contactUnlocked = false,
  bool confirmed = false,
}) =>
    {
      'id': id,
      'providerId': 'prov-$id',
      'initialMinPrice': min,
      'initialMaxPrice': max,
      'refinedMinPrice': refinedMin,
      'refinedMaxPrice': refinedMax,
      'contactUnlocked': contactUnlocked,
      'confirmed': confirmed,
    };
