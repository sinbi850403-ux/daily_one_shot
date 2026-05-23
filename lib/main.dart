import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_scope.dart';
import 'data/backup_service.dart';
import 'data/database.dart';
import 'data/entry_repository.dart';
import 'data/photo_storage.dart';
import 'features/search/search_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/timeline/timeline_screen.dart';
import 'features/today/today_screen.dart';
import 'iap/purchase_controller.dart';
import 'lock/biometric_lock.dart';
import 'services/badge_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR');

  final db = AppDatabase();
  final storage = PhotoStorage();
  final repo = EntryRepository(db);
  final backup = BackupService(db: db, repo: repo, storage: storage);

  await BiometricLock.instance.load();
  await BadgeService.instance.load();
  unawaited(PurchaseController.instance.init());
  unawaited(MobileAds.instance.initialize());
  unawaited(NotificationService.instance.init());

  runApp(DailyOneShotApp(
    db: db,
    repo: repo,
    storage: storage,
    backup: backup,
  ));
}

class DailyOneShotApp extends StatelessWidget {
  const DailyOneShotApp({
    super.key,
    required this.db,
    required this.repo,
    required this.storage,
    required this.backup,
  });

  final AppDatabase db;
  final EntryRepository repo;
  final PhotoStorage storage;
  final BackupService backup;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      db: db,
      repo: repo,
      storage: storage,
      backup: backup,
      child: MaterialApp(
        title: '하루 한 장',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        routes: {
          '/': (_) => const TodayScreen(),
          '/timeline': (_) => const TimelineScreen(),
          '/search': (_) => const SearchScreen(),
          '/settings': (_) => const SettingsScreen(),
        },
      ),
    );
  }

  static ThemeData _buildTheme(Brightness brightness) {
    // 따뜻한 호박색 — 사진과 어울리고 일기장 분위기
    const seed = Color(0xFFB07850);
    final cs = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      // ── AppBar: 배경 없애고 타이틀 왼쪽 정렬
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      // ── FilledButton: 더 둥글게
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      // ── TextField: filled + 둥근 모서리
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outlineVariant, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
      ),
      // ── Card: 약간의 그림자
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: cs.surfaceContainerLow,
      ),
    );
  }
}
