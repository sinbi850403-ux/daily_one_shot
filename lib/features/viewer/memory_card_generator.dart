import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/database.dart';

/// 공유용 메모리 카드 이미지(1080×1350 PNG)를 생성합니다.
/// photo + 날짜 + 메모 + 워터마크를 캔버스에 직접 그립니다.
class MemoryCardGenerator {
  static const double _w = 1080;
  static const double _h = 1350; // 4:5 portrait — 인스타/카카오 최적

  static Future<File> generate(Entry entry, File photoFile) async {
    // 1. 사진 로드
    final photoImage = await _loadUiImage(photoFile);

    // 2. 캔버스 준비
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, _w, _h));

    // 3. 사진 full-bleed
    _drawCoverImage(canvas, photoImage);

    // 4. 하단 그라디언트 오버레이
    _drawGradient(canvas);

    // 5. 텍스트 영역
    await _drawText(canvas, entry);

    // 6. 워터마크
    await _drawWatermark(canvas);

    photoImage.dispose();

    // 7. 이미지 → 파일 저장
    final picture = recorder.endRecording();
    final image = await picture.toImage(_w.toInt(), _h.toInt());
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    final tmp = await getTemporaryDirectory();
    final outFile = File('${tmp.path}/share_card.png');
    await outFile.writeAsBytes(byteData!.buffer.asUint8List());
    return outFile;
  }

  // ── helpers ─────────────────────────────────────────────────────────

  static Future<ui.Image> _loadUiImage(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  static void _drawCoverImage(Canvas canvas, ui.Image img) {
    final src = Rect.fromLTWH(
        0, 0, img.width.toDouble(), img.height.toDouble());
    // cover-fit: 짧은 쪽을 기준으로 꽉 채운 뒤 중앙 크롭
    final imgRatio = img.width / img.height;
    final cardRatio = _w / _h;
    Rect dst;
    if (imgRatio > cardRatio) {
      // 이미지가 더 넓음 → 높이 맞추고 좌우 크롭
      final fitH = _h;
      final fitW = fitH * imgRatio;
      final xOff = (_w - fitW) / 2;
      dst = Rect.fromLTWH(xOff, 0, fitW, fitH);
    } else {
      // 이미지가 더 좁음 → 너비 맞추고 상하 크롭
      final fitW = _w;
      final fitH = fitW / imgRatio;
      final yOff = (_h - fitH) / 2;
      dst = Rect.fromLTWH(0, yOff, fitW, fitH);
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, _w, _h));
    canvas.drawImageRect(img, src, dst, Paint());
    canvas.restore();
  }

  static void _drawGradient(Canvas canvas) {
    const gradientH = _h * 0.48;
    final rect =
        Rect.fromLTWH(0, _h - gradientH, _w, gradientH);
    final shader = const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [Color(0xD9000000), Color(0x00000000)],
      stops: [0.0, 1.0],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = shader);
  }

  static Future<void> _drawText(Canvas canvas, Entry entry) async {
    final locale = 'ko_KR';
    final dateLabel =
        DateFormat('yyyy년 M월 d일 (E)', locale).format(entry.date);
    final yearLabel = '${entry.date.year}';

    const leftPad = 72.0;
    const bottomPad = 90.0;
    double y = _h - bottomPad;

    // 워터마크 공간 확보 (아래에서 위로 배치)
    y -= 56; // watermark row

    // 메모
    if (entry.memo.isNotEmpty) {
      final memoText = _buildParagraph(
        entry.memo,
        fontSize: 42,
        color: const Color(0xCCFFFFFF),
        maxLines: 3,
        maxWidth: _w - leftPad * 2,
      );
      y -= memoText.height + 32;
      canvas.drawParagraph(memoText, Offset(leftPad, y));
    }

    // 구분선
    y -= 28;
    canvas.drawLine(
      Offset(leftPad, y),
      Offset(_w - leftPad, y),
      Paint()
        ..color = const Color(0x66FFFFFF)
        ..strokeWidth = 2,
    );
    y -= 28;

    // 날짜 (큰 텍스트)
    final datePara = _buildParagraph(
      dateLabel,
      fontSize: 58,
      fontWeight: ui.FontWeight.w700,
      color: Colors.white,
      maxWidth: _w - leftPad * 2,
    );
    y -= datePara.height;
    canvas.drawParagraph(datePara, Offset(leftPad, y));
    y -= 20;

    // 연도 (작은 레이블)
    final yearPara = _buildParagraph(
      yearLabel,
      fontSize: 34,
      color: const Color(0x99FFFFFF),
      maxWidth: _w - leftPad * 2,
      letterSpacing: 4,
    );
    y -= yearPara.height;
    canvas.drawParagraph(yearPara, Offset(leftPad, y));
  }

  static Future<void> _drawWatermark(Canvas canvas) async {
    const text = '하루 한 장  📷';
    final para = _buildParagraph(
      text,
      fontSize: 32,
      color: const Color(0x80FFFFFF),
      maxWidth: 500,
    );
    final x = _w - para.maxIntrinsicWidth - 72;
    final y = _h - 90.0 - para.height;
    canvas.drawParagraph(para, Offset(x, y));
  }

  static ui.Paragraph _buildParagraph(
    String text, {
    required double fontSize,
    required Color color,
    required double maxWidth,
    ui.FontWeight fontWeight = ui.FontWeight.w400,
    int? maxLines,
    double letterSpacing = 0,
  }) {
    final style = ui.TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      locale: const Locale('ko', 'KR'),
    );
    final paragraphStyle = ui.ParagraphStyle(
      textDirection: ui.TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: maxLines != null ? '…' : null,
    );
    return (ui.ParagraphBuilder(paragraphStyle)
          ..pushStyle(style)
          ..addText(text))
        .build()
      ..layout(ui.ParagraphConstraints(width: maxWidth));
  }
}
