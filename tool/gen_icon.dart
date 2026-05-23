// dart run tool/gen_icon.dart
// 앱 아이콘 1024×1024 PNG 생성

import 'dart:io';
import 'package:image/image.dart';

void main() {
  final img = Image(width: 1024, height: 1024);

  // ── 배경: 따뜻한 amber-brown ──────────────────────────────
  fill(img, color: ColorRgb8(176, 120, 80));

  // 배경 중앙 살짝 밝게 (비네팅 반대)
  for (var y = 0; y < 1024; y++) {
    for (var x = 0; x < 1024; x++) {
      final dx = (x - 512) / 512.0;
      final dy = (y - 512) / 512.0;
      final dist = (dx * dx + dy * dy).clamp(0, 1);
      final bright = (1 - dist * 0.25);
      final r = (176 * bright).round().clamp(0, 255);
      final g = (120 * bright).round().clamp(0, 255);
      final b = (80  * bright).round().clamp(0, 255);
      img.setPixelRgb(x, y, r, g, b);
    }
  }

  // ── 카메라 바디 (흰색 둥근 사각형) ───────────────────────
  const cx1 = 130, cy1 = 300, cx2 = 894, cy2 = 760;
  const cr = 70;
  _fillRoundRect(img, cx1, cy1, cx2, cy2, cr, ColorRgb8(255, 255, 255));

  // ── 뷰파인더 돌출부 (상단 중앙) ──────────────────────────
  _fillRoundRect(img, 370, 235, 654, 335, 35, ColorRgb8(255, 255, 255));

  // ── 렌즈 링 ──────────────────────────────────────────────
  fillCircle(img, x: 512, y: 530, radius: 195,
      color: ColorRgb8(200, 160, 110)); // 가장 바깥 링
  fillCircle(img, x: 512, y: 530, radius: 175,
      color: ColorRgb8(245, 235, 220)); // 은색 링
  fillCircle(img, x: 512, y: 530, radius: 155,
      color: ColorRgb8(40,  28,  16));  // 어두운 렌즈
  fillCircle(img, x: 512, y: 530, radius: 115,
      color: ColorRgb8(60,  42,  22));  // 렌즈 내부
  fillCircle(img, x: 512, y: 530, radius: 70,
      color: ColorRgb8(80,  58,  30));  // 광각 반사
  // 하이라이트
  fillCircle(img, x: 468, y: 488, radius: 28,
      color: ColorRgba8(255, 255, 255, 100));
  fillCircle(img, x: 456, y: 476, radius: 14,
      color: ColorRgba8(255, 255, 255, 180));

  // ── 플래시 (우상단) ──────────────────────────────────────
  _fillRoundRect(img, 750, 325, 855, 385, 16, ColorRgb8(255, 230, 160));

  // ── 저장 ─────────────────────────────────────────────────
  final outDir = Directory('assets/icon');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  File('assets/icon/app_icon.png').writeAsBytesSync(encodePng(img));
  print('✓ assets/icon/app_icon.png 생성 완료');
}

void _fillRoundRect(
    Image img, int x1, int y1, int x2, int y2, int r, Color color) {
  // 가운데 rect
  fillRect(img, x1: x1 + r, y1: y1, x2: x2 - r, y2: y2, color: color);
  fillRect(img, x1: x1, y1: y1 + r, x2: x2, y2: y2 - r, color: color);
  // 네 모서리 원
  fillCircle(img, x: x1 + r, y: y1 + r, radius: r, color: color);
  fillCircle(img, x: x2 - r, y: y1 + r, radius: r, color: color);
  fillCircle(img, x: x1 + r, y: y2 - r, radius: r, color: color);
  fillCircle(img, x: x2 - r, y: y2 - r, radius: r, color: color);
}
