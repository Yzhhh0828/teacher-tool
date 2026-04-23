import '../../core/config/api_config.dart';
import '../../core/utils/api_client.dart';
import '../services/sse_service.dart';

class AgentRepository {
  final ApiClient _client;
  final SSEService _sseService;

  AgentRepository(this._client) : _sseService = SSEService();

  Stream<Map<String, dynamic>> chat({
    required String message,
    String? sessionId,
    String? image,
    Map<String, String>? llmHeaders,
  }) {
    return _sseService.connect(
      ApiConfig.agentChat,
      {
        'content': message,
        'session_id': sessionId,
        'image': image,
      },
      extraHeaders: llmHeaders,
    );
  }

  Future<List<Map<String, dynamic>>> getHistory(String sessionId) async {
    final response = await _client.get(ApiConfig.agentHistory(sessionId));
    return List<Map<String, dynamic>>.from(response.data['messages']);
  }

  Future<void> deleteHistory(String sessionId) async {
    await _client.delete(ApiConfig.agentHistory(sessionId));
  }
}
