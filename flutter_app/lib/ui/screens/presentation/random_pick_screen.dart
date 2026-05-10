import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/classroom_provider.dart';
import '../../../providers/student_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/confetti_button.dart';
import '../../widgets/wheel_picker.dart';

/// Server-backed random-call screen.
///
/// Uses `/classroom/{id}/pick` so the result is persisted in the event log
/// (and benefits from "avoid recently picked" logic). The visual is a
/// spinning name wheel that lands on the chosen student.
class RandomPickScreen extends ConsumerStatefulWidget {
  const RandomPickScreen({super.key});

  @override
  ConsumerState<RandomPickScreen> createState() => _RandomPickScreenState();
}

class _RandomPickScreenState extends ConsumerState<RandomPickScreen> {
  bool _spinning = false;
  String? _final;
  bool _avoidRecent = true;

  Future<void> _pick() async {
    final cls = ref.read(currentClassProvider);
    if (cls == null) return;
    setState(() {
      _spinning = true;
      _final = null;
    });
    try {
      final repo = ref.read(classroomRepositoryProvider);
      final result = await repo.pickRandomStudent(
        cls.id,
        avoidRecentMinutes: _avoidRecent ? 60 : 0,
      );
      final picked = result['picked'];
      setState(() => _final = picked == null ? '暂无学生' : picked['name'] as String);
    } catch (e) {
      setState(() => _final = '请求失败');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cls = ref.watch(currentClassProvider);
    final names = cls == null
        ? <String>[]
        : (ref.watch(studentListProvider(cls.id)).valueOrNull ?? []).map((s) => s.name).toList();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('随机点名')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const Spacer(),
            SizedBox(
              height: 220,
              child: Center(
                child: NameWheel(
                  names: names.isEmpty ? const ['—'] : names,
                  running: _spinning,
                  finalName: _final,
                  onSettled: (name) {
                    if (!mounted) return;
                    setState(() => _spinning = false);
                    if (name != '—' && name.isNotEmpty) {
                      // ignore: unawaited_futures
                      ConfettiAction.celebrate(context, message: name);
                    }
                  },
                ),
              ),
            ),
            const Spacer(),
            AppCard(
              child: SwitchListTile(
                value: _avoidRecent,
                onChanged: (v) => setState(() => _avoidRecent = v),
                title: const Text('避免最近被点过的同学'),
                subtitle: const Text('60 分钟内点过的将被排除'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _spinning ? null : _pick,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.casino_rounded),
              label: Text(_spinning ? '抽取中…' : '随机抽取'),
            ),
          ],
        ),
      ),
    );
  }
}
