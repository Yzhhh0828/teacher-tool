import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../data/models/seating.dart';
import '../../../data/models/student.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/seating_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../widgets/confetti_button.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/shimmer_skeleton.dart';
import 'seating_export.dart';

// ─── Undo stack kept in-memory ──────────────────────────────────────────────

typedef _Grid = List<List<int?>>;

_Grid _cloneGrid(_Grid g) => g.map((r) => List<int?>.from(r)).toList();

class SeatingScreen extends ConsumerStatefulWidget {
  const SeatingScreen({super.key});

  @override
  ConsumerState<SeatingScreen> createState() => _SeatingScreenState();
}

class _SeatingScreenState extends ConsumerState<SeatingScreen> {
  // Local editing state
  _Grid? _localSeats;
  final List<_Grid> _undoStack = [];
  bool _dirty = false;
  bool _saving = false;
  bool _exporting = false;
  // Boundary for PNG export — wraps the on-screen seating grid.
  final GlobalKey _exportBoundaryKey = GlobalKey();

  void _pushUndo() {
    if (_localSeats != null) {
      _undoStack.add(_cloneGrid(_localSeats!));
      if (_undoStack.length > 30) _undoStack.removeAt(0);
    }
  }

  void _undo() {
    if (_undoStack.isEmpty || _localSeats == null) return;
    setState(() {
      _localSeats = _undoStack.removeLast();
      _dirty = true;
    });
  }

  void _syncFromServer(SeatingModel seating) {
    if (!_dirty) {
      _localSeats = _cloneGrid(seating.seats);
    }
  }

