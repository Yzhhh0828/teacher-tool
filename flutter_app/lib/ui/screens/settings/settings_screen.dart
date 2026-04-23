import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _baseUrlCtrl;
  String _provider = 'openai';
  bool _obscureKey = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _provider = s.provider;
    _apiKeyCtrl = TextEditingController(text: s.apiKey);
    _baseUrlCtrl = TextEditingController(text: s.baseUrl);
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _baseUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(settingsProvider.notifier).save(
          provider: _provider,
          apiKey: _apiKeyCtrl.text.trim(),
          baseUrl: _baseUrlCtrl.text.trim(),
        );
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存，下次 AI 请求即刻生效')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: AppTheme.backgroundLight,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(title: 'AI 模型配置'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _ProviderSelector(
                value: _provider,
                onChanged: (v) => setState(() => _provider = v),
              ),
              const Divider(height: 1, color: AppTheme.dividerColor),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('API Key', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _apiKeyCtrl,
                      obscureText: _obscureKey,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'sk-...',
                        hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.4)),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscureKey = !_obscureKey),
                          color: AppTheme.textSecondary,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.dividerColor),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Base URL（可选，用于代理）',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _baseUrlCtrl,
                      decoration: InputDecoration(
                        hintText: 'https://api.openai.com/v1',
                        hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.4)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.dividerColor),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('保存配置'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _InfoTile(
            icon: Icons.info_outline,
            text: 'API Key 加密存储在本地，随每次 AI 请求发送至后端覆盖环境变量配置',
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: '账户'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              ListTile(
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.surfaceSubtle,
                  child: const Icon(Icons.person_outline, size: 20, color: AppTheme.textSecondary),
                ),
                title: const Text('手机号'),
                subtitle: Text(authState.user?.phone ?? '未知'),
              ),
              const Divider(height: 1, color: AppTheme.dividerColor),
              ListTile(
                leading: const Icon(Icons.logout, size: 22, color: AppTheme.errorColor),
                title: Text('退出登录', style: const TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.w500)),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('退出登录'),
                      content: const Text('确定要退出登录吗？'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('退出'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref.read(authStateProvider.notifier).logout();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoTile({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _ProviderSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _ProviderSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text('提供商', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.textSecondary)),
          const Spacer(),
          _Chip(label: 'OpenAI', selected: value == 'openai', onTap: () => onChanged('openai')),
          const SizedBox(width: 8),
          _Chip(label: 'Anthropic', selected: value == 'anthropic', onTap: () => onChanged('anthropic')),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : AppTheme.surfaceSubtle,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
