import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../core/design/tokens.dart';
import '../providers/agent_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import 'actions_panel.dart';
import 'tools_panel.dart';

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

  Future<void> _sendMessage({String? overrideText}) async {
    final message = (overrideText ?? _messageController.text).trim();
    if (message.isEmpty && _base64Image == null) return;

    setState(() => _isLoading = true);

    ref.read(agentMessagesProvider.notifier).addMessage({
      'role': 'user',
      'content': message,
      'hasImage': _base64Image != null,
    });

    if (overrideText == null) _messageController.clear();
    final imageToSend = _base64Image;
    setState(() => _base64Image = null);

    try {
      final repository = ref.read(agentRepositoryProvider);
      final messages = ref.read(agentMessagesProvider.notifier);
      final settings = ref.read(settingsProvider);
      final llmHeaders = llmHeadersFromSettings(settings);

      await for (final event in repository.chat(
        message: message,
        sessionId: _sessionId,
        image: imageToSend,
        llmHeaders: llmHeaders,
      )) {
        if (event['event'] == 'message') {
          final data = event['data'] is String
              ? jsonDecode(event['data'])
              : event['data'];
          messages.addMessage({
            'role': 'assistant',
            'content': data['content'],
            'needs_confirmation': data['needs_confirmation'] == true,
            'action_executed': data['action_executed'] == true,
            'pending_tool_calls': data['pending_tool_calls'],
            'tool_traces': data['tool_traces'],
          });
          if (data['session_id'] != null) {
            _sessionId = data['session_id'];
          }
        } else if (event['event'] == 'error') {
          final data = event['data'] is String
              ? jsonDecode(event['data'])
              : event['data'];
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(agentMessagesProvider);
    final settings = ref.watch(settingsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 助手'),
        automaticallyImplyLeading: false,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.extension_outlined, size: 20),
            tooltip: '可用工具',
            onPressed: () => AgentToolsPanel.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded, size: 20),
            tooltip: '操作记录',
            onPressed: () => AgentActionsPanel.show(context),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: settings.isConfigured
                  ? Colors.green.withValues(alpha: 0.10)
                  : scheme.onSurfaceVariant.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: settings.isConfigured
                    ? Colors.green.withValues(alpha: 0.30)
                    : Colors.transparent,
              ),
            ),
            child: Text(
              settings.isConfigured
                  ? settings.provider.toUpperCase()
                  : '未配置',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: settings.isConfigured
                    ? Colors.green.shade700
                    : scheme.onSurfaceVariant,
              ),
            ),
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
                ? _EmptyChat(
                    onPrompt: (p) => _sendMessage(overrideText: p),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return _MessageBubble(
                        msg: msg,
                        loading: _isLoading,
                        onConfirm: () => _sendMessage(overrideText: '是'),
                        onCancel: () => _sendMessage(overrideText: '取消'),
                      );
                    },
                  ),
          ),
          _Composer(
            controller: _messageController,
            onSend: () => _sendMessage(),
            onPickImage: _pickImage,
            isLoading: _isLoading,
            hasImage: _base64Image != null,
            onClearImage: () => setState(() => _base64Image = null),
          ),
        ],
      ),
    );
  }
}

