import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../data/database.dart';
import '../viewer/photo_viewer_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<Entry> _results = [];
  bool _searched = false;
  bool _searching = false;

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    final scope = AppScope.of(context);
    final r = await scope.repo.search(q);
    if (!mounted) return;
    setState(() {
      _results = r;
      _searched = true;
      _searching = false;
    });
  }

  void _openViewer(Entry entry) async {
    final scope = AppScope.of(context);
    final file = await scope.storage.originalFile(entry.photoPath);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoViewerScreen(
          entry: entry,
          file: file,
          heroTag: 'search-${entry.date.toIso8601String()}',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: const InputDecoration(
            hintText: '메모 검색',
            border: InputBorder.none,
            filled: false,
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _search),
        ],
      ),
      body: _searching
          ? const Center(child: CircularProgressIndicator())
          : !_searched
              ? const Center(
                  child: Text('단어를 입력해 검색하세요',
                      style: TextStyle(color: Colors.grey)))
              : _results.isEmpty
                  ? const Center(
                      child: Text('검색 결과 없음',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final e = _results[i];
                        final heroTag =
                            'search-${e.date.toIso8601String()}';
                        return ListTile(
                          onTap: () => _openViewer(e),
                          leading: FutureBuilder<File>(
                            future: scope.storage.thumbFileForDay(e.date),
                            builder: (ctx, snap) {
                              final file = snap.data;
                              if (file == null || !file.existsSync()) {
                                return Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Theme.of(ctx)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                );
                              }
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Hero(
                                  tag: heroTag,
                                  child: SizedBox(
                                    width: 56,
                                    height: 56,
                                    child: Image.file(file,
                                        fit: BoxFit.cover),
                                  ),
                                ),
                              );
                            },
                          ),
                          title: Text(
                            DateFormat('yyyy년 M월 d일', 'ko_KR')
                                .format(e.date),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                          subtitle: e.memo.isNotEmpty
                              ? Text(e.memo,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis)
                              : const Text('메모 없음',
                                  style:
                                      TextStyle(color: Colors.grey)),
                          trailing:
                              const Icon(Icons.chevron_right),
                        );
                      },
                    ),
    );
  }
}
