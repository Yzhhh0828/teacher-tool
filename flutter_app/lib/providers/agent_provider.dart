import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/agent_repository.dart';
import '../data/services/sse_service.dart';
import 'auth_provider.dart';

final agentRepositoryProvider = Provider((ref) => AgentRepository(ref.read(apiClientProvider)));
final sseServiceProvider = Provider((ref) => SSEService());

final agentMessagesProvider = StateNotifierProvider<AgentMessagesNotifier, List<Map<String, dynamic>>>((ref) {
  return AgentMessagesNotifier();
});

class AgentMessagesNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  AgentMessagesNotifier() : super([]);

  void addMessage(Map<String, dynamic> message) {
    state = [...state, message];
  }

  void clear() {
    state = [];
  }
}
