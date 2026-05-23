import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'daily_reminder';
  static const _notifId = 1;

  bool _initialized = false;
  bool _enabled = false;
  int _hour = 21;
  int _minute = 0;

  bool get enabled => _enabled;
  TimeOfDay get time => TimeOfDay(hour: _hour, minute: _minute);

  Future<File> _settingsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, '.notif_settings.json'));
  }

  Future<void> init() async {
    try {
      tz.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
      } catch (_) {}

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(
        const InitializationSettings(android: android),
      );
      _initialized = true;
    } catch (_) {}

    await _loadSettings();

    // 앱 시작 시 활성화 상태면 재스케줄
    if (_enabled) _schedule().ignore();
  }

  Future<void> _loadSettings() async {
    try {
      final f = await _settingsFile();
      if (await f.exists()) {
        final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        _enabled = map['enabled'] as bool? ?? false;
        _hour = map['hour'] as int? ?? 21;
        _minute = map['minute'] as int? ?? 0;
      }
    } catch (_) {}
  }

  Future<void> _saveSettings() async {
    try {
      final f = await _settingsFile();
      await f.writeAsString(jsonEncode({
        'enabled': _enabled,
        'hour': _hour,
        'minute': _minute,
      }));
    } catch (_) {}
  }

  /// Android 13+ 알림 권한 요청. 이미 허용돼 있으면 true 즉시 반환.
  Future<bool> requestPermission() async {
    if (!_initialized) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return true; // 플랫폼 지원 안 하면 통과
      final result = await android.requestNotificationsPermission();
      return result ?? true;
    } catch (_) {
      return true; // 예외 시 허용으로 간주
    }
  }

  Future<void> setEnabled(bool v, {TimeOfDay? time}) async {
    _enabled = v;
    if (time != null) {
      _hour = time.hour;
      _minute = time.minute;
    }
    await _saveSettings();
    if (v) {
      await _schedule();
    } else {
      try { await _plugin.cancel(_notifId); } catch (_) {}
    }
  }

  Future<void> setTime(TimeOfDay time) async {
    _hour = time.hour;
    _minute = time.minute;
    await _saveSettings();
    if (_enabled) await _schedule();
  }

  Future<void> _schedule() async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(_notifId);

      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(
          tz.local, now.year, now.month, now.day, _hour, _minute);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        _channelId,
        '매일 기록 알림',
        channelDescription: '오늘 사진을 남기지 않았을 때 알려드립니다',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

      await _plugin.zonedSchedule(
        _notifId,
        '하루 한 장 📷',
        '오늘 한 장 남겼나요? 지금 기록해보세요.',
        scheduled,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // 스케줄 실패해도 enabled 상태는 유지
    }
  }
}

