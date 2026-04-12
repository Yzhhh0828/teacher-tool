import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';

class SSEService {
  final Dio _dio;

  SSEService() : _dio = Dio();

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

    await for (final chunk in stream) {
      buffer += utf8.decode(chunk);

      while (buffer.contains('\n')) {
        final index = buffer.indexOf('\n');
        final line = buffer.substring(0, index).trim();
        buffer = buffer.substring(index + 1);

        if (line.startsWith('event:')) {
          currentEventType = line.substring(6).trim();
          continue;
        }

        if (line.startsWith('data:')) {
          final jsonStr = line.substring(5).trim();
          if (jsonStr.isNotEmpty) {
            try {
              final data = jsonDecode(jsonStr);
              yield {
                'event': currentEventType ?? 'message',
                'data': data,
              };
            } catch (_) {}
          }
          currentEventType = null;
        }
      }
    }
  }
}
