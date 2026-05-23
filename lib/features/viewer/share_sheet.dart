import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../platform/share_channel.dart';
import 'memory_card_generator.dart';

/// 공유 옵션 바텀시트 — 메모리 카드 / 사진만
class ShareSheet extends StatefulWidget {
  const ShareSheet({super.key, required this.entry, required this.file});
  final Entry entry;
  final File file;

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  bool _generating = false;

  Future<void> _shareCard() async {
    setState(() => _generating = true);
    try {
      final card =
          await MemoryCardGenerator.generate(widget.entry, widget.file);
      if (!mounted) return;
      Navigator.pop(context);
      await ShareChannel.shareFile(card.path);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카드 생성 실패: $e')),
      );
    }
  }

  Future<void> _sharePhoto() async {
    Navigator.pop(context);
    await ShareChannel.shareFile(
      widget.file.path,
      text: widget.entry.memo.isNotEmpty ? widget.entry.memo : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: _generating
          ? const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color:
                        scheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  child: Text(
                    '공유',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.auto_awesome_outlined,
                        color: scheme.primary),
                  ),
                  title: const Text('메모리 카드로 공유',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('날짜·메모가 담긴 1080×1350 카드 이미지'),
                  onTap: _shareCard,
                ),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.photo_outlined,
                        color: scheme.secondary),
                  ),
                  title: const Text('사진만 공유',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('원본 사진 파일 그대로'),
                  onTap: _sharePhoto,
                ),
                const SizedBox(height: 12),
              ],
            ),
    );
  }
}
