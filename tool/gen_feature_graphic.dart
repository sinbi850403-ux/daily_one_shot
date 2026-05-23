// dart run tool/gen_feature_graphic.dart
// Play Store 피처 그래픽 1024×500 PNG 생성

import 'dart:io';
import 'dart:math';
import 'package:image/image.dart';

void main() {
  const w = 1024;
  const h = 500;

  final img = Image(width: w, height: h);

  // ── 배경: 짙은 warm-brown 그라데이션 ──────────────────────────
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      // 세로 그라데이션 (위 밝게 → 아래 어둡게)
      final t = y / h;
      final r = _lerp(50, 28, t).round();
      final g = _lerp(30, 16, t).round();
      final b = _lerp(18, 10, t).round();
      // 가로 중앙 글로우
      final dx = (x - w * 0.38) / (w * 0.5);
      final dy = (y - h * 0.5) / (h * 0.6);
      final glow = max(0.0, 1.0 - sqrt(dx * dx + dy * dy)) * 22;
      img.setPixelRgb(x, y,
          (r + glow).round().clamp(0, 255),
          (g + glow * 0.5).round().clamp(0, 255),
          b.clamp(0, 255));
    }
  }

  // ── 왼쪽: 앱 아이콘 (카메라) ─────────────────────────────────
  const icX = 200; // 아이콘 중심 X
  const icY = 240; // 아이콘 중심 Y
  const icS = 150; // 아이콘 반크기

  // 아이콘 배경 원 (따뜻한 갈색)
  fillCircle(img, x: icX, y: icY, radius: icS + 10,
      color: ColorRgba8(176, 120, 80, 60));
  fillCircle(img, x: icX, y: icY, radius: icS,
      color: ColorRgb8(176, 120, 80));

  // 카메라 바디 (흰색 둥근 사각형, 아이콘 내부)
  _fillRoundRect(img,
      icX - 95, icY - 52,
      icX + 95, icY + 65,
      16, ColorRgb8(255, 255, 255));

  // 뷰파인더 돌출부
  _fillRoundRect(img,
      icX - 26, icY - 68,
      icX + 26, icY - 46,
      8, ColorRgb8(255, 255, 255));

  // 렌즈 링
  fillCircle(img, x: icX, y: icY + 8, radius: 40,
      color: ColorRgb8(200, 160, 110));
  fillCircle(img, x: icX, y: icY + 8, radius: 35,
      color: ColorRgb8(245, 235, 220));
  fillCircle(img, x: icX, y: icY + 8, radius: 30,
      color: ColorRgb8(40, 28, 16));
  fillCircle(img, x: icX, y: icY + 8, radius: 22,
      color: ColorRgb8(60, 42, 22));
  fillCircle(img, x: icX, y: icY + 8, radius: 13,
      color: ColorRgb8(80, 58, 30));
  // 하이라이트
  fillCircle(img, x: icX - 10, y: icY - 2, radius: 6,
      color: ColorRgba8(255, 255, 255, 160));

  // 플래시 점
  _fillRoundRect(img,
      icX + 55, icY - 42,
      icX + 80, icY - 28,
      5, ColorRgb8(255, 230, 160));

  // ── 구분선 (세로) ─────────────────────────────────────────────
  for (var y = 80; y < h - 80; y++) {
    img.setPixelRgb(380, y, 176, 120, 80);
    img.setPixelRgb(381, y, 100, 68, 44);
  }

  // ── 오른쪽: 텍스트 영역 (막대로 표현) ───────────────────────
  // 제목 "하루 한 장" — 큰 밝은 바
  _drawTextBar(img, 420, 130, 380, 52, ColorRgb8(255, 238, 210), 10);

  // 부제 "평생소장 사진 일기" — 중간 금색 바
  _drawTextBar(img, 420, 202, 280, 8, ColorRgb8(176, 120, 80), 4);

  // 설명 텍스트 줄 (3줄)
  _drawTextBar(img, 420, 258, 300, 7, ColorRgb8(130, 90, 60), 3);
  _drawTextBar(img, 420, 274, 260, 7, ColorRgb8(130, 90, 60), 3);
  _drawTextBar(img, 420, 290, 220, 7, ColorRgb8(130, 90, 60), 3);

  // ── 하단 배지 바 ─────────────────────────────────────────────
  // 배지 아이콘 (작은 원 4개)
  final badgeColors = [
    ColorRgb8(176, 120, 80),
    ColorRgb8(212, 165, 116),
    ColorRgb8(232, 196, 154),
    ColorRgb8(122, 82, 48),
  ];
  final badgeLabels = [14, 12, 12, 12]; // 바 너비
  for (var i = 0; i < 4; i++) {
    final bx = 420 + i * 100;
    fillCircle(img, x: bx, y: 380, radius: 20, color: badgeColors[i]);
    // 작은 텍스트 바
    _fillRoundRect(img, bx - 30, 408, bx + 30, 416, 3,
        ColorRgb8(100, 68, 44));
  }

  // ── 우하단 "7,000원" 가격 배지 ───────────────────────────────
  _fillRoundRect(img, 820, 350, 990, 420, 16,
      ColorRgb8(176, 120, 80));
  _drawTextBar(img, 838, 365, 80, 14, ColorRgb8(255, 238, 210), 5);
  _drawTextBar(img, 838, 388, 100, 9, ColorRgb8(255, 220, 170), 4);

  // ── 저장 ─────────────────────────────────────────────────────
  final outDir = Directory('docs');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  final bytes = encodePng(img);
  File('docs/feature_graphic.png').writeAsBytesSync(bytes);
  print('✓ docs/feature_graphic.png (${(bytes.length / 1024).round()} KB) 생성 완료');
}

// ── 유틸 ──────────────────────────────────────────────────────────────────────

double _lerp(num a, num b, double t) => a + (b - a) * t;

void _fillRoundRect(Image img, int x1, int y1, int x2, int y2, int r, Color c) {
  fillRect(img, x1: x1 + r, y1: y1, x2: x2 - r, y2: y2, color: c);
  fillRect(img, x1: x1, y1: y1 + r, x2: x2, y2: y2 - r, color: c);
  fillCircle(img, x: x1 + r, y: y1 + r, radius: r, color: c);
  fillCircle(img, x: x2 - r, y: y1 + r, radius: r, color: c);
  fillCircle(img, x: x1 + r, y: y2 - r, radius: r, color: c);
  fillCircle(img, x: x2 - r, y: y2 - r, radius: r, color: c);
}

/// 텍스트를 둥근 막대(pill)로 표현
void _drawTextBar(Image img, int x, int y, int w, int h, Color c, int r) {
  if (r > h ~/ 2) r = h ~/ 2;
  _fillRoundRect(img, x, y, x + w, y + h, r, c);
}
