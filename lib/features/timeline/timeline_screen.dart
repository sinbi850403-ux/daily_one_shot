import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../ads/ad_banner.dart';
import '../../app_scope.dart';
import '../../data/database.dart';
import '../today/today_screen.dart';
import '../viewer/photo_viewer_screen.dart';
import 'month_grid.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> with RouteAware {
  List<Entry> _entries = [];
  bool _loading = true;
  int _streak = 0;
  int _total = 0;
  int _thisYear = 0;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didPopNext() {
    _load();
  }

  Future<void> _load() async {
    final scope = AppScope.of(context);
    final entries = await scope.repo.listAll();
    final streak = await scope.repo.currentStreak();
    final total = await scope.repo.totalCount();
    final thisYear = await scope.repo.countThisYear();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _streak = streak;
      _total = total;
      _thisYear = thisYear;
      _loading = false;
    });
  }

  Map<DateTime, List<Entry>> get _byMonth {
    final map = <DateTime, List<Entry>>{};
    for (final e in _entries) {
      final key = DateTime.utc(e.date.year, e.date.month, 1);
      map.putIfAbsent(key, () => []).add(e);
    }
    return map;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onEntryTap(Entry entry) async {
    final scope = AppScope.of(context);
    final file = await scope.storage.originalFile(entry.photoPath);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoViewerScreen(
          entry: entry,
          file: file,
          heroTag: 'timeline-${entry.date.toIso8601String()}',
        ),
      ),
    );
  }

  void _onEmptyDayTap(DateTime date) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TodayScreen(targetDate: date),
      ),
    );
    _load(); // 돌아오면 새로고침
  }

  @override
  Widget build(BuildContext context) {
    final byMonth = _byMonth;
    final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('타임라인'),
        actions: [
          if (months.isNotEmpty)
            IconButton(
              tooltip: '연도 점프',
              icon: const Icon(Icons.unfold_more),
              onPressed: () => _showYearJump(months),
            ),
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo_library_outlined,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('아직 기록이 없어요',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('오늘 첫 장 남기러 가기'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      // ── 통계 카드 ─────────────────────────────
                      SliverToBoxAdapter(
                        child: _StatsBar(
                          streak: _streak,
                          total: _total,
                          thisYear: _thisYear,
                        ),
                      ),
                      // ── 광고 배너 (무료 사용자만) ──────────────
                      const SliverToBoxAdapter(
                        child: AdBannerWidget(),
                      ),
                      // ── 월별 그리드 ───────────────────────────
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final monthKey = months[i];
                            return MonthGrid(
                              key: ValueKey(monthKey),
                              monthStart: monthKey,
                              entries: byMonth[monthKey]!,
                              onEntryTap: _onEntryTap,
                              onEmptyDayTap: _onEmptyDayTap,
                            );
                          },
                          childCount: months.length,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Future<void> _showYearJump(List<DateTime> months) async {
    final years = months.map((m) => m.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('연도 선택',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final y in years)
              ListTile(
                title: Text('$y년'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _scrollToYear(y, months);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _scrollToYear(int year, List<DateTime> months) {
    final idx = months.indexWhere((m) => m.year == year);
    if (idx < 0) return;
    final approxOffset = idx * 420.0;
    _scrollController.animateTo(
      approxOffset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }
}

// ── 통계 바 ────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  const _StatsBar({
    required this.streak,
    required this.total,
    required this.thisYear,
  });

  final int streak;
  final int total;
  final int thisYear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: cs.primary.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(
            icon: Icons.local_fire_department_outlined,
            value: '$streak일',
            label: '연속 기록',
            highlight: streak >= 7,
          ),
          _divider(cs),
          _StatItem(
            icon: Icons.photo_library_outlined,
            value: '$total장',
            label: '총 기록',
          ),
          _divider(cs),
          _StatItem(
            icon: Icons.calendar_today_outlined,
            value: '$thisYear장',
            label: '올해',
          ),
        ],
      ),
    );
  }

  Widget _divider(ColorScheme cs) => Container(
        height: 36,
        width: 1,
        color: cs.outline.withValues(alpha: 0.2),
      );
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = highlight ? cs.error : cs.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
