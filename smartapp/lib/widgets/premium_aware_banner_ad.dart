import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:smartapp/controllers/ad_controller.dart';
import 'package:smartapp/controllers/premium_controller.dart';

class PremiumAwareBannerAd extends StatefulWidget {
  const PremiumAwareBannerAd({super.key, this.padding});

  final EdgeInsetsGeometry? padding;

  @override
  State<PremiumAwareBannerAd> createState() => _PremiumAwareBannerAdState();
}

class _PremiumAwareBannerAdState extends State<PremiumAwareBannerAd> {
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
      final bool isPremium = _premiumController.isPremium.value;
      final bool isLoaded = _isLoaded;
      final BannerAd? ad = _ad;
      if (isPremium) {
        return const SizedBox.shrink();
      }
      final double width = ad?.size.width.toDouble() ?? _adController.adSize.width.toDouble();
      final double height = ad?.size.height.toDouble() ?? _adController.adSize.height.toDouble();

      if (!isLoaded || ad == null) {
        return Padding(
          padding: widget.padding ?? EdgeInsets.zero,
          child: _BannerShimmerPlaceholder(width: width, height: height),
        );
      }
      return Padding(
        padding: widget.padding ?? EdgeInsets.zero,
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      );
    });
  }
}

class _BannerShimmerPlaceholder extends StatefulWidget {
  const _BannerShimmerPlaceholder({required this.width, required this.height});

  final double width;
  final double height;

  @override
  State<_BannerShimmerPlaceholder> createState() =>
      _BannerShimmerPlaceholderState();
}

class _BannerShimmerPlaceholderState extends State<_BannerShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final double offset = (_controller.value * 2) - 1;
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                begin: Alignment(-1.0 - offset, 0),
                end: Alignment(1.0 - offset, 0),
                colors: <Color>[
                  Colors.grey.shade300,
                  Colors.grey.shade100,
                  Colors.grey.shade300,
                ],
                stops: const <double>[0.1, 0.5, 0.9],
              ).createShader(bounds);
            },
            child: Container(
              color: Colors.grey.shade300,
            ),
          ),
        );
      },
    );
  }
}
