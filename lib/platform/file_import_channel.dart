import 'package:flutter/services.dart';

/// Android에서 공유/열기로 전달된 ZIP 파일 경로를 가져옵니다.
class FileImportChannel {
  static const _ch = MethodChannel('com.dailyoneshot/file_import');

  /// 공유된 파일 경로. 없으면 null.
  static Future<String?> getSharedFilePath() async {
    try {
      final path = await _ch.invokeMethod<String>('getSharedFilePath');
      return path;
    } catch (_) {
      return null;
    }
  }
}
