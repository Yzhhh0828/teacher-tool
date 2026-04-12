import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ClassDetailScreen extends ConsumerWidget {
  final int classId;

  const ClassDetailScreen({super.key, required this.classId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('班级详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              final repository = ref.read(classRepositoryProvider);
              final code = await repository.createInviteCode(classId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('邀请码: $code')),
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Text('班级 ID: $classId'),
      ),
    );
  }
}
