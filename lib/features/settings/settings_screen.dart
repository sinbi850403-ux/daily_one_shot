import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app_scope.dart';
import '../../iap/purchase_controller.dart';
import '../../lock/biometric_lock.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = LocalAuthentication();
  bool _lockEnabled = false;
  String? _premiumState;

  @override
  void initState() {
    super.initState();
    _lockEnabled = BiometricLock.instance.enabled;
    _premiumState = PurchaseController.instance.isPremium ? '구매 완료' : '미구매';
  }

  Future<void> _toggleLock(bool v) async {
    if (v) {
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) {
        _snack('이 기기에서 생체 인증을 사용할 수 없습니다');
        return;
      }
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

  Future<void> _export() async {
    final scope = AppScope.of(context);
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final out = File(p.join(dir.path, 'export-$stamp.zip'));
    await scope.backup.exportToZip(out);
    _snack('내보내기 완료: ${out.path}');
  }

  Future<void> _buy() async {
    final ok = await PurchaseController.instance.buyLifetime();
    if (!mounted) return;
    setState(() =>
        _premiumState = PurchaseController.instance.isPremium ? '구매 완료' : '미구매');
    _snack(ok ? '구매 완료. 감사합니다!' : '구매 실패 또는 취소');
  }

  Future<void> _restore() async {
    await PurchaseController.instance.restore();
    if (!mounted) return;
    setState(() =>
        _premiumState = PurchaseController.instance.isPremium ? '구매 완료' : '미구매');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          const _SectionHeader('백업'),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('ZIP으로 내보내기'),
            subtitle: const Text('사진과 메모를 한 파일로 저장'),
            onTap: _export,
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('ZIP에서 가져오기'),
            subtitle: const Text('새 기기에서 데이터 복원'),
            onTap: () => _snack('파일 선택 UI는 OS 통합 후 추가됩니다'),
          ),
          const _SectionHeader('잠금'),
          SwitchListTile(
            title: const Text('생체 인증 잠금'),
            subtitle: const Text('앱 진입 시 인증 요구'),
            value: _lockEnabled,
            onChanged: _toggleLock,
          ),
          const _SectionHeader('구매'),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: Text('평생 이용권 (7,000원) — $_premiumState'),
            onTap: PurchaseController.instance.isPremium ? null : _buy,
          ),
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: const Text('구매 복원'),
            onTap: _restore,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          )),
    );
  }
}
