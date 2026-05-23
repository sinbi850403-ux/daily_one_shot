import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Stored as UTC midnight of the local date the entry belongs to.
  DateTimeColumn get date => dateTime().unique()();
  TextColumn get photoPath => text()();
  TextColumn get memo => text().withLength(min: 0, max: 200)();
  // v2: weather string (e.g. "맑음 22°C"), nullable
  TextColumn get weather => text().nullable()();
  // v2: GPS coordinates, nullable
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

@DriftDatabase(tables: [Entries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(entries, entries.weather);
        await m.addColumn(entries, entries.latitude);
        await m.addColumn(entries, entries.longitude);
      }
    },
    onCreate: (m) async {
      await m.createAll();
      await customStatement('''
        CREATE VIRTUAL TABLE entries_fts USING fts5(
          memo, content='entries', content_rowid='id', tokenize='unicode61'
        )
      ''');
      await customStatement('''
        CREATE TRIGGER entries_ai AFTER INSERT ON entries BEGIN
          INSERT INTO entries_fts(rowid, memo) VALUES (new.id, new.memo);
        END
      ''');
      await customStatement('''
        CREATE TRIGGER entries_ad AFTER DELETE ON entries BEGIN
          INSERT INTO entries_fts(entries_fts, rowid, memo) VALUES('delete', old.id, old.memo);
        END
      ''');
      await customStatement('''
        CREATE TRIGGER entries_au AFTER UPDATE ON entries BEGIN
          INSERT INTO entries_fts(entries_fts, rowid, memo) VALUES('delete', old.id, old.memo);
          INSERT INTO entries_fts(rowid, memo) VALUES (new.id, new.memo);
        END
      ''');
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'daily_one_shot.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
