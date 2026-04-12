import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/seating_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../data/models/student.dart';

class SeatingScreen extends ConsumerWidget {
  const SeatingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentClass = ref.watch(currentClassProvider);
    if (currentClass == null) {
      return const Center(child: Text('请先选择班级'));
    }

    final seatingAsync = ref.watch(seatingProvider(currentClass.id));
    final studentsAsync = ref.watch(studentListProvider(currentClass.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('座位管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('确认随机排座'),
                  content: const Text('确定要随机打乱所有座位吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(seatingProvider(currentClass.id).notifier).shuffleSeats();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showGridSizeDialog(context, ref, currentClass.id),
          ),
        ],
      ),
      body: seatingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (seating) {
          if (seating == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('暂无座位布局'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _showGridSizeDialog(context, ref, currentClass.id),
                    child: const Text('创建座位'),
                  ),
                ],
              ),
            );
          }

          return studentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (students) => _buildSeatingGrid(context, ref, seating, students, currentClass.id),
          );
        },
      ),
    );
  }

  Widget _buildSeatingGrid(
    BuildContext context,
    WidgetRef ref,
    dynamic seating,
    List<Student> students,
    int classId,
  ) {
    final studentMap = {for (var s in students) s.id: s};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Front of classroom indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '讲台 (前方)',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          // Seats grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: seating.cols,
              childAspectRatio: 1.2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: seating.rows * seating.cols,
            itemBuilder: (context, index) {
              final row = index ~/ seating.cols;
              final col = index % seating.cols;
              final studentId = seating.seats[row][col];
              final student = studentId != null ? studentMap[studentId] : null;

              return GestureDetector(
                onTap: () => _showSeatAssignmentDialog(
                  context,
                  ref,
                  classId,
                  row,
                  col,
                  studentId,
                  students,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: student != null ? Colors.blue[100] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${row + 1}-${col + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        student?.name ?? '空',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: student != null ? Colors.black87 : Colors.grey[500],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showGridSizeDialog(BuildContext context, WidgetRef ref, int classId) {
    int rows = 6;
    int cols = 8;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置座位布局'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('行数: '),
                const SizedBox(width: 8),
                Expanded(
                  child: StatefulBuilder(
                    builder: (context, setState) => Slider(
                      value: rows.toDouble(),
                      min: 2,
                      max: 10,
                      divisions: 8,
                      label: rows.toString(),
                      onChanged: (value) {
                        setState(() => rows = value.round());
                      },
                    ),
                  ),
                ),
                Text('$rows'),
              ],
            ),
            Row(
              children: [
                const Text('列数: '),
                const SizedBox(width: 8),
                Expanded(
                  child: StatefulBuilder(
                    builder: (context, setState) => Slider(
                      value: cols.toDouble(),
                      min: 2,
                      max: 10,
                      divisions: 8,
                      label: cols.toString(),
                      onChanged: (value) {
                        setState(() => cols = value.round());
                      },
                    ),
                  ),
                ),
                Text('$cols'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(seatingProvider(classId).notifier).createSeating(rows, cols);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showSeatAssignmentDialog(
    BuildContext context,
    WidgetRef ref,
    int classId,
    int row,
    int col,
    int? currentStudentId,
    List<Student> students,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('座位 ${row + 1}-${col + 1}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('清空座位'),
                onTap: () async {
                  Navigator.pop(context);
                  await ref.read(seatingProvider(classId).notifier).updateSeat(row, col, null);
                },
              ),
              const Divider(),
              ...students.map((student) => ListTile(
                    title: Text(student.name),
                    subtitle: Text(student.gender == 'male' ? '男' : '女'),
                    trailing: currentStudentId == student.id
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () async {
                      Navigator.pop(context);
                      await ref.read(seatingProvider(classId).notifier).updateSeat(row, col, student.id);
                    },
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
