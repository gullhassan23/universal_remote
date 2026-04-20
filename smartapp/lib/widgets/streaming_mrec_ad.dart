import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:smartapp/config/admob_config.dart';
import 'package:smartapp/controllers/ad_controller.dart';
import 'package:smartapp/controllers/premium_controller.dart';

class StreamingMrecAd extends StatefulWidget {
  const StreamingMrecAd({super.key});

  @override
  State<StreamingMrecAd> createState() => _StreamingMrecAdState();
}

class _StreamingMrecAdState extends State<StreamingMrecAd> {
  late final PremiumController _premiumController;
  late final AdController _adController;
  Worker? _premiumWorker;
  BannerAd? _ad;
  bool _isLoaded = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _premiumController = Get.find<PremiumController>();
    _adController = Get.find<AdController>();
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
    if (_isLoading || _isLoaded || _ad != null || _adUnitId.isEmpty) {
      return;
    }

    _isLoading = true;
    late final BannerAd pendingAd;
    pendingAd = BannerAd(
      adUnitId: _adUnitId,
      request: _adController.adRequest,
      size: AdSize.mediumRectangle,
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
        },
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
      if (_premiumController.isPremium.value || _adUnitId.isEmpty) {
        return const SizedBox.shrink();
      }

      if (!_isLoaded || _ad == null) {
        return const SizedBox(
          width: 300,
          height: 250,
        );
      }

      return SizedBox(
        width: _ad!.size.width.toDouble(),
        height: _ad!.size.height.toDouble(),
        child: AdWidget(ad: _ad!),
      );
    });
  }

  String get _adUnitId => AdMobConfig.mrecAdUnitId;
}
