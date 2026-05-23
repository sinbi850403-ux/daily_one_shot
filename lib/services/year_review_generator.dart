import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../data/database.dart';

/// 연도별 회고 카드 (1080×1350) — 최대 12장(월별 1장) 그리드
class YearReviewGenerator {
  static const double _w = 1080;
  static const double _h = 1350;

  static Future<File> generate(
      int year, List<Entry> entries, List<File> photos) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, _w, _h));

    // 배경
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _w, _h),
      Paint()..color = const Color(0xFF1A1008),
    );

    // 헤더 텍스트
    _drawText(canvas, '$year', 80, const Color(0xFFFFCC88),
        ui.FontWeight.w800, 72, _w / 2, 80, center: true);
    _drawText(canvas, '하루 한 장 — 올해의 기록', 28, const Color(0x99FFFFFF),
        ui.FontWeight.w400, 28, _w / 2, 170, center: true);
    _drawText(canvas, '${entries.length}일 기록', 36, const Color(0xCCFFCC88),
        ui.FontWeight.w700, 36, _w / 2, 215, center: true);

    // 12 셀 그리드 (3열 × 4행)
    const cols = 3;
    const rows = 4;
    const padX = 36.0;
    const padY = 260.0;
    const gap = 12.0;
    final cellW = (_w - padX * 2 - gap * (cols - 1)) / cols;
    final cellH = (_h - padY - 90 - gap * (rows - 1)) / rows;

    // 월별 최신 entry 선택
    final byMonth = <int, int>{}; // month → photos index
    for (var i = 0; i < entries.length; i++) {
      final m = entries[i].date.month;
      byMonth.putIfAbsent(m, () => i);
    }

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final month = row * cols + col + 1;
        if (month > 12) break;
        final x = padX + col * (cellW + gap);
        final y = padY + row * (cellH + gap);
        final rect = Rect.fromLTWH(x, y, cellW, cellH);

        final photoIdx = byMonth[month];
        if (photoIdx != null && photoIdx < photos.length) {
          try {
            final img = await _loadImage(photos[photoIdx]);
            _drawCover(canvas, img, rect);
            img.dispose();
          } catch (_) {
            _drawEmpty(canvas, rect, month);
          }
        } else {
          _drawEmpty(canvas, rect, month);
        }

        // 월 라벨
        _drawText(canvas, '$month월', 20, const Color(0xCCFFFFFF),
            ui.FontWeight.w600, 20, x + cellW / 2, y + cellH - 24,
            center: true);
      }
    }

    // 워터마크
    _drawText(canvas, '하루 한 장  📷', 26, const Color(0x66FFFFFF),
        ui.FontWeight.w400, 26, _w - 48, _h - 48, right: true);

    final picture = recorder.endRecording();
    final image = await picture.toImage(_w.toInt(), _h.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    final tmp = await getTemporaryDirectory();
    final out = File('${tmp.path}/year_review_$year.png');
    await out.writeAsBytes(data!.buffer.asUint8List());
    return out;
  }

  static void _drawCover(Canvas canvas, ui.Image img, Rect dst) {
    final rrect =
        RRect.fromRectAndRadius(dst, const Radius.circular(12));
    canvas.save();
    canvas.clipRRect(rrect);
    final src =
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    final imgR = img.width / img.height;
    final dstR = dst.width / dst.height;
    Rect fitDst;
    if (imgR > dstR) {
      final h = dst.height;
      final w = h * imgR;
      fitDst = Rect.fromLTWH(dst.left - (w - dst.width) / 2, dst.top, w, h);
    } else {
      final w = dst.width;
      final h = w / imgR;
      fitDst = Rect.fromLTWH(dst.left, dst.top - (h - dst.height) / 2, w, h);
    }
    canvas.drawImageRect(img, src, fitDst, Paint());
    canvas.restore();
  }

  static void _drawEmpty(Canvas canvas, Rect rect, int month) {
    final rrect =
        RRect.fromRectAndRadius(rect, const Radius.circular(12));
    canvas.drawRRect(
        rrect, Paint()..color = const Color(0xFF2A1A0A));
    canvas.drawRRect(
        rrect,
        Paint()
          ..color = const Color(0x33FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
  }

  static void _drawText(
    Canvas canvas,
    String text,
    double fontSize,
    Color color,
    ui.FontWeight weight,
    double maxWidth,
    double x,
    double y, {
    bool center = false,
    bool right = false,
  }) {
    final style = ui.TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: weight,
      locale: const Locale('ko', 'KR'),
    );
    final para = (ui.ParagraphBuilder(
            ui.ParagraphStyle(textDirection: ui.TextDirection.ltr))
          ..pushStyle(style)
          ..addText(text))
        .build()
      ..layout(ui.ParagraphConstraints(width: maxWidth));
    double dx = x;
    if (center) dx = x - para.maxIntrinsicWidth / 2;
    if (right) dx = x - para.maxIntrinsicWidth;
    canvas.drawParagraph(para, Offset(dx, y));
  }

  static Future<ui.Image> _loadImage(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