  Future<void> _saveToServer(int classId) async {
    if (_localSeats == null || !_dirty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(seatingProvider(classId).notifier)
          .saveSeats(_localSeats!);
      _dirty = false;
      _undoStack.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('座位已保存'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = ref.watch(themeProvider).palette;
    final accent = AppAccent(palette).seating;
    final currentClass = ref.watch(currentClassProvider);

    if (currentClass == null) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          title: const Text('座位管理'),
          automaticallyImplyLeading: false,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        body: EmptyView(
          icon: Icons.grid_view_rounded,
          title: '请先选择班级',
          message: '前往「班级」标签选择一个班级再来吧',
          accent: accent,
        ),
      );
    }

    final seatingAsync = ref.watch(seatingProvider(currentClass.id));
    final studentsAsync = ref.watch(studentListProvider(currentClass.id));

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('座位管理'),
        automaticallyImplyLeading: false,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_undoStack.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo_rounded),
              tooltip: '撤销',
              onPressed: _undo,
            ),
          if (_dirty)
            IconButton(
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_rounded),
              tooltip: '保存',
              onPressed:
                  _saving ? null : () => _saveToServer(currentClass.id),
            ),
          IconButton(
            icon: const Icon(Icons.shuffle_rounded),
            tooltip: '随机排座',
            onPressed: () => _confirmShuffle(context, currentClass.id),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: '更多',
            onSelected: (v) {
              switch (v) {
                case 'grid':
                  _showGridSizeDialog(context, currentClass.id);
                case 'save_layout':
                  _saveAsLayout(context, currentClass.id);
                case 'load_layout':
                  _showLayoutPicker(context, currentClass.id);
                case 'export_png':
                  _exportPng(currentClass.name);
                case 'export_pdf':
                  _exportPdfAndPrint(currentClass.name);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'grid',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.grid_on_rounded, size: 20),
                  title: Text('调整行列'),
                ),
              ),
              PopupMenuItem(
                value: 'save_layout',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.bookmark_add_outlined, size: 20),
                  title: Text('保存为方案'),
                ),
              ),
              PopupMenuItem(
                value: 'load_layout',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.folder_open_rounded, size: 20),
                  title: Text('加载方案'),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'export_png',
                child: ListTile(
                  key: ValueKey('seating-export-png'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.image_outlined, size: 20),
                  title: Text('导出 PNG 图片'),
                ),
              ),
              PopupMenuItem(
                value: 'export_pdf',
                child: ListTile(
                  key: ValueKey('seating-export-pdf'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.picture_as_pdf_outlined, size: 20),
                  title: Text('导出 PDF / 打印'),
                ),
              ),
            ],
          ),
          if (_exporting)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.gap2),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          const SizedBox(width: AppSpacing.gap2),
        ],
      ),
      body: seatingAsync.when(
        loading: () => ShimmerSkeleton.grid(crossAxisCount: 4, itemCount: 12),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (seating) {
          _syncFromServer(seating);
          return studentsAsync.when(
            loading: () => ShimmerSkeleton.grid(crossAxisCount: 4, itemCount: 12),
            error: (e, _) => Center(child: Text('加载失败：$e')),
            data: (students) => _buildGrid(
                context, scheme, accent, seating, students, currentClass.id),
          );
        },
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    ColorScheme scheme,
    Color accent,
    SeatingModel seating,
    List<Student> students,
    int classId,
  ) {
    final studentMap = {for (var s in students) s.id: s};
    final brightness = Theme.of(context).brightness;
    final seats = _localSeats ?? seating.seats;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: RepaintBoundary(
        key: _exportBoundaryKey,
        child: Container(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
        children: [
          // Teacher's podium
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(
                AppSpacing.gap6, 0, AppSpacing.gap6, AppSpacing.gap4),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: AppGradient.accent(accent, brightness),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.l),
                topRight: Radius.circular(AppRadius.l),
                bottomLeft: Radius.circular(AppRadius.s),
                bottomRight: Radius.circular(AppRadius.s),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.school_rounded,
                    color: Colors.white, size: 18),
                SizedBox(width: AppSpacing.gap2),
                Text(
                  '讲台',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Colors.white,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: AppMotion.short)
              .moveY(begin: -6, end: 0),
          const SizedBox(height: AppSpacing.gap4),
          // Seats grid with drag-and-drop
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: seating.cols,
              childAspectRatio: 1.05,
              crossAxisSpacing: AppSpacing.gap2,
              mainAxisSpacing: AppSpacing.gap2,
            ),
            itemCount: seating.rows * seating.cols,
            itemBuilder: (context, index) {
              final row = index ~/ seating.cols;
              final col = index % seating.cols;
              final studentId =
                  (row < seats.length && col < seats[row].length)
                      ? seats[row][col]
                      : null;
              final student =
                  studentId != null ? studentMap[studentId] : null;

              return _DraggableSeat(
                row: row,
                col: col,
                student: student,
                accent: accent,
                onAcceptDrop: (srcRow, srcCol) {
                  _pushUndo();
                  setState(() {
                    // Swap
                    final tmp = _localSeats![row][col];
                    _localSeats![row][col] = _localSeats![srcRow][srcCol];
                    _localSeats![srcRow][srcCol] = tmp;
                    _dirty = true;
                  });
                },
                onDragStarted: (r, c) {},
                onTap: () => _showSeatAssignmentDialog(
                    context, classId, row, col, studentId, students),
              );
            },
          ),
          if (_dirty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.gap4),
              child: Text(
                '有未保存的变更',
                style: TextStyle(
                  color: scheme.tertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
          ),
        ),
      ),
    );
  }

  // ── Export ──

  Future<void> _exportPng(String className) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      // Wait one frame so any pending layout settles before capture.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final png = await SeatingExporter.capturePng(_exportBoundaryKey);
      final dateStr = _filenameDate(DateTime.now());
      await SeatingExporter.sharePng(
        png,
        filename: '${className}_座位表_$dateStr.png',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('座位 PNG 已导出')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportPdfAndPrint(String className) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final seating = ref.read(seatingProvider(
              ref.read(currentClassProvider)!.id))
          .valueOrNull;
      final students = ref
              .read(studentListProvider(
                  ref.read(currentClassProvider)!.id))
              .valueOrNull ??
          const [];
      if (seating == null) {
        throw StateError('座位数据未加载');
      }
      final names = {for (var s in students) s.id: s.name};
      final genders = {for (var s in students) s.id: s.gender};
      final pdf = await SeatingExporter.buildPdf(
        className: className,
        date: DateTime.now(),
        rows: seating.rows,
        cols: seating.cols,
        seats: _localSeats ?? seating.seats,
        studentNames: names,
        studentGenders: genders,
      );
      await SeatingExporter.printPdf(
        pdf,
        name: '${className}_座位表_${_filenameDate(DateTime.now())}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _filenameDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Dialogs ──

  Future<void> _confirmShuffle(BuildContext context, int classId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认随机排座'),
        content: const Text('确定要随机打乱所有座位吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('随机')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ref.read(seatingProvider(classId).notifier).shuffleSeats();
        _dirty = false;
        _undoStack.clear();
        _localSeats = null;
        if (mounted) {
          ConfettiAction.celebrate(context, message: '座位已洗牌');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('随机排座失败：$e')),
          );
        }
      }
    }
  }

  void _showGridSizeDialog(BuildContext context, int classId) {
    int rows = 6;
    int cols = 8;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: const Text('设置座位布局'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('行数 '),
                  Expanded(
                    child: Slider(
                      value: rows.toDouble(),
                      min: 2, max: 10, divisions: 8,
                      label: rows.toString(),
                      onChanged: (v) => setSt(() => rows = v.round()),
                    ),
                  ),
                  Text('$rows',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              Row(
                children: [
                  const Text('列数 '),
                  Expanded(
                    child: Slider(
                      value: cols.toDouble(),
                      min: 2, max: 10, divisions: 8,
                      label: cols.toString(),
                      onChanged: (v) => setSt(() => cols = v.round()),
                    ),
                  ),
                  Text('$cols',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await ref
                      .read(seatingProvider(classId).notifier)
                      .createSeating(rows, cols);
                  _dirty = false;
                  _localSeats = null;
                  _undoStack.clear();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('创建座位布局失败：$e')),
                    );
                  }
                }
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveAsLayout(BuildContext context, int classId) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('保存为方案'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '方案名称'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final seating =
                  ref.read(seatingProvider(classId)).valueOrNull;
              if (seating == null) return;
              try {
                final repo = ref.read(seatingRepositoryProvider);
                await repo.createLayout(classId, {
                  'name': name,
                  'rows': seating.rows,
                  'cols': seating.cols,
                  'seats': _localSeats ?? seating.seats,
                });
                ref.invalidate(seatingLayoutsProvider(classId));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('方案「$name」已保存')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('保存失败：$e')),
                  );
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showLayoutPicker(BuildContext context, int classId) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Consumer(builder: (ctx, r, _) {
        final layouts = r.watch(seatingLayoutsProvider(classId));
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.gap4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('加载方案',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: AppSpacing.gap3),
                layouts.when(
                  loading: () => ShimmerSkeleton.list(
                      itemCount: 2, itemHeight: 48),
                  error: (e, _) => Text('加载失败：$e'),
                  data: (list) {
                    if (list.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.gap4),
                        child: Center(child: Text('暂无保存的方案')),
                      );
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: list.map((l) {
                        return ListTile(
                          leading: const Icon(
                              Icons.grid_view_rounded),
                          title: Text(l['name'] ?? '未命名'),
                          subtitle: Text(
                              '${l['rows']}×${l['cols']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 20),
                                onPressed: () async {
                                  final repo = ref.read(
                                      seatingRepositoryProvider);
                                  await repo.deleteLayout(
                                      l['id'] as int);
                                  ref.invalidate(
                                      seatingLayoutsProvider(
                                          classId));
                                },
                              ),
                            ],
                          ),
                          onTap: () async {
                            Navigator.pop(ctx);
                            try {
                              await ref
                                  .read(seatingProvider(classId)
                                      .notifier)
                                  .applyLayout(l['id'] as int);
                              _dirty = false;
                              _localSeats = null;
                              _undoStack.clear();
                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          '已应用方案「${l['name']}」')),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('应用失败：$e')),
                                );
                              }
                            }
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _showSeatAssignmentDialog(
    BuildContext context,
    int classId,
    int row,
    int col,
    int? currentStudentId,
    List<Student> students,
  ) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.gap4),
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('座位 ${row + 1}-${col + 1}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                leading: Icon(Icons.cleaning_services_rounded,
                    color: scheme.error),
                title: const Text('清空座位'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pushUndo();
                  setState(() {
                    _localSeats![row][col] = null;
                    _dirty = true;
                  });
                },
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: students
                      .map((student) => ListTile(
                            leading: CircleAvatar(
                              backgroundColor: scheme.primary
                                  .withValues(alpha: 0.18),
                              child: Text(
                                student.name.isEmpty
                                    ? '?'
                                    : student.name.substring(0, 1),
                                style: TextStyle(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            title: Text(student.name),
                            subtitle: Text(
                                student.gender == 'male' ? '男' : '女'),
                            trailing: currentStudentId == student.id
                                ? Icon(Icons.check_circle_rounded,
                                    color: scheme.primary)
                                : null,
                            onTap: () {
                              Navigator.pop(ctx);
                              _pushUndo();
                              setState(() {
                                _localSeats![row][col] = student.id;
                                _dirty = true;
                              });
                            },
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Draggable seat tile ────────────────────────────────────────────────────

class _DraggableSeat extends StatelessWidget {
  final int row;
  final int col;
  final Student? student;
  final Color accent;
  final void Function(int srcRow, int srcCol) onAcceptDrop;
  final void Function(int row, int col) onDragStarted;
  final VoidCallback onTap;

  const _DraggableSeat({
    required this.row,
    required this.col,
    required this.student,
    required this.accent,
    required this.onAcceptDrop,
    required this.onDragStarted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isEmpty = student == null;
    final isMale = student?.gender == 'male';
    final tintAlpha = brightness == Brightness.dark ? 0.16 : 0.10;

    // Gender color coding
    Color tileColor;
    Color borderColor;
    if (isEmpty) {
      tileColor = scheme.surface;
      borderColor = scheme.outlineVariant;
    } else if (isMale) {
      tileColor = Colors.blue.withValues(alpha: tintAlpha);
      borderColor = Colors.blue.withValues(alpha: 0.45);
    } else {
      tileColor = Colors.pink.withValues(alpha: tintAlpha);
      borderColor = Colors.pink.withValues(alpha: 0.45);
    }

    final tile = AnimatedContainer(
      duration: AppMotion.short,
      curve: AppMotion.standard,
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(AppRadius.s),
        border: Border.all(
          color: borderColor,
          width: isEmpty ? 1 : 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${row + 1}-${col + 1}',
            style: TextStyle(
              fontSize: 9,
              color: isEmpty
                  ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
                  : accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              student?.name ?? '空',
              maxLines: 1,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isEmpty
                    ? scheme.onSurfaceVariant.withValues(alpha: 0.5)
                    : scheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    final data = _SeatDragData(row, col);

    return DragTarget<_SeatDragData>(
      onWillAcceptWithDetails: (details) =>
          details.data.row != row || details.data.col != col,
      onAcceptWithDetails: (details) =>
          onAcceptDrop(details.data.row, details.data.col),
      builder: (context, candidates, rejects) {
        final isHovering = candidates.isNotEmpty;
        return LongPressDraggable<_SeatDragData>(
          data: data,
          onDragStarted: () => onDragStarted(row, col),
          feedback: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(AppRadius.s),
            child: SizedBox(
              width: 60,
              height: 60,
              child: tile,
            ),
          ),
          childWhenDragging: AnimatedContainer(
            duration: AppMotion.short,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.s),
              border: Border.all(
                color: scheme.outlineVariant,
                style: BorderStyle.solid,
              ),
            ),
          ),
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: isHovering
                    ? accent.withValues(alpha: 0.25)
                    : tileColor,
                borderRadius: BorderRadius.circular(AppRadius.s),
                border: Border.all(
                  color: isHovering ? accent : borderColor,
                  width: isHovering ? 2.0 : (isEmpty ? 1 : 1.5),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${row + 1}-${col + 1}',
                    style: TextStyle(
                      fontSize: 9,
                      color: isEmpty
                          ? scheme.onSurfaceVariant
                              .withValues(alpha: 0.6)
                          : accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      student?.name ?? '空',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isEmpty
                            ? scheme.onSurfaceVariant
                                .withValues(alpha: 0.5)
                            : scheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SeatDragData {
  final int row;
  final int col;
  const _SeatDragData(this.row, this.col);
}
