import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/config/api_config.dart';

class SSEService {
  final Dio _dio;
  final _storage = const FlutterSecureStorage();

  SSEService() : _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 300),
  ));

  Stream<Map<String, dynamic>> connect(String url, Map<String, dynamic> data, {Map<String, String>? extraHeaders}) async* {
    final token = await _storage.read(key: 'access_token');
    final response = await _dio.post<ResponseBody>(
      url,
      data: data,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Accept': 'text/event-stream',
          if (token != null) 'Authorization': 'Bearer $token',
          if (extraHeaders != null) ...extraHeaders,
        },
      ),
    );

    final stream = response.data!.stream;
    String buffer = '';
    String? currentEventType;
    String currentData = '';

    await for (final chunk in stream) {
      buffer += utf8.decode(chunk, allowMalformed: true);

      while (buffer.contains('\n')) {
        final index = buffer.indexOf('\n');
        final line = buffer.substring(0, index).trim();
        buffer = buffer.substring(index + 1);

        if (line.startsWith('event:')) {
          currentEventType = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          currentData += (currentData.isEmpty ? '' : '\n') + line.substring(5).trim();
        } else if (line.isEmpty && currentEventType != null) {
          if (currentData.isNotEmpty) {
            yield _buildEvent(currentEventType, currentData);
          }
          currentEventType = null;
          currentData = '';
        }
      }
    }

    if (currentEventType != null && currentData.isNotEmpty) {
      yield _buildEvent(currentEventType, currentData);
    }
  }

  Map<String, dynamic> _buildEvent(String eventType, String rawData) {
    try {
      return {
        'event': eventType,
        'data': jsonDecode(rawData),
      };
    } catch (_) {
      return {
        'event': 'error',
        'data': {
          'error': '无法解析服务端事件',
          'raw': rawData,
          'source_event': eventType,
        },
      };
    }
  }
}
