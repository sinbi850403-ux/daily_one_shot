import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../data/database.dart';
import '../../data/entry_repository.dart';
import '../../data/photo_storage.dart';
import '../../widgets/home_widget_bridge.dart';
import '../../ads/ad_banner.dart';
import '../../services/badge_service.dart' as badges;
import '../../services/weather_service.dart';
import '../memory/memory_screen.dart';
import '../viewer/photo_viewer_screen.dart';
import '../viewer/share_sheet.dart';

class TodayScreen extends StatefulWidget {
  /// [targetDate] 가 null 이면 오늘, 아니면 해당 날짜로 진입.
  const TodayScreen({super.key, this.targetDate});

  final DateTime? targetDate;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  Entry? _entry;
  bool _loading = true;
  bool _saving = false;

  Uint8List? _pendingPhotoBytes;

  final _memoController = TextEditingController();
  final _picker = ImagePicker();

  DateTime get _targetDay => widget.targetDate ?? DateTime.now();
  bool get _isToday => widget.targetDate == null;

  bool get _hasPhoto => _pendingPhotoBytes != null || _entry != null;
  bool get _hasUnsavedPhoto => _pendingPhotoBytes != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final scope = AppScope.of(context);
    final today = dayKey(_targetDay);
    final entry = await scope.repo.getByDate(today);
    if (!mounted) return;
    setState(() {
      _entry = entry;
      _memoController.text = entry?.memo ?? '';
      _pendingPhotoBytes = null;
      _loading = false;
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 4096,
      maxHeight: 4096,
      imageQuality: 92,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _pendingPhotoBytes = bytes);
  }

