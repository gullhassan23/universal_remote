import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:smartapp/controllers/ad_controller.dart';
import 'package:smartapp/controllers/premium_controller.dart';
import 'package:smartapp/services/analytics_service.dart';

class TopBannerAd extends StatefulWidget {
  const TopBannerAd({super.key});

  @override
  State<TopBannerAd> createState() => _TopBannerAdState();
}

class _TopBannerAdState extends State<TopBannerAd> {
  late final PremiumController _premiumController;
  late final AdController _adController;
  late final AnalyticsService _analyticsService;
  Worker? _premiumWorker;
  BannerAd? _ad;
  bool _isLoaded = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _premiumController = Get.find<PremiumController>();
    _adController = Get.find<AdController>();
    _analyticsService = Get.find<AnalyticsService>();
    _premiumWorker = ever<bool>(_premiumController.isPremium, _handlePremium);
    _handlePremium(_premiumController.isPremium.value);
  }

  void _handlePremium(bool isPremium) {
    if (isPremium) {
      _disposeAd();
      return;
    }
    _loadAdIfNeeded();
  }

  void _loadAdIfNeeded() {
    if (_isLoading || _isLoaded || _ad != null || _adController.adUnitId.isEmpty) {
      return;
    }
    _isLoading = true;
    late final BannerAd pendingAd;
    pendingAd = BannerAd(
      adUnitId: _adController.adUnitId,
      request: _adController.adRequest,
      size: _adController.adSize,
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (!mounted || ad is! BannerAd || !identical(ad, pendingAd)) {
            ad.dispose();
            return;
          }
          setState(() {
            _ad = ad;
            _isLoaded = true;
            _isLoading = false;
          });
          unawaited(
            _analyticsService.logEvent(
              'admob_banner_top_loaded',
              params: {'screen_name': 'TopBannerAd', 'ad_unit': 'banner_top'},
            ),
          );
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          if (!mounted || !identical(ad, pendingAd)) {
            return;
          }
          setState(() {
            _ad = null;
            _isLoaded = false;
            _isLoading = false;
          });
          unawaited(
            _analyticsService.logEvent(
              'admob_banner_top_failed_load',
              params: {
                'screen_name': 'TopBannerAd',
                'ad_unit': 'banner_top',
                'error_code': error.code,
                'error_domain': error.domain,
              },
            ),
          );
        },
        onAdImpression: (_) => unawaited(
          _analyticsService.logEvent(
            'admob_banner_top_impression',
            params: {'screen_name': 'TopBannerAd', 'ad_unit': 'banner_top'},
          ),
        ),
        onAdClicked: (_) => unawaited(
          _analyticsService.logEvent(
            'admob_banner_top_clicked',
            params: {'screen_name': 'TopBannerAd', 'ad_unit': 'banner_top'},
          ),
        ),
      ),
    );
    pendingAd.load();
  }

  void _disposeAd() {
    _ad?.dispose();
    _ad = null;
    _isLoaded = false;
    _isLoading = false;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _premiumWorker?.dispose();
    _ad?.dispose();
    _ad = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool isPremium = _premiumController.isPremium.value;
      final BannerAd? ad = _ad;
      final bool isLoaded = _isLoaded;
      if (isPremium || _adController.adUnitId.isEmpty) {
        return const SizedBox.shrink();
      }

      if (!isLoaded || ad == null) {
        return const SizedBox.shrink();
      }

      return SafeArea(
        top: true,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        ),
      );
    });
  }
}