// ─── Message bubble (assistant / user / tool) ───────────────────────────────
class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool loading;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  const _MessageBubble({
    required this.msg,
    required this.loading,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = msg['role'] == 'user';
    final pendingCalls = (msg['pending_tool_calls'] as List?)
        ?.cast<Map<String, dynamic>>();
    final traces = (msg['tool_traces'] as List?)?.cast<Map<String, dynamic>>();

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.gap3),
        padding: const EdgeInsets.all(AppSpacing.gap3),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? scheme.primary : scheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.m),
            topRight: const Radius.circular(AppRadius.m),
            bottomLeft: Radius.circular(
                isUser ? AppRadius.m : AppRadius.s),
            bottomRight: Radius.circular(
                isUser ? AppRadius.s : AppRadius.m),
          ),
          border: isUser
              ? null
              : Border.all(color: scheme.outlineVariant),
          boxShadow: AppShadow.subtle(scheme.shadow),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg['hasImage'] == true)
              Container(
                height: 100,
                width: 100,
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.image, size: 40, color: scheme.onSurfaceVariant),
              ),
            Text(
              (msg['content'] ?? '').toString(),
              style: TextStyle(
                color: isUser ? Colors.white : scheme.onSurface,
                height: 1.5,
                fontSize: 14,
              ),
            ),
            if (traces != null && traces.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              for (final t in traces) _ToolTrace(trace: t),
            ],
            if (pendingCalls != null && pendingCalls.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              for (final c in pendingCalls) _ToolCallCard(call: c),
            ],
            if (!isUser && msg['needs_confirmation'] == true) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: loading ? null : onConfirm,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('确认执行'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: loading ? null : onCancel,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('取消'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToolCallCard extends StatelessWidget {
  final Map<String, dynamic> call;
  const _ToolCallCard({required this.call});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final args = call['arguments'];
    final argText = args is Map || args is List
        ? const JsonEncoder.withIndent('  ').convert(args)
        : args?.toString() ?? '{}';
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 14, color: scheme.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  call['name']?.toString() ?? 'tool',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
          if (argText.trim().isNotEmpty && argText != '{}') ...[
            const SizedBox(height: 4),
            Text(
              argText,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ToolTrace extends StatelessWidget {
  final Map<String, dynamic> trace;
  const _ToolTrace({required this.trace});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ok = trace['ok'] == true;
    final color = ok ? Colors.green.shade600 : scheme.error;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle_outline : Icons.error_outline,
              size: 12, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${trace['name']}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Composer ──────────────────────────────────────────────────────────────
class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;
  final bool isLoading;
  final bool hasImage;
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.onPickImage,
    required this.onClearImage,
    required this.isLoading,
    required this.hasImage,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasImage)
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
                child: Row(
                  children: [
                    Icon(Icons.image_outlined, size: 14, color: scheme.primary),
                    const SizedBox(width: 4),
                    Text('已添加图片',
                        style: TextStyle(
                            fontSize: 12,
                            color: scheme.primary,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    InkWell(
                      onTap: onClearImage,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded,
                            size: 14, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image_outlined, size: 20),
                  onPressed: onPickImage,
                  color: scheme.onSurfaceVariant,
                  tooltip: '附加图片',
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: '输入消息…',
                      hintStyle: TextStyle(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      isDense: true,
                    ),
                    onSubmitted: (_) => onSend(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded, size: 22),
                  color: scheme.primary,
                  onPressed: isLoading ? null : onSend,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChat extends ConsumerWidget {
  final ValueChanged<String> onPrompt;
  const _EmptyChat({required this.onPrompt});

  static const _prompts = [
    ('📝', '帮我生成一份语文测验题'),
    ('🎯', '如何提高学生课堂参与度？'),
    ('📨', '帮我写一份家长通知书'),
    ('📊', '分析成绩波动的可能原因'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final palette = ref.watch(themeProvider).palette;
    final accent = AppAccent(palette).ai;
    final brightness = Theme.of(context).brightness;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gap5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                gradient: AppGradient.accent(accent, brightness),
                borderRadius: BorderRadius.circular(AppRadius.l),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 36, color: Colors.white),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(
                  begin: -4,
                  end: 4,
                  duration: const Duration(milliseconds: 2200),
                  curve: Curves.easeInOutSine,
                ),
            const SizedBox(height: AppSpacing.xl),
            Text('有什么可以帮你的？',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.xs),
            Text('试试以下问题，或直接输入',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.xxl),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < _prompts.length; i++)
                  InkWell(
                    onTap: () => onPrompt(_prompts[i].$2),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm + 2),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                            color: scheme.outlineVariant),
                        boxShadow: AppShadow.soft(scheme.shadow),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_prompts[i].$1,
                              style: const TextStyle(fontSize: 15)),
                          const SizedBox(width: 6),
                          Text(_prompts[i].$2,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  )
                      .animate(
                          delay: Duration(milliseconds: 80 * i))
                      .fadeIn(duration: AppMotion.medium)
                      .moveY(begin: 8, end: 0),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
