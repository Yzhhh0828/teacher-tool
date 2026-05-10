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

  Future<List<Map<String, dynamic>>> listTools({String? category}) async {
    final r = await _client.get(
      ApiConfig.agentTools,
      queryParameters: category != null ? {'category': category} : null,
    );
    return List<Map<String, dynamic>>.from(r.data['items']);
  }

  Future<Map<String, dynamic>> invokeTool({
    required String name,
    Map<String, dynamic> arguments = const {},
    bool confirmed = false,
  }) async {
    final r = await _client.post(
      ApiConfig.agentToolsInvoke,
      data: {'name': name, 'arguments': arguments, 'confirmed': confirmed},
    );
    return Map<String, dynamic>.from(r.data);
  }

  Future<List<Map<String, dynamic>>> listActions({int limit = 20}) async {
    final r = await _client.get('/agent/actions', queryParameters: {'limit': limit});
    return List<Map<String, dynamic>>.from(r.data['items']);
  }

  Future<Map<String, dynamic>> undoAction(int actionId) async {
    final r = await _client.post('/agent/actions/$actionId/undo');
    return Map<String, dynamic>.from(r.data);
  }

  /// Round-trip a 1-token "ping" so the user can verify their LLM
  /// configuration before saving / using it.
  Future<Map<String, dynamic>> testConnection({
    Map<String, String>? llmHeaders,
  }) async {
    final r = await _client.post(
      '/agent/test_connection',
      extraHeaders: llmHeaders,
    );
    return Map<String, dynamic>.from(r.data);
  }
}
