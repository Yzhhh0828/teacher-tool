import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../data/models/class_model.dart';
import '../../providers/class_provider.dart';
import '../../providers/theme_provider.dart';
import 'confetti_button.dart';
import 'shimmer_skeleton.dart';

/// 侧栏顶部的「当前班级」按钮。
///
/// - `compact = true`：仅显示头像（窄轨）
/// - `compact = false`：头像 + 名称 + 年级 chip + 下拉箭头
class ClassSwitcherHeader extends ConsumerWidget {
  final bool compact;
  const ClassSwitcherHeader({super.key, required this.compact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final palette = ref.watch(themeProvider).palette;
    final accent = AppAccent(palette).classes;
    final current = ref.watch(currentClassProvider);
    final initial = (current?.name.trim().isNotEmpty ?? false)
        ? current!.name.trim().substring(0, 1)
        : '+';
    final hasClass = current != null;

    final avatar = Container(
      width: compact ? 40 : 36,
      height: compact ? 40 : 36,
      decoration: BoxDecoration(
        gradient: hasClass
            ? AppGradient.accent(accent, Theme.of(context).brightness)
            : null,
        color: hasClass ? null : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.s),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: compact ? 18 : 16,
          fontWeight: FontWeight.w800,
          color: hasClass ? Colors.white : scheme.onSurfaceVariant,
        ),
      ),
    );

    final body = compact
        ? avatar
        : Row(
            children: [
              avatar,
              const SizedBox(width: AppSpacing.gap3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasClass ? current.name : '未选择班级',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                        letterSpacing: -0.1,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasClass ? '${current.grade}年级 · 切换' : '点击新建或加入',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.unfold_more_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          );

    return Tooltip(
      message: hasClass
          ? '${current.name} · 点击切换班级'
          : '新建或加入班级',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.m),
          onTap: () => showClassSwitcherSheet(context, ref),
          child: AnimatedContainer(
            duration: AppMotion.short,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : AppSpacing.gap3,
              vertical: compact ? 8 : AppSpacing.gap2,
            ),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.m),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: body,
          ),
        ),
      ),
    );
  }
}

/// 弹出班级切换器（弹窗 = 列表 + 新建 / 加入 + 当前班级 overflow 操作）。
Future<void> showClassSwitcherSheet(
    BuildContext context, WidgetRef ref) async {
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (ctx) => const _ClassSwitcherDialog(),
  );
}

class _ClassSwitcherDialog extends ConsumerStatefulWidget {
  const _ClassSwitcherDialog();
  @override
  ConsumerState<_ClassSwitcherDialog> createState() =>
      _ClassSwitcherDialogState();
}

