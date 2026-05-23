import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class Badge {
  const Badge({required this.id, required this.title, required this.emoji});
  final String id;
  final String title;
  final String emoji;
}

const _badges = [
  Badge(id: 'first',   emoji: '📷', title: '첫 기록'),
  Badge(id: 'day7',    emoji: '🔥', title: '7일 연속'),
  Badge(id: 'day30',   emoji: '⭐', title: '30일 연속'),
  Badge(id: 'day100',  emoji: '💎', title: '100일 연속'),
  Badge(id: 'day365',  emoji: '🏆', title: '1년 연속'),
  Badge(id: 'total10', emoji: '🌱', title: '10장 기록'),
  Badge(id: 'total50', emoji: '🌿', title: '50장 기록'),
  Badge(id: 'total100',emoji: '🌳', title: '100장 기록'),
];

class BadgeService {
  BadgeService._();
  static final instance = BadgeService._();

  Set<String> _earned = {};

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, '.badges.json'));
  }

  Future<void> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final list = jsonDecode(await f.readAsString()) as List;
        _earned = list.cast<String>().toSet();
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode(_earned.toList()));
    } catch (_) {}
  }

  /// 현재 streak/total 기준으로 새로 획득된 뱃지 목록 반환.
  Future<List<Badge>> checkAndAward({
    required int streak,
    required int total,
  }) async {
    final newly = <Badge>[];

    void tryAward(String id) {
      if (!_earned.contains(id)) {
        _earned.add(id);
        newly.add(_badges.firstWhere((b) => b.id == id));
      }
    }

    if (total >= 1)   tryAward('first');
    if (streak >= 7)  tryAward('day7');
    if (streak >= 30) tryAward('day30');
    if (streak >= 100)tryAward('day100');
    if (streak >= 365)tryAward('day365');
    if (total >= 10)  tryAward('total10');
    if (total >= 50)  tryAward('total50');
    if (total >= 100) tryAward('total100');

    if (newly.isNotEmpty) await _save();
    return newly;
  }

  List<Badge> get all => _badges;
  bool isEarned(String id) => _earned.contains(id);
  Set<String> get earnedIds => Set.unmodifiable(_earned);
}
