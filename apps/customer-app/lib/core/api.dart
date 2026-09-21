import 'package:onehub_shared/onehub_shared.dart';

// 10.0.2.2 is the Android emulator's alias for the host machine's localhost.
// Override with --dart-define=API_BASE_URL=... for iOS simulator or a real device.
final api = ApiClient(
  baseUrl: const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000/api/v1'),
);