class _ClassSwitcherDialogState extends ConsumerState<_ClassSwitcherDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = ref.watch(themeProvider).palette;
    final accent = AppAccent(palette).classes;
    final classesAsync = ref.watch(classListProvider);
    final current = ref.watch(currentClassProvider);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gap5, vertical: AppSpacing.gap6),
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── header ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gap5, AppSpacing.gap5, AppSpacing.gap3, AppSpacing.gap3),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.s),
                    ),
                    child: Icon(Icons.school_rounded, color: accent, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.gap3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '切换班级',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '所有功能模块都基于当前班级',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // ── search ─────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gap5),
              child: TextField(
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: '搜索班级名',
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.s),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.gap3),
            // ── list ───────────────────────────────
            Expanded(
              child: classesAsync.when(
                loading: () =>
                    ShimmerSkeleton.list(itemCount: 3, itemHeight: 56),
                error: (e, _) =>
                    Center(child: Text('加载失败：$e', textAlign: TextAlign.center)),
                data: (all) {
                  final classes = all
                      .where((c) =>
                          _query.isEmpty ||
                          c.name.toLowerCase().contains(_query))
                      .toList();
                  if (classes.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.gap5),
                        child: Text(
                          all.isEmpty ? '还没有任何班级，新建一个吧' : '没有匹配的班级',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.gap5),
                    itemCount: classes.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.gap2),
                    itemBuilder: (ctx, i) {
                      final cls = classes[i];
                      final selected = current?.id == cls.id;
                      return _ClassRow(
                        cls: cls,
                        selected: selected,
                        accent: accent,
                        onTap: () {
                          ref.read(currentClassProvider.notifier).select(cls);
                          Navigator.pop(context);
                        },
                        onMore: () => _showClassActions(context, ref, cls),
                      );
                    },
                  );
                },
              ),
            ),
            // ── actions ────────────────────────────
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.gap4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.group_add_rounded, size: 18),
                      label: const Text('加入班级'),
                      onPressed: () {
                        Navigator.pop(context);
                        showJoinClassDialog(context, ref);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.gap3),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('新建班级'),
                      onPressed: () {
                        Navigator.pop(context);
                        showCreateClassDialog(context, ref);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showClassActions(
      BuildContext context, WidgetRef ref, ClassModel cls) async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_rounded),
              title: const Text('生成邀请码'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await _showInviteCode(context, ref, cls);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_rounded),
              title: const Text('成员管理'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _showMembersDialog(context, ref, cls);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.redAccent),
              title: const Text('删除班级',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await _confirmDelete(context, ref, cls);
              },
            ),
            const SizedBox(height: AppSpacing.gap3),
          ],
        ),
      ),
    );
  }

  Future<void> _showInviteCode(
      BuildContext context, WidgetRef ref, ClassModel cls) async {
    try {
      final repo = ref.read(classRepositoryProvider);
      final code = await repo.createInviteCode(cls.id);
      if (!context.mounted) return;
      final scheme = Theme.of(context).colorScheme;
      final accent = AppAccent(ref.read(themeProvider).palette).classes;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${cls.name} · 邀请码'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.gap5,
                    horizontal: AppSpacing.gap4),
                decoration: AppSurface.tinted(ctx, accent,
                    radius: AppRadius.m, alpha: 0.10),
                child: Text(
                  code,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    letterSpacing: 4,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.gap3),
              Text(
                '将邀请码分享给其他老师即可加入此班级',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('关闭')),
            FilledButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('复制'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('邀请码已复制')),
                );
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('生成邀请码失败：$e')));
      }
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, ClassModel cls) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除班级？'),
        content: Text('"${cls.name}" 将被永久删除，相关数据无法恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(classListProvider.notifier).deleteClass(cls.id);
      if (ref.read(currentClassProvider)?.id == cls.id) {
        await ref.read(currentClassProvider.notifier).select(null);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已删除：${cls.name}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败：$e')));
      }
    }
  }

  void _showMembersDialog(
      BuildContext context, WidgetRef ref, ClassModel cls) {
    showDialog(
      context: context,
      builder: (ctx) => _MembersDialog(classId: cls.id, className: cls.name),
    );
  }
}

class _MembersDialog extends ConsumerStatefulWidget {
  final int classId;
  final String className;
  const _MembersDialog({required this.classId, required this.className});

  @override
  ConsumerState<_MembersDialog> createState() => _MembersDialogState();
}

class _MembersDialogState extends ConsumerState<_MembersDialog> {
  List<Map<String, dynamic>>? _members;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final repo = ref.read(classRepositoryProvider);
      final members = await repo.getMembers(widget.classId);
      if (mounted) setState(() => _members = members);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _removeMember(int memberId) async {
    try {
      final repo = ref.read(classRepositoryProvider);
      await repo.removeMember(widget.classId, memberId);
      await _loadMembers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('移除失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget body;
    if (_error != null) {
      body = Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text('加载失败：$_error'),
      );
    } else if (_members == null) {
      body = const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_members!.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Text('暂无成员'),
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: _members!.map((m) {
          final role = m['role'] as String? ?? 'teacher';
          final subject = m['subject'] as String?;
          final isOwner = role == 'owner';
          return ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: isOwner
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              child: Icon(
                isOwner ? Icons.star_rounded : Icons.person_rounded,
                size: 18,
                color: isOwner ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
              ),
            ),
            title: Text(
              isOwner ? '班主' : '教师',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text([
              '用户 #${m['user_id']}',
              if (subject != null && subject.isNotEmpty) subject,
            ].join(' · ')),
            trailing: isOwner
                ? null
                : IconButton(
                    icon: const Icon(Icons.person_remove_rounded, size: 20),
                    color: scheme.error,
                    tooltip: '移除',
                    onPressed: () => _removeMember(m['id'] as int),
                  ),
          );
        }).toList(),
      );
    }

