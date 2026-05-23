import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../data/database.dart';
import '../viewer/photo_viewer_screen.dart';

/// "이날의 기억" — 오늘과 같은 월/일의 과거 기록을 모두 표시.
class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  List<Entry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final scope = AppScope.of(context);
    final entries =
        await scope.repo.onThisDayInPriorYears(DateTime.now());
    if (!mounted) return;
    setState(() {
      _entries = entries..sort((a, b) => b.date.compareTo(a.date));
      _loading = false;
    });
  }

  void _openViewer(Entry entry) async {
    final scope = AppScope.of(context);
    final file = await scope.storage.originalFile(entry.photoPath);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoViewerScreen(
          entry: entry,
          file: file,
          heroTag: 'memory-${entry.date.toIso8601String()}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayLabel =
        DateFormat('M월 d일', 'ko_KR').format(today);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('이날의 기억 · $todayLabel'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_outlined,
                          size: 64,
                          color: theme.colorScheme.outlineVariant),
                      const SizedBox(height: 16),
                      Text(
                        '아직 작년 오늘 기록이 없어요',
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '꾸준히 기록하면 내년 오늘 여기 나타나요',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outlineVariant),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  itemCount: _entries.length,
                  itemBuilder: (ctx, i) {
                    final entry = _entries[i];
                    final yearsAgo =
                        today.year - entry.date.year;
                    return _MemoryCard(
                      entry: entry,
                      yearsAgo: yearsAgo,
                      onTap: () => _openViewer(entry),
                    );
                  },
                ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.entry,
    required this.yearsAgo,
    required this.onTap,
  });

  final Entry entry;
  final int yearsAgo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dateLabel =
        DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(entry.date);
    final heroTag = 'memory-${entry.date.toIso8601String()}';

    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 사진
            AspectRatio(
              aspectRatio: 4 / 3,
              child: FutureBuilder<File>(
                future: scope.storage.originalFile(entry.photoPath),
                builder: (ctx, snap) {
                  final file = snap.data;
                  if (file == null || !file.existsSync()) {
                    return Container(
                        color: cs.surfaceContainerHighest,
                        child: const Center(
                            child: CircularProgressIndicator()));
                  }
                  return Hero(
                    tag: heroTag,
                    child: Image.file(file, fit: BoxFit.cover),
                  );
                },
              ),
            ),
            // 정보
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$yearsAgo년 전 오늘',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  if (entry.memo.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      entry.memo,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
