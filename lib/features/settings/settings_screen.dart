import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app_scope.dart';
import '../../iap/purchase_controller.dart';
import '../../lock/biometric_lock.dart';
import '../../platform/file_import_channel.dart';
import '../../platform/share_channel.dart';
import '../../services/badge_service.dart';
import '../../services/notification_service.dart';
import '../../services/photobook_service.dart';
import '../../services/year_review_generator.dart';
import '../map/map_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = LocalAuthentication();
  bool _lockEnabled = false;
  bool _isPremium = false;
  bool _buyLoading = false;
  bool _exportLoading = false;
  bool _pdfLoading = false;
  bool _reviewLoading = false;
  bool _notifEnabled = false;
  TimeOfDay _notifTime = const TimeOfDay(hour: 21, minute: 0);

  @override
  void initState() {
    super.initState();
    _lockEnabled = BiometricLock.instance.enabled;
    _isPremium = PurchaseController.instance.isPremium;
    _notifEnabled = NotificationService.instance.enabled;
    _notifTime = NotificationService.instance.time;
  }

  // ── 잠금 ──────────────────────────────────────────────────────
  Future<void> _toggleLock(bool v) async {
    if (v) {
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) { _snack('이 기기에서 생체 인증을 사용할 수 없습니다'); return; }
      final ok = await _auth.authenticate(
        localizedReason: '잠금을 설정하려면 인증해 주세요',
        options: const AuthenticationOptions(biometricOnly: false),
      );
      if (!ok) return;
    }
    await BiometricLock.instance.setEnabled(v);
    if (!mounted) return;
    setState(() => _lockEnabled = v);
  }

  // ── 백업 ──────────────────────────────────────────────────────
  Future<void> _export() async {
    setState(() => _exportLoading = true);
    try {
      final scope = AppScope.of(context);
      final dir = await getApplicationDocumentsDirectory();
      final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
      final out = File(p.join(dir.path, 'export-$stamp.zip'));
      await scope.backup.exportToZip(out);
      if (!mounted) return;
      await ShareChannel.shareFile(out.path);
    } finally {
      if (mounted) setState(() => _exportLoading = false);
    }
  }

  Future<void> _import() async {
    final path = await FileImportChannel.getSharedFilePath();
    if (path == null) {
      _snack('파일 관리자에서 백업 ZIP → "다른 앱으로 열기" → 하루 한 장');
      return;
    }
    if (!mounted) return;
    try {
      final scope = AppScope.of(context);
      final count = await scope.backup.importFromZip(File(path), overwrite: false);
      _snack('$count개 항목 복원 완료 ✓');
    } catch (e) {
      _snack('가져오기 실패: $e');
    }
  }

  // ── PDF 포토북 ─────────────────────────────────────────────────
  Future<void> _exportPdf() async {
    setState(() => _pdfLoading = true);
    try {
      final scope = AppScope.of(context);
      final entries = await scope.repo.listAll();
      if (entries.isEmpty) { _snack('기록이 없습니다'); return; }
      final file = await PhotobookService.instance
          .generate(entries, scope.storage);
      if (!mounted) return;
      await ShareChannel.shareFile(file.path);
    } catch (e) {
      _snack('PDF 생성 실패: $e');
    } finally {
      if (mounted) setState(() => _pdfLoading = false);
    }
  }

  // ── 연도 회고 카드 ─────────────────────────────────────────────
  Future<void> _yearReview() async {
    final year = DateTime.now().year;
    setState(() => _reviewLoading = true);
    try {
      final scope = AppScope.of(context);
      final all = await scope.repo.listAll();
      final entries = all.where((e) => e.date.year == year).toList();
      if (entries.isEmpty) { _snack('올해 기록이 없습니다'); return; }

      // 월별 대표 파일 로드
      final byMonth = <int, int>{};
      for (var i = 0; i < entries.length; i++) {
        byMonth.putIfAbsent(entries[i].date.month, () => i);
      }
      final photos = <File>[];
      for (var i = 0; i < entries.length; i++) {
        photos.add(await scope.storage.originalFile(entries[i].photoPath));
      }

      final card = await YearReviewGenerator.generate(year, entries, photos);
      if (!mounted) return;
      await ShareChannel.shareFile(card.path);
    } catch (e) {
      _snack('회고 카드 생성 실패: $e');
    } finally {
      if (mounted) setState(() => _reviewLoading = false);
    }
  }

  // ── 알림 ──────────────────────────────────────────────────────
  Future<void> _toggleNotif(bool v) async {
    if (v) {
      // 권한 요청 — 실패해도 일단 켜기 시도
      await NotificationService.instance.requestPermission();
    }
    await NotificationService.instance.setEnabled(v, time: _notifTime);
    if (!mounted) return;
    setState(() => _notifEnabled = v);
    _snack(v ? '알림이 켜졌습니다' : '알림이 꺼졌습니다');
  }

  Future<void> _pickNotifTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _notifTime,
    );
    if (picked == null || !mounted) return;
    setState(() => _notifTime = picked);
    await NotificationService.instance.setTime(picked);
  }

  // ── IAP ───────────────────────────────────────────────────────
  Future<void> _buy() async {
    setState(() => _buyLoading = true);
    try {
      final ok = await PurchaseController.instance.buyLifetime();
      if (!mounted) return;
      setState(() => _isPremium = PurchaseController.instance.isPremium);
      _snack(ok ? '구매 완료. 감사합니다!' : '구매 실패 또는 취소');
    } finally {
      if (mounted) setState(() => _buyLoading = false);
    }
  }

  Future<void> _restore() async {
    await PurchaseController.instance.restore();
    if (!mounted) return;
    setState(() => _isPremium = PurchaseController.instance.isPremium);
    _snack(_isPremium ? '구매 내역 복원 완료 ✓' : '복원할 구매 내역이 없습니다');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── UI ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // ── 프리미엄 ───────────────────────────────────────────
          _SettingCard(
            child: _isPremium
                ? ListTile(
                    leading: _iconBox(Icons.workspace_premium_outlined,
                        cs.primaryContainer, cs.primary),
                    title: const Text('평생 이용권',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('구매 완료 · 모든 기능 이용 중'),
                    trailing: _chip('소장 중', cs),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          _iconBox(Icons.workspace_premium_outlined,
                              cs.primaryContainer, cs.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('평생 이용권',
                                    style: tt.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700)),
                                Text('광고 없이 평생 사용 · 7,000원',
                                    style: tt.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: _buyLoading ? null : _buy,
                              child: _buyLoading
                                  ? const SizedBox(width: 18, height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Text('구매하기'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                              onPressed: _restore,
                              child: const Text('복원')),
                        ]),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),

          // ── 알림 ───────────────────────────────────────────────
          _SettingCard(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: _iconBox(Icons.notifications_outlined,
                      cs.primaryContainer, cs.primary),
                  title: const Text('매일 기록 알림',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('오늘 기록을 안 했을 때 알려드려요'),
                  value: _notifEnabled,
                  onChanged: _toggleNotif,
                ),
                if (_notifEnabled) ...[
                  Divider(height: 1, indent: 16, endIndent: 16,
                      color: cs.outlineVariant.withValues(alpha: 0.4)),
                  ListTile(
                    leading: _iconBox(Icons.schedule_outlined,
                        cs.surfaceContainerHighest, cs.onSurfaceVariant),
                    title: const Text('알림 시간',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Text(
                      _notifTime.format(context),
                      style: TextStyle(color: cs.primary,
                          fontWeight: FontWeight.w700),
                    ),
                    onTap: _pickNotifTime,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── 공유·내보내기 ───────────────────────────────────────
          _SettingCard(
            child: Column(
              children: [
                ListTile(
                  leading: _iconBox(Icons.upload_file_outlined,
                      cs.tertiaryContainer, cs.tertiary),
                  title: const Text('ZIP 내보내기',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('사진·메모 백업'),
                  trailing: _exportLoading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right),
                  onTap: _exportLoading ? null : _export,
                ),
                _divider(cs),
                ListTile(
                  leading: _iconBox(Icons.file_download_outlined,
                      cs.secondaryContainer, cs.secondary),
                  title: const Text('ZIP 가져오기',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('기기 이전 · 복원'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _import,
                ),
                _divider(cs),
                ListTile(
                  leading: _iconBox(Icons.picture_as_pdf_outlined,
                      cs.errorContainer, cs.error),
                  title: const Text('PDF 포토북',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('전체 기록을 PDF 한 파일로'),
                  trailing: _pdfLoading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right),
                  onTap: _pdfLoading ? null : _exportPdf,
                ),
                _divider(cs),
                ListTile(
                  leading: _iconBox(Icons.auto_awesome_outlined,
                      cs.primaryContainer, cs.primary),
                  title: const Text('올해 회고 카드',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('올해 월별 사진 모아 이미지로 공유'),
                  trailing: _reviewLoading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right),
                  onTap: _reviewLoading ? null : _yearReview,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── 지도 ───────────────────────────────────────────────
          _SettingCard(
            child: ListTile(
              leading: _iconBox(Icons.map_outlined,
                  cs.tertiaryContainer, cs.tertiary),
              title: const Text('지도 보기',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('위치 정보가 있는 기록을 지도에 표시'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MapScreen())),
            ),
          ),
          const SizedBox(height: 12),

          // ── 뱃지 ───────────────────────────────────────────────
          _SettingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Text('획득 뱃지',
                      style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: BadgeService.instance.all.map((b) {
                      final earned = BadgeService.instance.isEarned(b.id);
                      return Tooltip(
                        message: b.title,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: earned
                                ? cs.primaryContainer
                                : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: earned
                                  ? cs.primary.withValues(alpha: 0.4)
                                  : cs.outlineVariant.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              b.emoji,
                              style: TextStyle(
                                  fontSize: 24,
                                  color: earned ? null : Colors.transparent),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── 잠금 ───────────────────────────────────────────────
          _SettingCard(
            child: SwitchListTile(
              secondary: _iconBox(Icons.fingerprint,
                  cs.surfaceContainerHighest, cs.onSurfaceVariant),
              title: const Text('생체 인증 잠금',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('앱 열 때 지문·얼굴 인증'),
              value: _lockEnabled,
              onChanged: _toggleLock,
            ),
          ),
          const SizedBox(height: 32),

          Center(
            child: Text('하루 한 장 v1.0',
                style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.45))),
          ),
        ],
      ),
    );
  }

  Widget _iconBox(IconData icon, Color bg, Color fg) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: fg, size: 22),
      );

  Widget _chip(String label, ColorScheme cs) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.primary)),
      );

  Widget _divider(ColorScheme cs) => Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: cs.outlineVariant.withValues(alpha: 0.4));
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.4), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