    return AlertDialog(
      title: Text('${widget.className} · 成员'),
      content: SizedBox(width: 320, child: body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

class _ClassRow extends StatelessWidget {
  final ClassModel cls;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onMore;
  const _ClassRow({
    required this.cls,
    required this.selected,
    required this.accent,
    required this.onTap,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = cls.name.trim().isEmpty
        ? '班'
        : cls.name.trim().substring(0, 1);
    return Material(
      color: selected
          ? accent.withValues(alpha: 0.10)
          : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.m),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.gap3, vertical: AppSpacing.gap3),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppGradient.accent(
                      accent, Theme.of(context).brightness),
                  borderRadius: BorderRadius.circular(AppRadius.s),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.gap3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cls.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${cls.grade}年级',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: const Text(
                    '当前',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.more_horiz_rounded),
                tooltip: '更多',
                onPressed: onMore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 共享对话框：新建 / 加入 ─────────────────────────────────────────────────

void showCreateClassDialog(BuildContext context, WidgetRef ref) {
  final nameCtrl = TextEditingController();
  final gradeCtrl = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('新建班级'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '班级名称',
              prefixIcon: Icon(Icons.school_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.gap4),
          TextField(
            controller: gradeCtrl,
            decoration: const InputDecoration(
              labelText: '年级',
              prefixIcon: Icon(Icons.grade_rounded),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton.icon(
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('创建'),
          onPressed: () async {
            final name = nameCtrl.text.trim();
            final grade = gradeCtrl.text.trim();
            if (name.isEmpty) return;
            try {
              await ref
                  .read(classListProvider.notifier)
                  .createClass(name, grade);
              // auto-select the freshly created class (latest match by name).
              final all = ref.read(classListProvider).maybeWhen(
                  data: (l) => l, orElse: () => const <ClassModel>[]);
              ClassModel? fresh;
              for (final c in all) {
                if (c.name == name) fresh = c;
              }
              fresh ??= all.isNotEmpty ? all.last : null;
              if (fresh != null) {
                await ref.read(currentClassProvider.notifier).select(fresh);
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
                // ignore: unawaited_futures
                ConfettiAction.celebrate(context, message: '班级创建成功！');
              }
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('创建班级失败：$e')));
              }
            }
          },
        ),
      ],
    ),
  );
}

void showJoinClassDialog(BuildContext context, WidgetRef ref) {
  final codeCtrl = TextEditingController();
  final subjectCtrl = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('加入班级'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: codeCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '邀请码',
              prefixIcon: Icon(Icons.qr_code_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.gap4),
          TextField(
            controller: subjectCtrl,
            decoration: const InputDecoration(
              labelText: '教授科目',
              prefixIcon: Icon(Icons.menu_book_rounded),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(
          onPressed: () async {
            try {
              final repo = ref.read(classRepositoryProvider);
              await repo.joinClass(
                codeCtrl.text.trim(),
                subjectCtrl.text.trim(),
              );
              await ref.read(classListProvider.notifier).loadClasses();
              if (ctx.mounted) {
                Navigator.pop(ctx);
                // ignore: unawaited_futures
                ConfettiAction.success(context, message: '已加入班级');
              }
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('加入班级失败：$e')));
              }
            }
          },
          child: const Text('加入'),
        ),
      ],
    ),
  );
}
