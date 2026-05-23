import 'package:flutter/services.dart';

/// Android ACTION_SEND를 직접 호출해 파일/텍스트 공유.
/// share_plus 없이 MethodChannel로 구현.
class ShareChannel {
  static const _ch = MethodChannel('com.dailyoneshot/share');

  static Future<void> shareFile(String path, {String? text}) async {
    try {
      await _ch.invokeMethod('shareFile', {
        'path': path,
        'text': text ?? '',
        'mimeType': _mimeType(path),
      });
    } catch (_) {}
  }

  static Future<void> shareText(String text) async {
    try {
      await _ch.invokeMethod('shareText', {'text': text});
    } catch (_) {}
  }

  static String _mimeType(String path) {
    if (path.endsWith('.zip')) return 'application/zip';
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
    if (path.endsWith('.png')) return 'image/png';
    return '*/*';
  }
}
