import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../providers/theme_provider.dart';

/// Compact theme controller — tap = light/dark/system rotation,
/// long-press / dropdown arrow = palette picker.
class ThemeToggleButton extends ConsumerWidget {
  /// Visual size variant. Default 40 fits an AppBar; rail uses 44.
  final double size;

  const ThemeToggleButton({super.key, this.size = 40});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final prefs = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);

    final modeIcon = switch (prefs.mode) {
      ThemeMode.light => Icons.light_mode_outlined,
      ThemeMode.dark => Icons.dark_mode_outlined,
      ThemeMode.system => Icons.brightness_auto_outlined,
    };
    final modeLabel = switch (prefs.mode) {
      ThemeMode.light => '浅色',
      ThemeMode.dark => '深色',
      ThemeMode.system => '跟随系统',
    };

    return Tooltip(
      message: '主题：$modeLabel · 长按选择配色',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: notifier.toggleMode,
        onLongPress: () => _showPalettePicker(context, ref),
        child: Container(
          height: size,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
                color: scheme.primary.withValues(alpha: 0.20)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(modeIcon, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _showPalettePicker(context, ref),
                child: Icon(Icons.palette_outlined,
                    size: 16, color: scheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPalettePicker(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(themeProvider.notifier);
    final current = ref.read(themeProvider).palette;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('外观',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.md),
                _ModeRow(),
                const SizedBox(height: AppSpacing.lg),
                Text('配色',
                    style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 0.4)),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: AppPalette.all.map((p) {
                    final selected = p.name == current.name;
                    return InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      onTap: () {
                        notifier.setPalette(p);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? p.seed.withValues(alpha: 0.12)
                              : scheme.surfaceContainerHighest,
                          borderRadius:
                              BorderRadius.circular(AppRadius.lg),
                          border: Border.all(
                              color: selected
                                  ? p.seed
                                  : scheme.outlineVariant),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                  color: p.seed, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(_paletteLabel(p.name),
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface)),
                            if (selected) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.check,
                                  size: 16, color: p.seed),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _paletteLabel(String name) {
    return switch (name) {
      'warmOrange' => '暖橙',
      'mellardGreen' => '莫兰迪绿',
      _ => name,
    };
  }
}

class _ModeRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final mode = ref.watch(themeProvider).mode;
    final notifier = ref.read(themeProvider.notifier);
    Widget chip(ThemeMode value, IconData icon, String label) {
      final selected = mode == value;
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: ChoiceChip(
          avatar: Icon(icon,
              size: 16,
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant),
          label: Text(label),
          selected: selected,
          onSelected: (_) => notifier.setMode(value),
        ),
      );
    }

    return Row(
      children: [
        chip(ThemeMode.light, Icons.light_mode_outlined, '浅色'),
        chip(ThemeMode.dark, Icons.dark_mode_outlined, '深色'),
        chip(ThemeMode.system, Icons.brightness_auto_outlined, '跟随系统'),
      ],
    );
  }
}
