import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../data/database.dart';
import '../../data/entry_repository.dart';
import '../../widgets/home_widget_bridge.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  Entry? _entry;
  bool _loading = true;
  final _memoController = TextEditingController();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final scope = AppScope.of(context);
    final today = dayKey(DateTime.now());
    final entry = await scope.repo.getByDate(today);
    if (!mounted) return;
    setState(() {
      _entry = entry;
      _memoController.text = entry?.memo ?? '';
      _loading = false;
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final scope = AppScope.of(context);
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 4096,
      maxHeight: 4096,
      imageQuality: 92,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final today = DateTime.now();
    final relative = await scope.storage.saveForDay(today, bytes);
    await scope.repo.upsert(
      day: today,
      photoPath: relative,
      memo: _memoController.text.trim(),
    );
    await HomeWidgetBridge(repo: scope.repo, storage: scope.storage).refresh();
    await _load();
  }

  Future<void> _saveMemo() async {
    final entry = _entry;
    if (entry == null) return;
    final scope = AppScope.of(context);
    await scope.repo.upsert(
      day: entry.date,
      photoPath: entry.photoPath,
      memo: _memoController.text.trim(),
    );
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dateLabel = DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(today);
    final scope = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘'),
        actions: [
          IconButton(
            tooltip: '검색',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).pushNamed('/search'),
          ),
          IconButton(
            tooltip: '타임라인',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => Navigator.of(context).pushNamed('/timeline'),
          ),
          IconButton(
            tooltip: '설정',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateLabel,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _PhotoCard(
                        entry: _entry,
                        storage: scope.storage,
                        onTapEmpty: _showPickerSheet,
                        onTapFilled: _showPickerSheet,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _memoController,
                      maxLength: 200,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: '오늘 한 줄',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _saveMemo(),
                    ),
                  ],
                ),
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

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.entry,
    required this.storage,
    required this.onTapEmpty,
    required this.onTapFilled,
  });

  final Entry? entry;
  final dynamic storage;
  final VoidCallback onTapEmpty;
  final VoidCallback onTapFilled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = entry;
    if (e == null) {
      return InkWell(
        onTap: onTapEmpty,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
              style: BorderStyle.solid,
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_a_photo_outlined, size: 48),
                SizedBox(height: 12),
                Text('오늘 한 장 남기기'),
              ],
            ),
          ),
        ),
      );
    }
    return FutureBuilder<File>(
      future: storage.originalFile(e.photoPath),
      builder: (ctx, snap) {
        final file = snap.data;
        if (file == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return InkWell(
          onTap: onTapFilled,
          borderRadius: BorderRadius.circular(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(file, fit: BoxFit.cover, width: double.infinity),
          ),
        );
      },
    );
  }
}
