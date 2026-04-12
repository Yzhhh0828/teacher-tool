import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';

class SSEService {
  final Dio _dio;

  SSEService() : _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 300),
  ));

  Stream<Map<String, dynamic>> connect(String url, Map<String, dynamic> data) async* {
    final response = await _dio.post<ResponseBody>(
      url,
      data: data,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Accept': 'text/event-stream',
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
            try {
              final data = jsonDecode(currentData);
              yield {
                'event': currentEventType,
                'data': data,
              };
            } catch (_) {}
          }
          currentEventType = null;
          currentData = '';
        }
      }
    }
  }
}