  Future<void> _save() async {
    if (!_hasPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 먼저 선택해 주세요')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final scope = AppScope.of(context);
      final memo = _memoController.text.trim();
      String relativePath;

      // 날씨 + GPS (백그라운드, 실패해도 저장 진행)
      final weatherFuture = _isToday && _entry == null
          ? WeatherService.instance.fetch()
          : Future.value(null);

      if (_pendingPhotoBytes != null) {
        if (_entry != null) {
          final oldFile =
              await scope.storage.originalFile(_entry!.photoPath);
          imageCache.evict(FileImage(oldFile));
        }
        relativePath =
            await scope.storage.saveForDay(_targetDay, _pendingPhotoBytes!);
        final newFile = await scope.storage.originalFile(relativePath);
        imageCache.evict(FileImage(newFile));
      } else {
        relativePath = _entry!.photoPath;
      }

      final weather = await weatherFuture;

      await scope.repo.upsert(
        day: _targetDay,
        photoPath: relativePath,
        memo: memo,
        weather: weather?.label,
        latitude: weather?.latitude,
        longitude: weather?.longitude,
      );

      if (_isToday) {
        unawaited(
          HomeWidgetBridge(repo: scope.repo, storage: scope.storage)
              .refresh(),
        );
      }

      await _load();

      if (!mounted) return;

      // 뱃지 체크
      final streak = await scope.repo.currentStreak();
      final total = await scope.repo.totalCount();
      final newBadges = await badges.BadgeService.instance
          .checkAndAward(streak: streak, total: total);

      if (!mounted) return;
      if (newBadges.isNotEmpty) {
        _showBadgeDialog(newBadges.first);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(weather != null
                ? '저장됐어요 ✓  ${weather.label}'
                : '저장됐어요 ✓'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showBadgeDialog(badges.Badge badge) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${badge.emoji} 뱃지 획득!'),
        content: Text('${badge.title} 달성을 축하합니다!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEntry() async {
    final entry = _entry;
    if (entry == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('사진과 메모를 삭제할까요?\n되돌릴 수 없습니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final scope = AppScope.of(context);
    final oldFile = await scope.storage.originalFile(entry.photoPath);
    imageCache.evict(FileImage(oldFile));
    await scope.repo.delete(entry.id);
    await scope.storage.deleteForDay(entry.date);
    if (_isToday) {
      unawaited(
        HomeWidgetBridge(repo: scope.repo, storage: scope.storage)
            .refresh(),
      );
    }
    if (!mounted) return;
    if (_isToday) {
      setState(() {
        _entry = null;
        _pendingPhotoBytes = null;
        _memoController.clear();
      });
    } else {
      Navigator.pop(context); // 과거 날짜면 닫기
    }
  }

  Future<void> _share() async {
    final entry = _entry;
    if (entry == null) return;
    final scope = AppScope.of(context);
    final file = await scope.storage.originalFile(entry.photoPath);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ShareSheet(entry: entry, file: file),
    );
  }

  void _openViewer() async {
    final entry = _entry;
    if (entry == null) return;
    final scope = AppScope.of(context);
    final file = await scope.storage.originalFile(entry.photoPath);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoViewerScreen(
          entry: entry,
          file: file,
          heroTag: 'today-photo',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat(
            _isToday ? 'yyyy년 M월 d일 (E)' : 'yyyy년 M월 d일 (E)', 'ko_KR')
        .format(_targetDay);
    final scope = AppScope.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isToday ? '오늘' : dateLabel),
        // 과거 날짜 입력 화면은 날짜를 타이틀로 표시하고 네비게이션 없음
        actions: _isToday
            ? [
                if (_entry != null) ...[
                  IconButton(
                    tooltip: '공유',
                    icon: const Icon(Icons.ios_share_outlined),
                    onPressed: _share,
                  ),
                  IconButton(
                    tooltip: '오늘 기록 삭제',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _deleteEntry,
                  ),
                ],
                // 이날의 기억 버튼
                FutureBuilder<List>(
                  future:
                      scope.repo.onThisDayInPriorYears(DateTime.now()),
                  builder: (ctx, snap) {
                    final hasMemory =
                        (snap.data?.isNotEmpty ?? false);
                    return IconButton(
                      tooltip: '이날의 기억',
                      icon: Icon(
                        Icons.auto_awesome_outlined,
                        color: hasMemory
                            ? theme.colorScheme.primary
                            : null,
                      ),
                      onPressed: () => Navigator.of(context)
                          .push(MaterialPageRoute(
                              builder: (_) => const MemoryScreen())),
                    );
                  },
                ),
                IconButton(
                  tooltip: '검색',
                  icon: const Icon(Icons.search),
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/search'),
                ),
                IconButton(
                  tooltip: '타임라인',
                  icon: const Icon(Icons.calendar_month_outlined),
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/timeline'),
                ),
                IconButton(
                  tooltip: '설정',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/settings'),
                ),
              ]
            : [
                if (_entry != null) ...[
                  IconButton(
                    tooltip: '공유',
                    icon: const Icon(Icons.ios_share_outlined),
                    onPressed: _share,
                  ),
                  IconButton(
                    tooltip: '기록 삭제',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _deleteEntry,
                  ),
                ],
              ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 날짜 + 미저장 뱃지 (오늘 화면에서만)
                          if (_isToday)
                            Row(
                              children: [
                                Text(
                                  dateLabel,
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.w700),
                                ),
                                if (_hasUnsavedPhoto) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme
                                          .tertiaryContainer,
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '미저장',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme
                                            .onTertiaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          if (_isToday) const SizedBox(height: 12),
                          // 사진 카드
                          Expanded(
                            child: _PhotoCard(
                              pendingBytes: _pendingPhotoBytes,
                              entry: _entry,
                              storage: scope.storage,
                              onTap: _showPickerSheet,
                              onViewerTap:
                                  _entry != null ? _openViewer : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _memoController,
                            maxLength: 200,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: _hasPhoto
                                  ? '오늘 한 줄 (선택)'
                                  : '사진을 먼저 선택해 주세요',
                            ),
                            enabled: _hasPhoto,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  // 광고 배너 (무료 사용자만)
                  const AdBannerWidget(),
                  // 저장 버튼
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Text('저장',
                                style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showPickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('카메라'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── 사진 카드 ──────────────────────────────────────────────────────────────

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.pendingBytes,
    required this.entry,
    required this.storage,
    required this.onTap,
    this.onViewerTap,
  });

  final Uint8List? pendingBytes;
  final Entry? entry;
  final PhotoStorage storage;
  final VoidCallback onTap;
  final VoidCallback? onViewerTap; // 저장된 사진 → 뷰어

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (pendingBytes != null) {
      return _photoShell(
        onTap: onTap,
        child: Image.memory(
          pendingBytes!,
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      );
    }

    if (entry != null) {
      return FutureBuilder<File>(
        future: storage.originalFile(entry!.photoPath),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final file = snap.data;
          if (file == null || !file.existsSync()) {
            return _emptyCard(theme,
                label: '사진 파일 없음\n탭해서 다시 선택');
          }
          return _photoShell(
            // 저장된 사진: 탭 → 뷰어, 없으면 picker
            onTap: onViewerTap ?? onTap,
            child: Hero(
              tag: 'today-photo',
              child: Image.file(
                file,
                fit: BoxFit.cover,
                width: double.infinity,
                key: ValueKey(
                    entry!.updatedAt.millisecondsSinceEpoch),
              ),
            ),
          );
        },
      );
    }

    return _emptyCard(theme);
  }

  Widget _photoShell({required Widget child, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard(ThemeData theme,
      {String label = '오늘 한 장 남기기'}) {
    final cs = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.surfaceContainerHighest,
                cs.surfaceContainerHigh,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.6),
              width: 1.2,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add_a_photo_outlined,
                      size: 36, color: cs.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '탭해서 사진 선택',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void unawaited(Future<void> f) {}
