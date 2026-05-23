import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BiometricLock {
  BiometricLock._();
  static final BiometricLock instance = BiometricLock._();

  bool _enabled = false;
  bool _unlockedThisSession = false;

  bool get enabled => _enabled;
  bool get unlockedThisSession => _unlockedThisSession;

  Future<File> _settingsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, '.settings.json'));
  }

  Future<void> load() async {
    try {
      final file = await _settingsFile();
      if (await file.exists()) {
        final map =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        _enabled = map['biometric_lock'] as bool? ?? false;
      }
    } catch (_) {
      _enabled = false;
    }
  }

  Future<void> setEnabled(bool v) async {
    _enabled = v;
    if (!v) _unlockedThisSession = false;
    try {
      final file = await _settingsFile();
      await file.writeAsString(
          jsonEncode({'biometric_lock': v}));
    } catch (_) {}
  }

  void markUnlocked() {
    _unlockedThisSession = true;
  }

  void lock() {
    _unlockedThisSession = false;
  }
}
