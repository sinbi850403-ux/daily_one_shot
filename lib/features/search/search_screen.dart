import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../data/database.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<Entry> _results = [];
  bool _searched = false;

  Future<void> _search() async {
    final scope = AppScope.of(context);
    final q = _controller.text.trim();
    final r = q.isEmpty ? <Entry>[] : await scope.repo.search(q);
    if (!mounted) return;
    setState(() {
      _results = r;
      _searched = true;
    });
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
          ),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.search), onPressed: _search),
        ],
      ),
      body: !_searched
          ? const Center(child: Text('단어를 입력해 검색하세요'))
          : _results.isEmpty
              ? const Center(child: Text('검색 결과 없음'))
              : ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final e = _results[i];
                    return ListTile(
                      leading: FutureBuilder<File>(
                        future: scope.storage.thumbFileForDay(e.date),
                        builder: (ctx, snap) {
                          final file = snap.data;
                          if (file == null) {
                            return const SizedBox(width: 56, height: 56);
                          }
                          return SizedBox(
                            width: 56,
                            height: 56,
                            child: Image.file(file, fit: BoxFit.cover),
                          );
                        },
                      ),
                      title: Text(
                        DateFormat('yyyy년 M월 d일', 'ko_KR').format(e.date),
                      ),
                      subtitle: Text(
                        e.memo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
    );
  }
}
