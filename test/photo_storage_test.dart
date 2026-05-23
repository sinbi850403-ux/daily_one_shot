import 'dart:io';

import 'package:daily_one_shot/data/photo_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late PhotoStorage storage;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('daily_one_shot_test_');
    storage = PhotoStorage(rootOverride: tmp);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('saveForDay writes original and thumb, normalizes orientation',
      () async {
    // Build a 4x2 image with EXIF orientation 6 (rotate 90 CW).
    final src = img.Image(width: 4, height: 2);
    img.fill(src, color: img.ColorRgb8(255, 0, 0));
    src.exif.imageIfd['Orientation'] = 6;
    final bytes = img.encodeJpg(src);

    final day = DateTime(2026, 5, 23);
    final relative = await storage.saveForDay(day, bytes);

    final originalFile = await storage.originalFile(relative);
    expect(await originalFile.exists(), isTrue);
    final original = img.decodeImage(await originalFile.readAsBytes())!;
    // After bakeOrientation a 4x2 with orientation 6 becomes 2x4.
    expect(original.width, 2);
    expect(original.height, 4);

    final thumb = await storage.thumbFileForDay(day);
    expect(await thumb.exists(), isTrue);
    final thumbImage = img.decodeImage(await thumb.readAsBytes())!;
    expect(thumbImage.width, 256);
    expect(thumbImage.height, 256);
  });

  test('saveForDay overwriting the same day replaces the file', () async {
    final day = DateTime(2026, 5, 23);
    final red = img.Image(width: 10, height: 10);
    img.fill(red, color: img.ColorRgb8(255, 0, 0));
    final green = img.Image(width: 10, height: 10);
    img.fill(green, color: img.ColorRgb8(0, 255, 0));

    await storage.saveForDay(day, img.encodeJpg(red));
    final rel = await storage.saveForDay(day, img.encodeJpg(green));

    final f = await storage.originalFile(rel);
    final stored = img.decodeImage(await f.readAsBytes())!;
    final centerPixel = stored.getPixel(5, 5);
    // JPEG is lossy; just check green dominates red.
    expect(centerPixel.g > centerPixel.r, isTrue);
  });

  test('deleteForDay removes both original and thumb', () async {
    final day = DateTime(2026, 5, 23);
    final src = img.Image(width: 10, height: 10);
    img.fill(src, color: img.ColorRgb8(0, 0, 255));
    final rel = await storage.saveForDay(day, img.encodeJpg(src));

    final original = File(p.join(tmp.path, rel));
    final thumb = await storage.thumbFileForDay(day);
    expect(await original.exists(), isTrue);
    expect(await thumb.exists(), isTrue);

    await storage.deleteForDay(day);
    expect(await original.exists(), isFalse);
    expect(await thumb.exists(), isFalse);
  });
}
