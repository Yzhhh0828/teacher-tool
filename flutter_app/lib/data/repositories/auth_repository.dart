import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/config/api_config.dart';
import '../../core/utils/api_client.dart';
import '../models/user.dart';

class AuthRepository {
  final ApiClient _client;
  final _storage = const FlutterSecureStorage();

  AuthRepository(this._client);

  Future<String?> sendCode(String phone) async {
    final response = await _client.post(ApiConfig.sendCode, data: {'phone': phone});
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data['debug_code'] as String?;
    }
    return null;
  }

  Future<AuthTokens> login(String phone, String code) async {
    final response = await _client.post(
      ApiConfig.login,
      data: {'phone': phone, 'code': code},
    );
    final tokens = AuthTokens.fromJson(response.data);

    // Save tokens
    await _storage.write(key: 'access_token', value: tokens.accessToken);
    await _storage.write(key: 'refresh_token', value: tokens.refreshToken);

    return tokens;
  }

  Future<User> getMe() async {
    final response = await _client.get(ApiConfig.me);
    return User.fromJson(response.data);
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'access_token');
    return token != null;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }
}
