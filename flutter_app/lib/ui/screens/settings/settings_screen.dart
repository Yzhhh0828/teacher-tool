import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/tokens.dart';
import '../../../providers/agent_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _baseUrlCtrl;
  late TextEditingController _modelCtrl;
  String _provider = 'openai';
  bool _obscureKey = true;
  bool _saving = false;
  bool _testing = false;
  ({bool ok, String message})? _testResult;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _provider = s.provider;
    final p = s.profileFor(_provider);
    _apiKeyCtrl = TextEditingController(text: p.apiKey);
    _baseUrlCtrl = TextEditingController(text: p.baseUrl);
    _modelCtrl = TextEditingController(text: p.model);
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _baseUrlCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  void _switchProvider(String name) {
    if (name == _provider) return;
    final s = ref.read(settingsProvider);
    final p = s.profileFor(name);
    setState(() {
      _provider = name;
      _apiKeyCtrl.text = p.apiKey;
      _baseUrlCtrl.text = p.baseUrl;
      _modelCtrl.text = p.model;
      _testResult = null;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(settingsProvider.notifier).save(
          provider: _provider,
          apiKey: _apiKeyCtrl.text.trim(),
          baseUrl: _baseUrlCtrl.text.trim(),
          model: _modelCtrl.text.trim(),
        );
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存，下次 AI 请求即刻生效')),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final headers = <String, String>{
      'X-LLM-Provider': _provider,
      if (_apiKeyCtrl.text.trim().isNotEmpty) 'X-API-Key': _apiKeyCtrl.text.trim(),
      if (_baseUrlCtrl.text.trim().isNotEmpty) 'X-Base-URL': _baseUrlCtrl.text.trim(),
      if (_modelCtrl.text.trim().isNotEmpty) 'X-LLM-Model': _modelCtrl.text.trim(),
    };
    try {
      final r = await ref
          .read(agentRepositoryProvider)
          .testConnection(llmHeaders: headers);
      if (!mounted) return;
      final ok = r['ok'] == true;
      setState(() {
        _testResult = (
          ok: ok,
          message: ok
              ? '连接成功 · 模型回复："${r['reply'] ?? ''}"'
              : '连接失败 · ${r['error'] ?? '未知错误'}',
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _testResult = (ok: false, message: '请求失败：$e'));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final scheme = Theme.of(context).colorScheme;
    final defaults = LlmSettings.defaults[_provider]!;
    final isOllama = _provider == 'ollama';

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        automaticallyImplyLeading: false,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const _SectionHeader(title: 'AI 模型配置'),
          const SizedBox(height: AppSpacing.sm),
          _SettingsCard(
            children: [
              _ProviderSelector(value: _provider, onChanged: _switchProvider),
              Divider(height: 1, color: scheme.outlineVariant),
              if (!isOllama) ...[
                _LabelledField(
                  label: 'API Key',
                  hint: 'sk-...',
                  controller: _apiKeyCtrl,
                  obscure: _obscureKey,
                  monospace: true,
                  trailing: IconButton(
                    icon: Icon(
                      _obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  ),
                ),
                Divider(height: 1, color: scheme.outlineVariant),
              ],
              _LabelledField(
                label: isOllama ? 'Ollama 地址' : 'Base URL（可选，用于代理）',
                hint: defaults.baseUrl,
                controller: _baseUrlCtrl,
              ),
              Divider(height: 1, color: scheme.outlineVariant),
              _LabelledField(
                label: '模型',
                hint: defaults.model,
                controller: _modelCtrl,
                monospace: true,
              ),
              Divider(height: 1, color: scheme.outlineVariant),
              if (_testResult != null)
                _TestResultBanner(ok: _testResult!.ok, message: _testResult!.message),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _testing || _saving ? null : _testConnection,
                        icon: _testing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.network_check_rounded, size: 18),
                        label: const Text('测试连接'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving || _testing ? null : _save,
                        icon: _saving
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.save_rounded, size: 18),
                        label: const Text('保存配置'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const _InfoTile(
            icon: Icons.lock_outline_rounded,
            text: '凭证以加密形式保存在本设备，随每次 AI 请求发送至后端覆盖服务端默认配置。',
          ),
          const SizedBox(height: AppSpacing.xxl),
          const _SectionHeader(title: '外观'),
          const SizedBox(height: AppSpacing.sm),
          const _AppearanceCard(),
          const SizedBox(height: AppSpacing.xxl),
          const _SectionHeader(title: '账户'),
          const SizedBox(height: AppSpacing.sm),
          _SettingsCard(
            children: [
              ListTile(
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: scheme.surfaceContainerHighest,
                  child: Icon(Icons.person_outline, size: 20, color: scheme.onSurfaceVariant),
                ),
                title: const Text('手机号'),
                subtitle: Text(authState.user?.phone ?? '未知'),
              ),
              Divider(height: 1, color: scheme.outlineVariant),
              ListTile(
                leading: Icon(Icons.logout_rounded, size: 22, color: scheme.error),
                title: Text(
                  '退出登录',
                  style: TextStyle(color: scheme.error, fontWeight: FontWeight.w500),
                ),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('退出登录'),
                      content: const Text('确定要退出登录吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: scheme.error),
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
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(children: children),
    );
  }
}

class _LabelledField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final bool monospace;
  final Widget? trailing;
  const _LabelledField({
    required this.label,
    required this.hint,
    required this.controller,
    this.obscure = false,
    this.monospace = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: obscure,
            style: TextStyle(
              fontFamily: monospace ? 'monospace' : null,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
              suffixIcon: trailing,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide(color: scheme.primary, width: 1.5),
              ),
              filled: true,
              fillColor: scheme.surface,
            ),
          ),
        ],
      ),
    );
  }
}

class _TestResultBanner extends StatelessWidget {
  final bool ok;
  final String message;
  const _TestResultBanner({required this.ok, required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = ok ? Colors.green.shade600 : scheme.error;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle_outline : Icons.error_outline, color: color, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoTile({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(themeProvider);
    final scheme = Theme.of(context).colorScheme;
    return _SettingsCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
              AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
          child: Text('主题色板',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: Row(
            children: [
              for (var i = 0; i < AppPalette.all.length; i++) ...[
                Expanded(
                  child: _PaletteSwatch(
                    palette: AppPalette.all[i],
                    selected:
                        prefs.palette.name == AppPalette.all[i].name,
                    onTap: () => ref
                        .read(themeProvider.notifier)
                        .setPalette(AppPalette.all[i]),
                  ),
                ),
                if (i < AppPalette.all.length - 1)
                  const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Divider(height: 1, color: scheme.outlineVariant),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
              AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
          child: Text('明暗模式',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: Center(
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('浅色'),
                    icon: Icon(Icons.light_mode_rounded)),
                ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('跟随系统'),
                    icon: Icon(Icons.brightness_auto_rounded)),
                ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('深色'),
                    icon: Icon(Icons.dark_mode_rounded)),
              ],
              selected: {prefs.mode},
              onSelectionChanged: (s) => ref
                  .read(themeProvider.notifier)
                  .setMode(s.first),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _PaletteSwatch extends StatelessWidget {
  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  const _PaletteSwatch({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: AppMotion.short,
      curve: AppMotion.standard,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2.5 : 1,
        ),
        boxShadow: selected ? AppShadow.tinted(palette.seed) : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        palette.seed,
                        palette.tertiary,
                        palette.accent3,
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(AppRadius.md),
                  ),
                  child: selected
                      ? const Center(
                          child: Icon(Icons.check_rounded,
                              color: Colors.white, size: 28),
                        )
                            .animate()
                            .scale(
                              begin: const Offset(0, 0),
                              end: const Offset(1, 1),
                              duration: AppMotion.short,
                              curve: AppMotion.spring,
                            )
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: palette.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: palette.accent1,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: palette.accent2,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  palette.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                        selected ? scheme.primary : scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _ProviderSelector({required this.value, required this.onChanged});

  static const _options = [
    (id: 'openai', label: 'OpenAI', icon: Icons.bolt_rounded),
    (id: 'anthropic', label: 'Anthropic', icon: Icons.auto_awesome_rounded),
    (id: 'ollama', label: 'Ollama', icon: Icons.devices_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '提供商',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const Spacer(),
          ..._options.expand((opt) => [
                _ProviderChip(
                  icon: opt.icon,
                  label: opt.label,
                  selected: value == opt.id,
                  onTap: () => onChanged(opt.id),
                ),
                const SizedBox(width: 6),
              ]).toList()
            ..removeLast(),
        ],
      ),
    );
  }
}

class _ProviderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ProviderChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
