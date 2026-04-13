import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class ApiClient {
  late final Dio _dio;
  final _storage = const FlutterSecureStorage();
  final Future<void> Function()? _onSessionExpired;

  ApiClient({Future<void> Function()? onSessionExpired})
      : _onSessionExpired = onSessionExpired {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        final requestOptions = error.requestOptions;
        final hasRetried = requestOptions.extra['retried_after_refresh'] == true;
        final isRefreshRequest = requestOptions.path == ApiConfig.refresh;

        if (error.response?.statusCode == 401 && !hasRetried && !isRefreshRequest) {
          // Try to refresh token
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry request
            final opts = requestOptions;
            final token = await _storage.read(key: 'access_token');
            opts.headers['Authorization'] = 'Bearer $token';
            opts.extra['retried_after_refresh'] = true;
            final response = await _dio.fetch(opts);
            return handler.resolve(response);
          }
          await _clearTokens(notifySessionExpired: true);
        } else if (error.response?.statusCode == 401) {
          await _clearTokens(notifySessionExpired: true);
        }
        return handler.next(error);
      },
    ));
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;

      final response = await Dio().post(
        '${ApiConfig.baseUrl}${ApiConfig.refresh}',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        await _storage.write(
          key: 'access_token',
          value: response.data['access_token'],
        );
        await _storage.write(
          key: 'refresh_token',
          value: response.data['refresh_token'],
        );
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (error) {
      throw Exception(_describeError(error));
    }
  }

  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (error) {
      throw Exception(_describeError(error));
    }
  }

  Future<Response> put(String path, {dynamic data}) async {
    try {
      return await _dio.put(path, data: data);
    } on DioException catch (error) {
      throw Exception(_describeError(error));
    }
  }

  Future<Response> delete(String path) async {
    try {
      return await _dio.delete(path);
    } on DioException catch (error) {
      throw Exception(_describeError(error));
    }
  }

  Future<void> _clearTokens({bool notifySessionExpired = false}) async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    if (notifySessionExpired && _onSessionExpired != null) {
      await _onSessionExpired!();
    }
  }

  String _describeError(DioException error) {
    final responseData = error.response?.data;
    if (responseData is Map<String, dynamic>) {
      final detail = responseData['detail'] ?? responseData['message'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail;
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '请求超时，请稍后重试';
      case DioExceptionType.connectionError:
        return '无法连接到服务器，请检查地址和网络';
      case DioExceptionType.badResponse:
        return '服务器返回了异常响应';
      case DioExceptionType.cancel:
        return '请求已取消';
      case DioExceptionType.badCertificate:
        return '服务器证书无效';
      case DioExceptionType.unknown:
        return '发生了未知网络错误';
    }
  }
}
