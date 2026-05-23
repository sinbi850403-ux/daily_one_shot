import 'package:flutter/widgets.dart';

import 'data/backup_service.dart';
import 'data/database.dart';
import 'data/entry_repository.dart';
import 'data/photo_storage.dart';

/// Lightweight DI: no state-management package. The app is small enough that
/// an InheritedWidget exposing singletons is clearer than Riverpod/Provider.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.db,
    required this.repo,
    required this.storage,
    required this.backup,
    required super.child,
  });

  final AppDatabase db;
  final EntryRepository repo;
  final PhotoStorage storage;
  final BackupService backup;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing — wrap root with AppScope');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}
