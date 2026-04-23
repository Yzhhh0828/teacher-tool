import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/agent_provider.dart';
import '../providers/settings_provider.dart';
import '../core/theme/app_theme.dart';

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

      final settings = ref.read(settingsProvider);
      final llmHeaders = settings.isConfigured
          ? {
              'X-LLM-Provider': settings.provider,
              'X-API-Key': settings.apiKey,
              if (settings.baseUrl.isNotEmpty) 'X-Base-URL': settings.baseUrl,
            }
          : null;

      await for (final event in repository.chat(
        message: message,
        sessionId: _sessionId,
        image: imageToSend,
        llmHeaders: llmHeaders,
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

    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('AI 助手'),
        backgroundColor: AppTheme.backgroundLight,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (settings.isConfigured)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
              ),
              child: Text(
                settings.provider.toUpperCase(),
                style: const TextStyle(fontSize: 11, color: AppTheme.successColor, fontWeight: FontWeight.w700),
              ),
            )
          else
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('未配置', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: '清空对话',
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
                ? _EmptyChat(onPrompt: (p) {
                    _messageController.text = p;
                    _sendMessage();
                  })
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
                                ? AppTheme.primaryColor
                                : AppTheme.surfaceWhite,
                            borderRadius: BorderRadius.circular(AppTheme.radius),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (msg['hasImage'] == true)
                                Container(
                                  height: 100,
                                  width: 100,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.dividerColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.image, size: 40, color: AppTheme.textSecondary),
                                ),
                              Text(
                                msg['content'] ?? '',
                                style: TextStyle(
                                  color: isUser ? Colors.white : AppTheme.textPrimary,
                                ),
                              ),
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
              color: AppTheme.backgroundLight,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.image_outlined, size: 20), onPressed: _pickImage, color: AppTheme.textSecondary),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: '输入消息…',
                        hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5)),
                        filled: true,
                        fillColor: AppTheme.surfaceSubtle,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: _isLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded, size: 22),
                    color: AppTheme.primaryColor,
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

class _EmptyChat extends StatelessWidget {
  final ValueChanged<String> onPrompt;
  const _EmptyChat({required this.onPrompt});

  static const _prompts = [
    '帮我生成一份语文测验题',
    '如何提高学生课堂参与度？',
    '帮我写一份家长通知书',
    '分析成绩波动的可能原因',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.smart_toy_outlined, size: 28, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 16),
            Text('有什么可以帮助你？', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('试试以下问题，或直接输入', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _prompts.map((p) => GestureDetector(
                onTap: () => onPrompt(p),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceWhite,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Text(p, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
