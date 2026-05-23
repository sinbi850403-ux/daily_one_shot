import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../data/database.dart';

/// 한 달의 사진 그리드.
/// - 일요일 시작 달력 레이아웃
/// - 요일 헤더(일~토)
/// - 오늘 셀 하이라이트
/// - 빈 날 탭 → 과거 기록 추가 (onEmptyDayTap)
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.monthStart,
    required this.entries,
    required this.onEntryTap,
    this.onEmptyDayTap,
    this.onOffsetMeasured,
  });

  final DateTime monthStart;
  final List<Entry> entries;
  final void Function(Entry) onEntryTap;
  final void Function(DateTime)? onEmptyDayTap;
  final void Function(double offset)? onOffsetMeasured;

  static const _weekLabels = ['일', '월', '화', '수', '목', '금', '토'];

  /// Dart weekday: 1=Mon … 7=Sun → 일요일 시작 offset
  static int _startOffset(DateTime first) => first.weekday % 7;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysInMonth =
        DateTime(monthStart.year, monthStart.month + 1, 0).day;
    final offset = _startOffset(monthStart);
    final totalCells = offset + daysInMonth;

    final scope = AppScope.of(context);
    final byDay = {for (final e in entries) e.date.day: e};
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('yyyy년 M월', 'ko_KR').format(monthStart),
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),

          // 요일 헤더
          Row(
            children: _weekLabels.map((d) {
              final isSun = d == '일';
              final isSat = d == '토';
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSun
                          ? cs.error.withValues(alpha: 0.8)
                          : isSat
                              ? cs.primary.withValues(alpha: 0.8)
                              : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
            ),
            itemBuilder: (ctx, i) {
              if (i < offset) return const SizedBox.shrink();

              final day = i - offset + 1;
              final cellDate = DateTime(
                  monthStart.year, monthStart.month, day);
              final isFuture = cellDate.isAfter(today);
              final isToday = cellDate == today;
              final entry = byDay[day];

              if (entry == null) {
                return _EmptyCell(
                  day: day,
                  isToday: isToday,
                  isFuture: isFuture,
                  weekdayIndex: i % 7,
                  onTap: (!isFuture && onEmptyDayTap != null)
                      ? () => onEmptyDayTap!(cellDate)
                      : null,
                );
              }
              return _PhotoCell(
                entry: entry,
                day: day,
                isToday: isToday,
                storage: scope.storage,
                onTap: () => onEntryTap(entry),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── 빈 셀 ──────────────────────────────────────────────────────────────────

class _EmptyCell extends StatelessWidget {
  const _EmptyCell({
    required this.day,
    required this.isToday,
    required this.isFuture,
    required this.weekdayIndex,
    this.onTap,
  });

  final int day;
  final bool isToday;
  final bool isFuture;
  final int weekdayIndex; // 0=일, 6=토
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textColor = weekdayIndex == 0
        ? cs.error.withValues(alpha: 0.5)
        : weekdayIndex == 6
            ? cs.primary.withValues(alpha: 0.5)
            : cs.onSurfaceVariant.withValues(alpha: 0.35);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isToday
              ? cs.primaryContainer.withValues(alpha: 0.35)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(5),
          border: isToday
              ? Border.all(color: cs.primary, width: 1.5)
              : null,
        ),
        child: Center(
          child: Text(
            '$day',
            style: TextStyle(
              color: isFuture
                  ? cs.onSurfaceVariant.withValues(alpha: 0.18)
                  : isToday
                      ? cs.primary
                      : textColor,
              fontSize: 9,
            ),
          ),
        ),
      ),
    );
  }
}

// ── 사진 셀 ────────────────────────────────────────────────────────────────

class _PhotoCell extends StatelessWidget {
  const _PhotoCell({
    required this.entry,
    required this.day,
    required this.isToday,
    required this.storage,
    required this.onTap,
  });

  final Entry entry;
  final int day;
  final bool isToday;
  final dynamic storage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final heroTag = 'timeline-${entry.date.toIso8601String()}';

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<File>(
            future: storage.thumbFileForDay(entry.date),
            builder: (ctx, snap) {
              final file = snap.data;
              final exists = file != null && file.existsSync();
              if (!exists) {
                return Container(
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Center(
                    child: Text('$day',
                        style: const TextStyle(fontSize: 9)),
                  ),
                );
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Hero(
                  tag: heroTag,
                  child: Image.file(file, fit: BoxFit.cover),
                ),
              );
            },
          ),
          if (isToday)
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: cs.primary, width: 2),
              ),
            ),
        ],
      ),
    );
  }
}
