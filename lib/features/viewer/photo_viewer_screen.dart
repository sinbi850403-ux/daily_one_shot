import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import 'share_sheet.dart';

/// 전체화면 사진 뷰어 — 핀치줌 + 오버레이 토글 + 공유
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.entry,
    required this.file,
    this.heroTag,
  });

  final Entry entry;
  final File file;
  final String? heroTag;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  final _transformCtrl = TransformationController();
  bool _overlayVisible = true;

  @override
  void initState() {
    super.initState();
    // 전체화면 몰입 모드
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  Future<void> _share() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ShareSheet(entry: widget.entry, file: widget.file),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(widget.entry.date);
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () =>
            setState(() => _overlayVisible = !_overlayVisible),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── 사진 (핀치줌) ────────────────────────────────────
            InteractiveViewer(
              transformationController: _transformCtrl,
              minScale: 0.8,
              maxScale: 6.0,
              onInteractionEnd: (_) {
                if (_transformCtrl.value.getMaxScaleOnAxis() <= 1.05) {
                  setState(() => _overlayVisible = true);
                }
              },
              child: Center(
                child: widget.heroTag != null
                    ? Hero(
                        tag: widget.heroTag!,
                        child: Image.file(widget.file,
                            fit: BoxFit.contain),
                      )
                    : Image.file(widget.file, fit: BoxFit.contain),
              ),
            ),

            // ── 상단 바 (뒤로 + 공유) ───────────────────────────
            AnimatedOpacity(
              opacity: _overlayVisible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: EdgeInsets.fromLTRB(4, safeTop + 4, 4, 0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.ios_share_outlined,
                          color: Colors.white),
                      tooltip: '공유',
                      onPressed: _share,
                    ),
                  ],
                ),
              ),
            ),

            // ── 하단 날짜 + 메모 ─────────────────────────────────
            AnimatedOpacity(
              opacity: _overlayVisible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.75),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(
                      24, 48, 24, safeBottom + 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.entry.memo.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          widget.entry.memo,
                          style: TextStyle(
                            color: Colors.white
                                .withValues(alpha: 0.85),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
