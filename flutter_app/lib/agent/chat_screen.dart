import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/agent_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  String? _sessionId;
  String? _base64Image;
  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _base64Image = base64Encode(bytes);
      });
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty && _base64Image == null) return;

    setState(() => _isLoading = true);

    ref.read(agentMessagesProvider.notifier).addMessage({
      'role': 'user',
      'content': message,
      'hasImage': _base64Image != null,
    });

    _messageController.clear();
    final imageToSend = _base64Image;
    setState(() => _base64Image = null);

    try {
      final repository = ref.read(agentRepositoryProvider);
      final messages = ref.read(agentMessagesProvider.notifier);

      await for (final event in repository.chat(
        message: message,
        sessionId: _sessionId,
        image: imageToSend,
      )) {
        if (event['event'] == 'message') {
          final data = event['data'] is String ? jsonDecode(event['data']) : event['data'];
          messages.addMessage({
            'role': 'assistant',
            'content': data['content'],
          });
          if (data['session_id'] != null) {
            _sessionId = data['session_id'];
          }
        } else if (event['event'] == 'error') {
          final data = event['data'] is String ? jsonDecode(event['data']) : event['data'];
          final errorMessage = data is Map<String, dynamic>
              ? (data['error']?.toString() ?? 'Agent 服务异常')
              : 'Agent 服务异常';
          messages.addMessage({
            'role': 'assistant',
            'content': '抱歉，发生了错误: $errorMessage',
          });
        }
      }
    } catch (e) {
      ref.read(agentMessagesProvider.notifier).addMessage({
        'role': 'assistant',
        'content': '抱歉，发生了错误: $e',
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(agentMessagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 助手'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final sessionId = _sessionId;
              if (sessionId != null) {
                try {
                  await ref.read(agentRepositoryProvider).deleteHistory(sessionId);
                } catch (_) {}
              }
              ref.read(agentMessagesProvider.notifier).clear();
              _sessionId = null;
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text('有什么可以帮助你的？'),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.7,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (msg['hasImage'] == true)
                                Container(
                                  height: 100,
                                  width: 100,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image, size: 50),
                                ),
                              Text(msg['content'] ?? ''),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.image), onPressed: _pickImage),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(hintText: '输入消息...'),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: _isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                    onPressed: _isLoading ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
