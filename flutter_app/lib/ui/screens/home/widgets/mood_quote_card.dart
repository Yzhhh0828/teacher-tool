import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/services/prefs_service.dart';
import '../../../../providers/prefs_provider.dart';
import '../../../widgets/soft_card.dart';

/// Bottom-of-home card combining "心情速记" (per-day mood pick) and a
/// rotating "课堂金句" (quote-of-the-day from a built-in pool plus user
/// custom additions, persisted via [PrefsService]).
class MoodQuoteCard extends ConsumerStatefulWidget {
  final Color accent;
  const MoodQuoteCard({super.key, required this.accent});

  @override
  ConsumerState<MoodQuoteCard> createState() => _MoodQuoteCardState();
}

class _MoodQuoteCardState extends ConsumerState<MoodQuoteCard> {
  static const _moods = <_Mood>[
    _Mood('happy', '😄', '元气满满'),
    _Mood('chill', '🙂', '挺好的'),
    _Mood('flat', '😐', '一般般'),
    _Mood('worry', '😟', '有点累'),
    _Mood('sleepy', '😴', '想睡觉'),
  ];

  static const _builtinQuotes = <String>[
    '教育不是注满一桶水，而是点燃一把火。 — 叶芝',
    '学贵得师，亦贵得友。 — 唐甄',
    '我以为我们对一棵树的爱，胜过对一本书的爱。 — 苏霍姆林斯基',
    '没有爱就没有教育。 — 苏霍姆林斯基',
    '千教万教，教人求真；千学万学，学做真人。 — 陶行知',
    '捧着一颗心来，不带半根草去。 — 陶行知',
    '要敢于让孩子去尝试，去犯错。 — 蒙台梭利',
    '教育的根是苦的，但其果实是甜的。 — 亚里士多德',
    '不愤不启，不悱不发。 — 孔子',
    '学而不思则罔，思而不学则殆。 — 孔子',
    '凡是儿童自己能做到的，应当让他自己去做。 — 陈鹤琴',
    '知识改变命运，努力成就未来。',
    '教师是人类灵魂的工程师。 — 加里宁',
    '今天你以学校为荣，明天学校以你为荣。',
    '人生没有彩排，每一天都是现场直播。',
    '兴趣是最好的老师。 — 爱因斯坦',
    '学习这件事，不是缺乏时间，而是缺乏努力。 — 雷曼',
    '少年若天性，习惯成自然。 — 孔子',
    '读书破万卷，下笔如有神。 — 杜甫',
    '玉不琢，不成器；人不学，不知义。 — 礼记',
    '一日不读书，胸臆无佳想。 — 萧抡',
    '黑发不知勤学早，白首方悔读书迟。 — 颜真卿',
    '路漫漫其修远兮，吾将上下而求索。 — 屈原',
    '学如逆水行舟，不进则退。',
    '态度决定一切，细节决定成败。',
    '让每个孩子都体验到成功的快乐。',
    '尊重每个孩子的独特性，是教育的起点。',
    '教育是慢的艺术，需要耐心等待。',
    '种一棵树最好的时间是十年前，其次是现在。',
    '教师的人格就是教育工作中的一切。 — 乌申斯基',
  ];

  final TextEditingController _addQuoteCtrl = TextEditingController();

  @override
  void dispose() {
    _addQuoteCtrl.dispose();
    super.dispose();
  }

  String _todayQuote(PrefsService prefs) {
    final pool = [..._builtinQuotes, ...prefs.customQuotes];
    if (pool.isEmpty) return '';
    final today = DateTime.now();
    // Stable per-day index via simple date hash.
    final idx =
        (today.year * 1000 + today.month * 31 + today.day) % pool.length;
    return pool[idx];
  }

  void _selectMood(String mood) {
    final prefs = ref.read(prefsServiceProvider);
    prefs.setMoodFor(DateTime.now(), mood);
    setState(() {});
  }

  Future<void> _addCustomQuote() async {
    final prefs = ref.read(prefsServiceProvider);
    final ctx = context;
    _addQuoteCtrl.clear();
    await showDialog<void>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: const Text('添加自定义金句'),
        content: TextField(
          controller: _addQuoteCtrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '记下今天的教学感悟…',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final txt = _addQuoteCtrl.text.trim();
              if (txt.isEmpty) return;
              await prefs.addCustomQuote(txt);
              if (dctx.mounted) Navigator.pop(dctx);
              if (mounted) setState(() {});
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final prefs = ref.watch(prefsServiceProvider);
    final today = DateTime.now();
    final selectedMood = prefs.moodFor(today);
    final quote = _todayQuote(prefs);

    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.gap4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_rounded, color: widget.accent, size: 18),
              const SizedBox(width: 6),
              Text(
                '心情速记',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              if (selectedMood != null)
                Text(
                  '已记录今日心情',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.gap2),
          // Mood emoji picker
          LayoutBuilder(builder: (ctx, c) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final m in _moods)
                  _MoodPick(
                    emoji: m.emoji,
                    label: m.label,
                    selected: selectedMood == m.id,
                    accent: widget.accent,
                    onTap: () => _selectMood(m.id),
                  ),
              ],
            );
          }),
          const SizedBox(height: AppSpacing.gap4),
          Divider(color: scheme.outlineVariant.withValues(alpha: 0.5), height: 1),
          const SizedBox(height: AppSpacing.gap3),
          Row(
            children: [
              Icon(Icons.format_quote_rounded, color: widget.accent, size: 18),
              const SizedBox(width: 6),
              Text(
                '今日金句',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                tooltip: '添加自定义金句',
                onPressed: _addCustomQuote,
                color: widget.accent,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            quote,
            style: TextStyle(
              fontSize: 13.5,
              fontStyle: FontStyle.italic,
              color: scheme.onSurface.withValues(alpha: 0.85),
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          )
              .animate(key: ValueKey(quote))
              .fadeIn(duration: const Duration(milliseconds: 320))
              .moveY(begin: 4, end: 0),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: AppMotion.short)
        .moveY(
            begin: 6,
            end: 0,
            duration: AppMotion.short,
            curve: AppMotion.standard);
  }
}

class _Mood {
  final String id;
  final String emoji;
  final String label;
  const _Mood(this.id, this.emoji, this.label);
}

class _MoodPick extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _MoodPick({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: AnimatedContainer(
        duration: AppMotion.short,
        curve: AppMotion.emphasized,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.gap2, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: Border.all(
            color: selected ? accent : scheme.outlineVariant,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.18 : 1,
              duration: AppMotion.short,
              curve: Curves.easeOutBack,
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: selected ? accent : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
