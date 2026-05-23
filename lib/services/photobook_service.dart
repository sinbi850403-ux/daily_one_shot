import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/database.dart';
import '../data/photo_storage.dart';

class PhotobookService {
  PhotobookService._();
  static final instance = PhotobookService._();

  /// 전체 entries를 연/월별로 묶어 PDF 파일 생성 후 반환.
  Future<File> generate(List<Entry> entries, PhotoStorage storage) async {
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
    );

    // 표지
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Container(
          decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF1A0F00)),
          child: pw.Center(
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  '하루 한 장',
                  style: pw.TextStyle(
                    font: pw.Font.helveticaBold(),
                    fontSize: 48,
                    color: PdfColors.orange200,
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  '${entries.length}일간의 기록',
                  style: pw.TextStyle(
                    fontSize: 18,
                    color: PdfColors.white,
                  ),
                ),
                if (entries.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  pw.Text(
                    '${_fmt(entries.last.date)} ~ ${_fmt(entries.first.date)}',
                    style: const pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.grey300,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    // 각 entry 한 페이지
    for (final entry in entries) {
      Uint8List? imgBytes;
      try {
        final file = await storage.originalFile(entry.photoPath);
        if (await file.exists()) {
          imgBytes = await file.readAsBytes();
        }
      } catch (_) {}

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // 날짜
                pw.Text(
                  _fmtFull(entry.date),
                  style: pw.TextStyle(
                    font: pw.Font.helveticaBold(),
                    fontSize: 16,
                    color: PdfColors.brown800,
                  ),
                ),
                if (entry.weather != null)
                  pw.Text(
                    entry.weather!,
                    style: const pw.TextStyle(
                        fontSize: 11, color: PdfColors.grey700),
                  ),
                pw.SizedBox(height: 12),
                // 사진
                if (imgBytes != null)
                  pw.Expanded(
                    child: pw.Center(
                      child: pw.Image(
                        pw.MemoryImage(imgBytes),
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  )
                else
                  pw.Expanded(
                    child: pw.Container(
                      color: PdfColors.grey200,
                      child: pw.Center(
                        child: pw.Text('사진 없음',
                            style:
                                const pw.TextStyle(color: PdfColors.grey)),
                      ),
                    ),
                  ),
                // 메모
                if (entry.memo.isNotEmpty) ...[
                  pw.SizedBox(height: 12),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.orange50,
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Text(
                      entry.memo,
                      style: const pw.TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      );
    }

    final bytes = await doc.save();
    final tmp = await getTemporaryDirectory();
    final stamp =
        DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final out = File('${tmp.path}/photobook_$stamp.pdf');
    await out.writeAsBytes(bytes);
    return out;
  }

  static String _fmt(DateTime d) =>
      DateFormat('yyyy.MM.dd').format(d.toLocal());

  static String _fmtFull(DateTime d) =>
      DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(d.toLocal());
}
