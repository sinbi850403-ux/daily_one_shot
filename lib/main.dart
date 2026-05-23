import 'dart:async';

import 'package:flutter/material.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR');

  final db = AppDatabase();
  final storage = PhotoStorage();
  final repo = EntryRepository(db);
  final backup = BackupService(db: db, repo: repo, storage: storage);

  await BiometricLock.instance.load();
  unawaited(PurchaseController.instance.init());

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
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7C8DA0),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7C8DA0),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        routes: {
          '/': (_) => const TodayScreen(),
          '/timeline': (_) => const TimelineScreen(),
          '/search': (_) => const SearchScreen(),
          '/settings': (_) => const SettingsScreen(),
        },
      ),
    );
  }
}
