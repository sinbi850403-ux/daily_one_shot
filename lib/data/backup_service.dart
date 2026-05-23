import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import 'database.dart';
import 'entry_repository.dart';
import 'photo_storage.dart';

/// ZIP export/import for "carry your data forever" guarantee.
/// Format:
///   manifest.json   — { version, exportedAt, entries: [{date, memo, photo, createdAt, updatedAt}] }
///   photos/<file>   — original photos referenced by manifest
class BackupService {
  BackupService({
    required AppDatabase db,
    required EntryRepository repo,
    required PhotoStorage storage,
  })  : _repo = repo,
        _storage = storage;

  final EntryRepository _repo;
  final PhotoStorage _storage;

  static const int formatVersion = 1;

  Future<File> exportToZip(File targetFile) async {
    final encoder = ZipFileEncoder()..create(targetFile.path);
    try {
      final entries = await _repo.listAll();
      final manifest = {
        'version': formatVersion,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'entries': [
          for (final e in entries)
            {
              'date': e.date.toIso8601String(),
              'memo': e.memo,
              'photo': p.basename(e.photoPath),
              'createdAt': e.createdAt.toIso8601String(),
              'updatedAt': e.updatedAt.toIso8601String(),
            }
        ],
      };
      encoder.addArchiveFile(ArchiveFile.string(
        'manifest.json',
        const JsonEncoder.withIndent('  ').convert(manifest),
      ));
      for (final e in entries) {
        final src = await _storage.originalFile(e.photoPath);
        if (await src.exists()) {
          await encoder.addFile(src, 'photos/${p.basename(e.photoPath)}');
        }
      }
    } finally {
      await encoder.close();
    }
    return targetFile;
  }

  /// Imports a ZIP. By default REPLACES existing entries with the same date.
  /// Returns the count of imported entries.
  Future<int> importFromZip(File source, {bool overwrite = true}) async {
    final bytes = await source.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null) {
      throw const FormatException('manifest.json missing');
    }
    final manifest =
        jsonDecode(utf8.decode(manifestFile.content as List<int>))
            as Map<String, dynamic>;
    final entries = (manifest['entries'] as List).cast<Map<String, dynamic>>();

    int imported = 0;
    for (final m in entries) {
      final date = DateTime.parse(m['date'] as String);
      final memo = m['memo'] as String? ?? '';
      final photoName = m['photo'] as String;

      final photoEntry = archive.findFile('photos/$photoName');
      if (photoEntry == null) continue;

      if (!overwrite) {
        final existing = await _repo.getByDate(date);
        if (existing != null) continue;
      }

      final photoBytes =
          Uint8List.fromList(photoEntry.content as List<int>);
      final saved = await _storage.saveForDay(date, photoBytes);
      await _repo.upsert(day: date, photoPath: saved, memo: memo);
      imported += 1;
    }
    return imported;
  }
}
