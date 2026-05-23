import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../iap/purchase_controller.dart';

// TODO: 출시 전 AdMob 콘솔(https://apps.admob.com)에서 실제 광고 단위 ID로 교체
const _kBannerAdUnitId = 'ca-app-pub-1789643452673979/2904673589'; // 테스트 ID

/// 무료 사용자에게만 배너 광고를 표시합니다.
/// 프리미엄 구매 시 SizedBox.shrink()를 반환해 공간을 차지하지 않습니다.
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _ad;
  bool _adLoaded = false;

  @override
  void initState() {
    super.initState();
    if (!PurchaseController.instance.isPremium) {
      _loadAd();
    }
  }

  void _loadAd() {
    _ad = BannerAd(
      adUnitId: _kBannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) {
            _ad?.dispose();
            return;
          }
          setState(() => _adLoaded = true);
        },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (PurchaseController.instance.isPremium) {
      return const SizedBox.shrink();
    }
    if (!_adLoaded || _ad == null) {
      // 광고 로드 전: 높이를 예약해 레이아웃 점프 방지
      return const SizedBox(height: 50);
    }
    final cs = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.center,
      width: double.infinity,
      height: _ad!.size.height.toDouble(),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.4), width: 0.5),
        ),
      ),
      child: AdWidget(ad: _ad!),
    );
  }
}
