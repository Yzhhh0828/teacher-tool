import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../widgets/confetti_button.dart';
import '../../widgets/shake.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrls = List.generate(6, (_) => TextEditingController());
  final _codeFocus = List.generate(6, (_) => FocusNode());
  bool _codeSent = false;
  int _shakeKey = 0;
  String? _lastError;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    for (final c in _codeCtrls) {
      c.dispose();
    }
    for (final f in _codeFocus) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _codeCtrls.map((c) => c.text).join();

  Future<void> _sendCode() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() {
        _lastError = '请输入手机号';
        _shakeKey++;
      });
      return;
    }
    await ref.read(authStateProvider.notifier).sendCode(phone);
    final st = ref.read(authStateProvider);
    if (mounted) {
      if (st.error == null) {
        setState(() => _codeSent = true);
        // Auto-fill debug code on web for convenience.
        if (st.debugCode != null && st.debugCode!.length == 6) {
          for (var i = 0; i < 6; i++) {
            _codeCtrls[i].text = st.debugCode![i];
          }
        }
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) _codeFocus[0].requestFocus();
      } else {
        setState(() {
          _lastError = st.error;
          _shakeKey++;
        });
      }
    }
  }

  Future<void> _login() async {
    final phone = _phoneCtrl.text.trim();
    final code = _code;
    if (phone.isEmpty || code.length != 6) {
      setState(() {
        _lastError = '请输入完整的 6 位验证码';
        _shakeKey++;
      });
      return;
    }

    await ref.read(authStateProvider.notifier).login(phone, code);
    if (!mounted) return;
    final st = ref.read(authStateProvider);
    if (st.isLoggedIn) {
      // Fire success animation + delegate routing to AuthWrapper.
      // ignore: unawaited_futures
      ConfettiAction.success(context, message: '登录成功');
    } else if (st.error != null) {
      setState(() {
        _lastError = st.error;
        _shakeKey++;
      });
    }
  }

  void _resetCode() {
    setState(() {
      _codeSent = false;
      _lastError = null;
      for (final c in _codeCtrls) {
        c.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = ref.watch(themeProvider).palette;
    final brightness = Theme.of(context).brightness;
    final auth = ref.watch(authStateProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Aurora gradient background
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppGradient.aurora(palette, brightness),
              ),
            ),
          ),
          // Decorative blurred orbs
          Positioned(
            top: -80,
            left: -60,
            child: _Orb(
              color: palette.accent1.withValues(alpha: 0.4),
              size: 260,
            ),
          ),
          Positioned(
            bottom: -100,
            right: -80,
            child: _Orb(
              color: palette.accent2.withValues(alpha: 0.35),
              size: 320,
            ),
          ),
          Positioned(
            top: 200,
            right: -50,
            child: _Orb(
              color: palette.tertiary.withValues(alpha: 0.30),
              size: 180,
            ),
          ),
          // Foreground content
          SafeArea(
            child: LayoutBuilder(
              builder: (ctx, c) {
                final wide = c.maxWidth >= 900;
                if (wide) {
                  return Row(
                    children: [
                      Expanded(child: _HeroPanel(palette: palette)),
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(AppSpacing.xxxl),
                            child: _LoginCard(
                              codeSent: _codeSent,
                              auth: auth,
                              phoneCtrl: _phoneCtrl,
                              codeCtrls: _codeCtrls,
                              codeFocus: _codeFocus,
                              shakeKey: _shakeKey,
                              error: _lastError,
                              onSend: _sendCode,
                              onLogin: _login,
                              onReset: _resetCode,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxl, vertical: AppSpacing.xxxl),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _HeroBadge(palette: palette, scheme: scheme)
                              .animate()
                              .scale(
                                  duration: AppMotion.long,
                                  curve: AppMotion.spring),
                          const SizedBox(height: AppSpacing.xxl),
                          _LoginCard(
                            codeSent: _codeSent,
                            auth: auth,
                            phoneCtrl: _phoneCtrl,
                            codeCtrls: _codeCtrls,
                            codeFocus: _codeFocus,
                            shakeKey: _shakeKey,
                            error: _lastError,
                            onSend: _sendCode,
                            onLogin: _login,
                            onReset: _resetCode,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Subwidgets ─────────────────────────────────────────────────────────────

class _HeroPanel extends StatelessWidget {
  final AppPalette palette;
  const _HeroPanel({required this.palette});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.huge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _HeroBadge(palette: palette, scheme: scheme)
              .animate()
              .scale(duration: AppMotion.long, curve: AppMotion.spring),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            '教师助手',
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
              letterSpacing: -1.5,
              height: 1.05,
            ),
          ).animate().fadeIn(duration: AppMotion.long).moveY(
                begin: 20,
                end: 0,
                duration: AppMotion.long,
                curve: AppMotion.emphasized,
              ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '让备课、组卷、点评、记录\n变得简单且充满乐趣',
            style: TextStyle(
              fontSize: 20,
              color: scheme.onSurface.withValues(alpha: 0.75),
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          )
              .animate(delay: const Duration(milliseconds: 200))
              .fadeIn(duration: AppMotion.long)
              .moveY(begin: 16, end: 0),
          const SizedBox(height: AppSpacing.xxxl),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _FeaturePill(
                  icon: Icons.smart_toy_rounded,
                  label: 'AI 助教',
                  color: palette.tertiary),
              _FeaturePill(
                  icon: Icons.bar_chart_rounded,
                  label: '智能分析',
                  color: palette.secondary),
              _FeaturePill(
                  icon: Icons.celebration_rounded,
                  label: '课堂互动',
                  color: palette.accent1),
              _FeaturePill(
                  icon: Icons.shuffle_rounded,
                  label: '随机点名',
                  color: palette.accent2),
            ]
                .animate(interval: const Duration(milliseconds: 80))
                .fadeIn(duration: AppMotion.medium)
                .moveX(begin: -12, end: 0),
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final AppPalette palette;
  final ColorScheme scheme;
  const _HeroBadge({required this.palette, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.seed, palette.tertiary, palette.accent3],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.tinted(palette.seed),
      ),
      child: const Icon(Icons.auto_awesome,
          color: Colors.white, size: 44),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(
          begin: -4,
          end: 4,
          duration: const Duration(milliseconds: 2400),
          curve: Curves.easeInOutSine,
        );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _FeaturePill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.30)),
        boxShadow: AppShadow.tinted(color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  const _Orb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(0.95, 0.95),
            end: const Offset(1.05, 1.05),
            duration: const Duration(milliseconds: 4000),
            curve: Curves.easeInOutSine,
          ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  final bool codeSent;
  final AuthState auth;
  final TextEditingController phoneCtrl;
  final List<TextEditingController> codeCtrls;
  final List<FocusNode> codeFocus;
  final int shakeKey;
  final String? error;
  final VoidCallback onSend;
  final VoidCallback onLogin;
  final VoidCallback onReset;

  const _LoginCard({
    required this.codeSent,
    required this.auth,
    required this.phoneCtrl,
    required this.codeCtrls,
    required this.codeFocus,
    required this.shakeKey,
    required this.error,
    required this.onSend,
    required this.onLogin,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Shake(
      trigger: shakeKey,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5)),
          boxShadow: AppShadow.floating(scheme.shadow),
        ),
        child: AnimatedSize(
          duration: AppMotion.medium,
          curve: AppMotion.emphasized,
          child: AnimatedSwitcher(
            duration: AppMotion.medium,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0.06, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: codeSent
                ? _CodeStep(
                    key: const ValueKey('code'),
                    auth: auth,
                    codeCtrls: codeCtrls,
                    codeFocus: codeFocus,
                    error: error,
                    onLogin: onLogin,
                    onReset: onReset,
                  )
                : _PhoneStep(
                    key: const ValueKey('phone'),
                    auth: auth,
                    phoneCtrl: phoneCtrl,
                    error: error,
                    onSend: onSend,
                  ),
          ),
        ),
      ),
    );
  }
}

class _PhoneStep extends StatelessWidget {
  final AuthState auth;
  final TextEditingController phoneCtrl;
  final String? error;
  final VoidCallback onSend;

  const _PhoneStep({
    super.key,
    required this.auth,
    required this.phoneCtrl,
    required this.error,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('欢迎回来 👋',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            )),
        const SizedBox(height: AppSpacing.sm),
        Text('用手机号登录，开启今日的精彩教学',
            style: TextStyle(
              fontSize: 14,
              color: scheme.onSurfaceVariant,
            )),
        const SizedBox(height: AppSpacing.xxl),
        TextField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          decoration: const InputDecoration(
            labelText: '手机号',
            hintText: '请输入 11 位手机号',
            prefixIcon: Icon(Icons.phone_iphone_rounded),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (error != null)
          _ErrorBanner(message: error!).animate().fadeIn(),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: auth.isLoading ? null : onSend,
            icon: auth.isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: const Text('发送验证码'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg)),
              textStyle: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _CodeStep extends StatelessWidget {
  final AuthState auth;
  final List<TextEditingController> codeCtrls;
  final List<FocusNode> codeFocus;
  final String? error;
  final VoidCallback onLogin;
  final VoidCallback onReset;

  const _CodeStep({
    super.key,
    required this.auth,
    required this.codeCtrls,
    required this.codeFocus,
    required this.error,
    required this.onLogin,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('输入验证码',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            )),
        const SizedBox(height: AppSpacing.sm),
        Text('我们已向你的手机发送 6 位验证码',
            style: TextStyle(
                fontSize: 14, color: scheme.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.xl),
        if (auth.debugCode != null)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm + 2,
                horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                  color: scheme.tertiary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt_rounded,
                    color: scheme.tertiary, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Text('开发调试码：',
                    style: TextStyle(
                        color: scheme.onSurface, fontSize: 13)),
                Text(auth.debugCode!,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.tertiary,
                      letterSpacing: 4,
                    )),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) {
            return Flexible(
              child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: i == 0 || i == 5 ? 0 : 4),
                child: _CodeBox(
                  controller: codeCtrls[i],
                  focusNode: codeFocus[i],
                  onChanged: (v) {
                    if (v.length == 1 && i < 5) {
                      codeFocus[i + 1].requestFocus();
                    } else if (v.isEmpty && i > 0) {
                      codeFocus[i - 1].requestFocus();
                    }
                    final allFilled =
                        codeCtrls.every((c) => c.text.isNotEmpty);
                    if (allFilled) onLogin();
                  },
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (error != null)
          _ErrorBanner(message: error!).animate().fadeIn(),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: auth.isLoading ? null : onLogin,
            icon: auth.isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.login_rounded, size: 18),
            label: const Text('登录'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg)),
              textStyle: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.arrow_back_rounded, size: 16),
          label: const Text('返回修改手机号'),
        ),
      ],
    );
  }
}

class _CodeBox extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _CodeBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  State<_CodeBox> createState() => _CodeBoxState();
}

class _CodeBoxState extends State<_CodeBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: AppMotion.micro,
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    widget.focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _hasFocus = widget.focusNode.hasFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    if (v.isNotEmpty) {
      _scaleCtrl.forward().then((_) => _scaleCtrl.reverse());
    }
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedScale(
      scale: _hasFocus ? 1.08 : 1.0,
      duration: AppMotion.short,
      curve: AppMotion.standard,
      child: AnimatedContainer(
        duration: AppMotion.short,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: _hasFocus
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: ScaleTransition(
          scale: Tween(begin: 1.0, end: 1.12).animate(
            CurvedAnimation(parent: _scaleCtrl, curve: AppMotion.standard),
          ),
          child: SizedBox(
            width: 48,
            height: 56,
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                counterText: '',
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: scheme.primary, width: 2),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _onChanged,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              color: scheme.error, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    color: scheme.onErrorContainer,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
