import 'dart:io';

import 'package:daily_one_shot/data/backup_service.dart';
import 'package:daily_one_shot/data/database.dart';
import 'package:daily_one_shot/data/entry_repository.dart';
import 'package:daily_one_shot/data/photo_storage.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late AppDatabase db;
  late EntryRepository repo;
  late PhotoStorage storage;
  late BackupService backup;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('daily_one_shot_backup_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = EntryRepository(db);
    storage = PhotoStorage(rootOverride: tmp);
    backup = BackupService(db: db, repo: repo, storage: storage);
  });

  tearDown(() async {
    await db.close();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<void> _seed() async {
    for (final day in [
      DateTime(2026, 5, 1),
      DateTime(2026, 5, 2),
      DateTime(2026, 5, 3),
    ]) {
      final src = img.Image(width: 100, height: 100);
      img.fill(src,
          color: img.ColorRgb8(day.day * 50, 100, 200 - day.day * 30));
      final rel = await storage.saveForDay(day, img.encodeJpg(src));
      await repo.upsert(day: day, photoPath: rel, memo: '메모 ${day.day}');
    }
  }

  test('export then import roundtrips all entries', () async {
    await _seed();

    final zipFile = File(p.join(tmp.path, 'export.zip'));
    await backup.exportToZip(zipFile);
    expect(await zipFile.exists(), isTrue);
    expect(await zipFile.length(), greaterThan(0));

    // Wipe DB and storage, then import.
    for (final day in [
      DateTime(2026, 5, 1),
      DateTime(2026, 5, 2),
      DateTime(2026, 5, 3),
    ]) {
      final entry = await repo.getByDate(day);
      if (entry != null) await repo.delete(entry.id);
      await storage.deleteForDay(day);
    }
    expect(await repo.listAll(), isEmpty);

    final imported = await backup.importFromZip(zipFile);
    expect(imported, 3);

    final restored = await repo.listAll();
    expect(restored.length, 3);
    expect(restored.map((e) => e.memo).toSet(),
        {'메모 1', '메모 2', '메모 3'});

    for (final e in restored) {
      final f = await storage.originalFile(e.photoPath);
      expect(await f.exists(), isTrue, reason: 'photo for ${e.date}');
    }
  });

  test('import with overwrite=false skips existing dates', () async {
    await _seed();
    final zipFile = File(p.join(tmp.path, 'export.zip'));
    await backup.exportToZip(zipFile);

    // Modify memo in DB, then import with overwrite=false.
    final existing = await repo.getByDate(DateTime(2026, 5, 1));
    await repo.upsert(
        day: existing!.date,
        photoPath: existing.photoPath,
        memo: '변경된 메모');

    await backup.importFromZip(zipFile, overwrite: false);
    final after = await repo.getByDate(DateTime(2026, 5, 1));
    expect(after!.memo, '변경된 메모');
  });
}
