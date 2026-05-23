/// Generates Play Store feature graphic (1024×500 PNG)
/// Run: dart tool/gen_feature_graphic.dart
import 'dart:io';
import 'dart:math';
import 'package:image/image.dart';

void main() async {
  const w = 1024;
  const h = 500;

  final img = Image(width: w, height: h);

  // ─── Background gradient (warm dark brown → darker) ───────────────────────
  for (var y = 0; y < h; y++) {
    final t = y / h;
    final r = _lerp(0x2C, 0x1A, t);
    final g = _lerp(0x1A, 0x0E, t);
    final b = _lerp(0x10, 0x08, t);
    for (var x = 0; x < w; x++) {
      img.setPixelRgb(x, y, r.round(), g.round(), b.round());
    }
  }

  // ─── Subtle warm vignette glow (center) ───────────────────────────────────
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final dx = (x - w / 2) / (w / 2);
      final dy = (y - h / 2) / (h / 2);
      final dist = sqrt(dx * dx + dy * dy);
      final glow = max(0.0, 1.0 - dist * 1.2);
      final p = img.getPixel(x, y);
      final nr = min(255, p.r.toInt() + (glow * 30).round());
      final ng = min(255, p.g.toInt() + (glow * 15).round());
      img.setPixelRgb(x, y, nr, ng, p.b.toInt());
    }
  }

  // ─── Camera icon (centered left-ish) ──────────────────────────────────────
  const cx = 280;
  const cy = 240;
  const camW = 160;
  const camH = 110;
  const camR = 14; // corner radius
  const gold = 0xFFB07850; // warm gold/brown
  const white = 0xFFFFFFFF;

  // Camera body
  _fillRoundRect(img, cx - camW ~/ 2, cy - camH ~/ 2, camW, camH, camR,
      0xFFB07850);

  // Viewfinder bump
  _fillRoundRect(
      img, cx - 22, cy - camH ~/ 2 - 16, 44, 18, 5, 0xFFB07850);

  // Lens outer ring
  _fillCircle(img, cx, cy + 6, 40, 0xFF7A5230);
  // Lens middle ring
  _fillCircle(img, cx, cy + 6, 30, 0xFFD4A574);
  // Lens inner
  _fillCircle(img, cx, cy + 6, 18, 0xFF2C1A10);
  // Lens glint
  _fillCircle(img, cx - 8, cy + 6 - 8, 5, 0x99FFFFFF);

  // ─── Right side: App name + tagline ───────────────────────────────────────
  // Draw "하루 한 장" as big text using pixel blocks (simple bitmapped text)
  _drawKoreanTitle(img, 440, 180);
  _drawTagline(img, 440, 290);

  // ─── Bottom-right: small badge icons ─────────────────────────────────────
  const badges = ['📷', '📅', '✨', '🔒'];
  // (rendered as colored dots since dart:image has no font for emoji)
  final dotColors = [0xFFB07850, 0xFFD4A574, 0xFFE8C49A, 0xFF7A5230];
  for (var i = 0; i < 4; i++) {
    _fillCircle(img, 440 + i * 56, 390, 14, dotColors[i]);
  }

  // ─── Fine horizontal divider line ─────────────────────────────────────────
  for (var x = 420; x < w - 40; x++) {
    img.setPixelRgb(x, 340, 0xB0, 0x78, 0x50);
  }

  // ─── Save ─────────────────────────────────────────────────────────────────
  final outDir = Directory('docs');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  final bytes = encodePng(img);
  File('docs/feature_graphic.png').writeAsBytesSync(bytes);
  print('✅  docs/feature_graphic.png (${bytes.length ~/ 1024} KB)');
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

double _lerp(num a, num b, double t) => a + (b - a) * t;

void _fillCircle(Image img, int cx, int cy, int r, int argb) {
  final a = (argb >> 24) & 0xFF;
  final red = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  for (var y = cy - r; y <= cy + r; y++) {
    for (var x = cx - r; x <= cx + r; x++) {
      if (x < 0 || y < 0 || x >= img.width || y >= img.height) continue;
      final dx = x - cx;
      final dy = y - cy;
      if (dx * dx + dy * dy <= r * r) {
        if (a == 255) {
          img.setPixelRgb(x, y, red, g, b);
        } else {
          final p = img.getPixel(x, y);
          final af = a / 255;
          final nr = (p.r * (1 - af) + red * af).round();
          final ng = (p.g * (1 - af) + g * af).round();
          final nb = (p.b * (1 - af) + b * af).round();
          img.setPixelRgb(x, y, nr, ng, nb);
        }
      }
    }
  }
}

void _fillRoundRect(
    Image img, int x, int y, int w, int h, int r, int argb) {
  final red = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  for (var py = y; py < y + h; py++) {
    for (var px = x; px < x + w; px++) {
      if (px < 0 || py < 0 || px >= img.width || py >= img.height) continue;
      if (_inRoundRect(px - x, py - y, w, h, r)) {
        img.setPixelRgb(px, py, red, g, b);
      }
    }
  }
}

bool _inRoundRect(int x, int y, int w, int h, int r) {
  if (x < r && y < r) return (x - r) * (x - r) + (y - r) * (y - r) <= r * r;
  if (x > w - r && y < r)
    return (x - (w - r)) * (x - (w - r)) + (y - r) * (y - r) <= r * r;
  if (x < r && y > h - r)
    return (x - r) * (x - r) + (y - (h - r)) * (y - (h - r)) <= r * r;
  if (x > w - r && y > h - r)
    return (x - (w - r)) * (x - (w - r)) +
            (y - (h - r)) * (y - (h - r)) <=
        r * r;
  return true;
}

/// Draw "하루 한 장" using thick strokes (2px dots in a grid)
void _drawKoreanTitle(Image img, int left, int top) {
  // Since dart:image has no TTF renderer, we approximate with a bold bar
  const barH = 10;
  const barSpacing = 6;
  final labels = ['하루 한 장'];
  for (var i = 0; i < 3; i++) {
    final y = top + i * (barH + barSpacing);
    final barW = [160, 120, 100][i];
    for (var py = y; py < y + barH; py++) {
      for (var px = left; px < left + barW; px++) {
        if (px >= img.width || py >= img.height) continue;
        img.setPixelRgb(px, py, 0xFF, 0xF5, 0xE6);
      }
    }
  }
  // Main title bar (larger)
  _fillRoundRect(img, left, top, 260, 56, 8, 0xFFFFEEDD);
  _fillRoundRect(img, left + 8, top + 8, 244, 40, 6, 0xFF2C1A10);
  // Accent line
  _fillRoundRect(img, left, top + 64, 200, 5, 2, 0xFFB07850);
}

void _drawTagline(Image img, int left, int top) {
  // Tagline placeholder bars
  const lines = [200, 160, 140];
  for (var i = 0; i < lines.length; i++) {
    final y = top + i * 22;
    _fillRoundRect(img, left, y, lines[i], 7, 3, 0xFF7A5230);
  }
}
