import 'package:drift/drift.dart';

import 'database.dart';

/// Truncates any DateTime to local midnight, stored as UTC instant of that
/// local midnight. This is the canonical "day key" — one entry per day.
DateTime dayKey(DateTime moment) {
  final local = moment.toLocal();
  return DateTime.utc(local.year, local.month, local.day);
}

class EntryRepository {
  EntryRepository(this._db);
  final AppDatabase _db;

  Future<Entry?> getByDate(DateTime day) {
    final key = dayKey(day);
    return (_db.select(_db.entries)..where((t) => t.date.equals(key)))
        .getSingleOrNull();
  }

  Future<int> upsert({
    required DateTime day,
    required String photoPath,
    required String memo,
    String? weather,
    double? latitude,
    double? longitude,
  }) async {
    final key = dayKey(day);
    final now = DateTime.now().toUtc();
    final existing = await getByDate(key);
    if (existing == null) {
      return _db.into(_db.entries).insert(
        EntriesCompanion.insert(
          date: key,
          photoPath: photoPath,
          memo: memo,
          weather: Value(weather),
          latitude: Value(latitude),
          longitude: Value(longitude),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    await (_db.update(_db.entries)..where((t) => t.id.equals(existing.id)))
        .write(EntriesCompanion(
      photoPath: Value(photoPath),
      memo: Value(memo),
      weather: Value(weather ?? existing.weather),
      latitude: Value(latitude ?? existing.latitude),
      longitude: Value(longitude ?? existing.longitude),
      updatedAt: Value(now),
    ));
    return existing.id;
  }

  Future<void> delete(int id) =>
      (_db.delete(_db.entries)..where((t) => t.id.equals(id))).go();

  Future<List<Entry>> listBetween(DateTime from, DateTime to) {
    final a = dayKey(from);
    final b = dayKey(to);
    return (_db.select(_db.entries)
          ..where((t) => t.date.isBetweenValues(a, b))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
  }

  Future<List<Entry>> listAll() {
    return (_db.select(_db.entries)
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  /// FTS5 search. Falls back to LIKE for very short or non-tokenizable input.
  Future<List<Entry>> search(String query, {DateTime? from, DateTime? to}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final useFts = trimmed.length >= 2 && !trimmed.contains(RegExp(r'[%_]'));
    final List<Entry> hits;
    if (useFts) {
      final ftsQuery = _toFtsQuery(trimmed);
      final rows = await _db.customSelect(
        'SELECT entries.* FROM entries '
        'JOIN entries_fts ON entries_fts.rowid = entries.id '
        'WHERE entries_fts MATCH ? ORDER BY entries.date DESC',
        variables: [Variable.withString(ftsQuery)],
        readsFrom: {_db.entries},
      ).get();
      hits = rows.map((r) => _db.entries.map(r.data)).toList();
    } else {
      hits = await (_db.select(_db.entries)
            ..where((t) => t.memo.contains(trimmed))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();
    }

    if (from == null && to == null) return hits;
    final a = from == null ? null : dayKey(from);
    final b = to == null ? null : dayKey(to);
    return hits.where((e) {
      if (a != null && e.date.isBefore(a)) return false;
      if (b != null && e.date.isAfter(b)) return false;
      return true;
    }).toList();
  }

  /// Entries that fell on the same month/day in prior years (memory widget).
  Future<List<Entry>> onThisDayInPriorYears(DateTime today) async {
    final all = await listAll();
    final key = dayKey(today);
    return all.where((e) {
      return e.date.month == key.month &&
          e.date.day == key.day &&
          e.date.year < key.year;
    }).toList();
  }

  // ── 통계 ─────────────────────────────────────────────────────────────────

  Future<int> totalCount() async => (await listAll()).length;

  /// 오늘(또는 어제)을 포함한 연속 기록 일수.
  Future<int> currentStreak() async {
    final entries = await listAll(); // 내림차순 정렬
    if (entries.isEmpty) return 0;
    final today = dayKey(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    // 오늘 기록 있으면 오늘부터, 없으면 어제부터 카운트
    DateTime cursor =
        entries.first.date == today ? today : yesterday;
    int streak = 0;
    for (final e in entries) {
      if (e.date == cursor) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else if (e.date.isBefore(cursor)) {
        break; // 연속 끊김
      }
    }
    return streak;
  }

  /// 올해 기록한 날 수.
  Future<int> countThisYear() async {
    final year = DateTime.now().year;
    final entries = await listAll();
    return entries.where((e) => e.date.year == year).length;
  }

  String _toFtsQuery(String input) {
    // Escape double quotes, wrap each token as a prefix match.
    final tokens = input
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => '"${t.replaceAll('"', '""')}"*');
    return tokens.join(' AND ');
  }
}
