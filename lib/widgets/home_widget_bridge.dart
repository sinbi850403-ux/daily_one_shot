import 'package:home_widget/home_widget.dart';

import '../data/entry_repository.dart';
import '../data/photo_storage.dart';

/// Pushes today + memory data to the native home-screen widget.
/// Native side (WidgetKit on iOS, Glance on Android) reads these keys.
class HomeWidgetBridge {
  HomeWidgetBridge({required this.repo, required this.storage});
  final EntryRepository repo;
  final PhotoStorage storage;

  static const _kTodayHasEntry = 'today_has_entry';
  static const _kTodayThumbPath = 'today_thumb_path';
  static const _kMemoryMemo = 'memory_memo';
  static const _kMemoryThumbPath = 'memory_thumb_path';
  static const _kMemoryYearsAgo = 'memory_years_ago';

  Future<void> refresh() async {
    final today = DateTime.now();
    final todays = await repo.getByDate(today);
    if (todays != null) {
      final thumb = await storage.thumbFileForDay(todays.date);
      await HomeWidget.saveWidgetData(_kTodayHasEntry, true);
      await HomeWidget.saveWidgetData(_kTodayThumbPath, thumb.path);
    } else {
      await HomeWidget.saveWidgetData(_kTodayHasEntry, false);
      await HomeWidget.saveWidgetData(_kTodayThumbPath, null);
    }

    final memories = await repo.onThisDayInPriorYears(today);
    if (memories.isNotEmpty) {
      final pick = memories.first;
      final thumb = await storage.thumbFileForDay(pick.date);
      await HomeWidget.saveWidgetData(_kMemoryMemo, pick.memo);
      await HomeWidget.saveWidgetData(_kMemoryThumbPath, thumb.path);
      await HomeWidget.saveWidgetData(
        _kMemoryYearsAgo,
        today.year - pick.date.year,
      );
    } else {
      await HomeWidget.saveWidgetData(_kMemoryMemo, null);
      await HomeWidget.saveWidgetData(_kMemoryThumbPath, null);
      await HomeWidget.saveWidgetData(_kMemoryYearsAgo, null);
    }

    await HomeWidget.updateWidget(
      androidName: 'DailyOneShotWidgetProvider',
      iOSName: 'DailyOneShotWidget',
    );
  }
}
