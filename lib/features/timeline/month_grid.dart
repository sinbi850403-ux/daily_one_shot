import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../data/database.dart';

class MonthGrid extends StatelessWidget {
  const MonthGrid({super.key, required this.monthStart, required this.entries});

  final DateTime monthStart;
  final List<Entry> entries;

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateTime(monthStart.year, monthStart.month + 1, 0).day;
    final scope = AppScope.of(context);
    final byDay = {for (final e in entries) e.date.day: e};

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('yyyy년 M월', 'ko_KR').format(monthStart),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemBuilder: (ctx, i) {
              final day = i + 1;
              final entry = byDay[day];
              if (entry == null) {
                return Container(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: Theme.of(ctx)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.4),
                        fontSize: 10,
                      ),
                    ),
                  ),
                );
              }
              return FutureBuilder<File>(
                future: scope.storage.thumbFileForDay(entry.date),
                builder: (ctx, snap) {
                  final file = snap.data;
                  if (file == null) {
                    return Container(
                      color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    );
                  }
                  return Image.file(file, fit: BoxFit.cover);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
