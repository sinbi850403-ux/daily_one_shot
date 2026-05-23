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
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

@DriftDatabase(tables: [Entries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
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
