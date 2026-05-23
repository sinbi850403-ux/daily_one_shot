import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/database.dart';
import 'month_grid.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  late Future<List<Entry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Entry>> _load() {
    final scope = AppScope.of(context);
    return scope.repo.listAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('타임라인'),
        actions: [
          IconButton(
            tooltip: '연도 점프',
            icon: const Icon(Icons.skip_next_outlined),
            onPressed: _showYearJump,
          ),
        ],
      ),
      body: FutureBuilder<List<Entry>>(
        future: _future,
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snap.data!;
          if (entries.isEmpty) {
            return const Center(child: Text('아직 기록이 없어요'));
          }
          // Bucket entries by (year, month).
          final byMonth = <DateTime, List<Entry>>{};
          for (final e in entries) {
            final key = DateTime.utc(e.date.year, e.date.month, 1);
            byMonth.putIfAbsent(key, () => []).add(e);
          }
          final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
          return ListView.builder(
            itemCount: months.length,
            itemBuilder: (ctx, i) {
              final monthKey = months[i];
              return MonthGrid(
                monthStart: monthKey,
                entries: byMonth[monthKey]!,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showYearJump() async {
    final entries = await _future;
    if (entries.isEmpty || !mounted) return;
    final years = entries.map((e) => e.date.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final y in years)
              ListTile(
                title: Text('$y년'),
                onTap: () => Navigator.pop(sheetCtx, y),
              ),
          ],
        ),
      ),
    );
  }
}

