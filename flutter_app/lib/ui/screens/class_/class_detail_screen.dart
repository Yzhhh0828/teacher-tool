import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/class_model.dart';
import '../../../providers/class_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../grade/exam_list_screen.dart';
import '../presentation/presentation_screen.dart';
import '../schedule/schedule_screen.dart';
import '../seating/seating_screen.dart';
import '../student/student_list_screen.dart';

class ClassDetailScreen extends ConsumerWidget {
  final int classId;

  const ClassDetailScreen({super.key, required this.classId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(classRepositoryProvider);
    final currentClass = ref.watch(currentClassProvider);
    final classFuture = currentClass?.id == classId
        ? Future<ClassModel>.value(currentClass)
        : repository.getClassDetail(classId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('班级详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              try {
                final code = await repository.createInviteCode(classId);
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('邀请码'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceSubtle,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: Text(
                              code,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.primaryColor, letterSpacing: 2),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text('将此邀请码分享给其他老师加入班级', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary), textAlign: TextAlign.center),
                        ],
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
                        FilledButton.icon(
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('复制'),
                          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: code));
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('邀请码已复制')));
                          },
                        ),
                      ],
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('生成邀请码失败：$e')));
                }
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<ClassModel>(
        future: classFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('加载班级详情失败：${snapshot.error}'),
              ),
            );
          }

          final classInfo = snapshot.data;
          if (classInfo == null) {
            return const Center(child: Text('未找到班级信息'));
          }

          if (currentClass?.id != classInfo.id) {
            Future.microtask(() {
              ref.read(currentClassProvider.notifier).state = classInfo;
            });
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // Header info strip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
                      child: Text(
                        classInfo.name.trim().isEmpty ? '班' : classInfo.name.trim().substring(0, 1),
                        style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700, fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(classInfo.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.textPrimary)),
                          const SizedBox(height: 3),
                          Text('${classInfo.grade} 年级', style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('班级功能', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: 0.3)),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.4,
                children: [
                  _GridEntry(icon: Icons.badge_outlined, title: '学生管理', color: AppTheme.primaryColor,
                      onTap: () => _openPage(context, const StudentListScreen())),
                  _GridEntry(icon: Icons.assignment_outlined, title: '考试成绩', color: const Color(0xFFD97A3A),
                      onTap: () => _openPage(context, const ExamListScreen())),
                  _GridEntry(icon: Icons.grid_view_outlined, title: '座位表', color: AppTheme.successColor,
                      onTap: () => _openPage(context, const SeatingScreen())),
                  _GridEntry(icon: Icons.calendar_view_week_outlined, title: '课表管理', color: const Color(0xFF7A9EC7),
                      onTap: () => _openPage(context, const ScheduleScreen())),
                  _GridEntry(icon: Icons.present_to_all_outlined, title: '课堂展示', color: AppTheme.accent,
                      onTap: () => _openPage(context, const PresentationScreen())),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }
}

class _GridEntry extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _GridEntry({required this.icon, required this.title, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceWhite,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderLight),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
