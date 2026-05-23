import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// File layout inside the app sandbox:
///   <docs>/photos/originals/yyyy/MM/yyyyMMdd.jpg
///   <docs>/photos/thumbs256/yyyy/MM/yyyyMMdd.jpg   (widget-safe size)
class PhotoStorage {
  PhotoStorage({Directory? rootOverride}) : _rootOverride = rootOverride;
  final Directory? _rootOverride;

  Future<Directory> _root() async {
    final override = _rootOverride;
    if (override != null) return override;
    return getApplicationDocumentsDirectory();
  }

  Future<String> _ensureDir(String relative) async {
    final root = await _root();
    final dir = Directory(p.join(root.path, relative));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  String _relativeOriginal(DateTime day) {
    final y = day.year.toString().padLeft(4, '0');
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return 'photos/originals/$y/$m/$y$m$d.jpg';
  }

  String _relativeThumb(DateTime day) {
    final y = day.year.toString().padLeft(4, '0');
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return 'photos/thumbs256/$y/$m/$y$m$d.jpg';
  }

  /// Reads source bytes, normalizes EXIF rotation, writes both original
  /// (max 2048px on long edge) and a 256px square-cropped thumbnail.
  /// Returns relative path to the original (this is what gets stored in DB).
  Future<String> saveForDay(DateTime day, Uint8List sourceBytes) async {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) {
      throw const FormatException('Unsupported image format');
    }
    final oriented = img.bakeOrientation(decoded);

    final original = oriented.width > 2048 || oriented.height > 2048
        ? img.copyResize(
            oriented,
            width: oriented.width >= oriented.height ? 2048 : null,
            height: oriented.height > oriented.width ? 2048 : null,
            interpolation: img.Interpolation.linear,
          )
        : oriented;

    final root = await _root();
    final originalRel = _relativeOriginal(day);
    final thumbRel = _relativeThumb(day);

    await _ensureDir(p.dirname(originalRel));
    await _ensureDir(p.dirname(thumbRel));

    final originalFile = File(p.join(root.path, originalRel));
    final thumbFile = File(p.join(root.path, thumbRel));

    await originalFile.writeAsBytes(img.encodeJpg(original, quality: 88));

    final thumb = _squareThumb(oriented, 256);
    await thumbFile.writeAsBytes(img.encodeJpg(thumb, quality: 80));

    return originalRel;
  }

  img.Image _squareThumb(img.Image src, int size) {
    final short = src.width < src.height ? src.width : src.height;
    final x = (src.width - short) ~/ 2;
    final y = (src.height - short) ~/ 2;
    final cropped =
        img.copyCrop(src, x: x, y: y, width: short, height: short);
    return img.copyResize(cropped,
        width: size, height: size, interpolation: img.Interpolation.average);
  }

  Future<File> originalFile(String relativePath) async {
    final root = await _root();
    return File(p.join(root.path, relativePath));
  }

  Future<File> thumbFileForDay(DateTime day) async {
    final root = await _root();
    return File(p.join(root.path, _relativeThumb(day)));
  }

  Future<void> deleteForDay(DateTime day) async {
    final root = await _root();
    for (final rel in [_relativeOriginal(day), _relativeThumb(day)]) {
      final f = File(p.join(root.path, rel));
      if (await f.exists()) await f.delete();
    }
  }
}
