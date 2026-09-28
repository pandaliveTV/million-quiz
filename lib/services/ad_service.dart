import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_policy.dart';
import 'storage_service.dart';

/// ===================== AdMob unit IDs =====================
/// These are Google's official TEST ids. Before publishing, replace them
/// with the EliteP ids from your AdMob console (and set the App ID in
/// android/app/src/main/AndroidManifest.xml).
class AdIds {
  static const banner = 'ca-app-pub-3940256099942544/6300978111';
  static const interstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const rewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const appOpen = 'ca-app-pub-3940256099942544/9257395921';
}

/// Single place for all ad logic. Frequency rules live in [AdPolicy]:
/// * banner on Home / Categories only (never during gameplay)
/// * interstitial after every finished round, ≥120 s between full-screen ads
/// * rewarded only when the player asks (hints, second chance, x2 coins)
/// * app open when returning from background, same 120 s gap
/// * no ads in the first 60 s of the first launch
/// * UMP (GDPR) consent is gathered before any ad is requested
/// * "Remove Ads" purchase disables banner / interstitial / app open only
class AdService {
  final StorageService storage;
  final AdPolicy policy;

  AdService(this.storage)
    : policy = AdPolicy(firstLaunchMs: storage.firstLaunch);

  bool _ready = false;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  AppOpenAd? _appOpen;
  StreamSubscription<AppState>? _appStateSub;

  /// True while any full-screen ad covers the app; the game pauses its timer.
  final fullScreenVisible = ValueNotifier<bool>(false);

  /// Notifies when the SDK becomes ready so banners can load.
  final ready = ValueNotifier<bool>(false);

  bool get canShowRewarded =>
      _ready && _rewarded != null && policy.canShowRewarded;

  /// Gathers GDPR consent (UMP) first, then initialises the SDK.
  Future<void> init() async {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((_) {
        if (!completer.isCompleted) completer.complete();
      }),
      (_) {
        if (!completer.isCompleted) completer.complete();
      },
    );
    await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {},
    );
    if (!await ConsentInformation.instance.canRequestAds()) return;

    await MobileAds.instance.initialize();
    _ready = true;
    ready.value = true;
    _loadInterstitial();
    _loadRewarded();
    _loadAppOpen();
    AppStateEventNotifier.startListening();
    _appStateSub = AppStateEventNotifier.appStateStream.listen((s) {
      if (s == AppState.foreground) _showAppOpen();
    });
  }

  /// Whether the privacy options (consent) entry point must be shown.
  Future<bool> privacyOptionsRequired() async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  void showPrivacyOptions() => ConsentForm.showPrivacyOptionsForm((_) {});

  void dispose() => _appStateSub?.cancel();

  // ---------------- Banner ----------------
  bool get bannerAllowed =>
      _ready && policy.canShowBanner(adsRemoved: storage.adsRemoved);

  BannerAd? createBanner(VoidCallback onLoaded) {
    if (!bannerAllowed) return null;
    return BannerAd(
      adUnitId: AdIds.banner,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
  }

  // ---------------- Interstitial ----------------
  void _loadInterstitial() {
    if (storage.adsRemoved) return;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  /// Call once after every complete round (win, loss or walk-away).
  void onRoundFinished() {
    if (!_ready) return;
    final ad = _interstitial;
    if (!policy.onRoundFinished(adsRemoved: storage.adsRemoved)) return;
    if (ad == null || fullScreenVisible.value) return;
    _interstitial = null;
    ad.fullScreenContentCallback = _fullScreenCallback(_loadInterstitial);
    ad.show();
  }

  // ---------------- Rewarded ----------------
  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (_) => _rewarded = null,
      ),
    );
  }

  /// Shows a rewarded ad (always player-initiated). Completes with true
  /// only if the reward was earned.
  Future<bool> showRewarded() {
    final ad = _rewarded;
    if (ad == null || !canShowRewarded) return Future.value(false);
    _rewarded = null;
    final result = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = _fullScreenCallback(() {
      _loadRewarded();
      if (!result.isCompleted) result.complete(earned);
    });
    ad.show(onUserEarnedReward: (_, _) => earned = true);
    return result.future;
  }

  // ---------------- App Open ----------------
  void _loadAppOpen() {
    if (storage.adsRemoved) return;
    AppOpenAd.load(
      adUnitId: AdIds.appOpen,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) => _appOpen = ad,
        onAdFailedToLoad: (_) => _appOpen = null,
      ),
    );
  }

  void _showAppOpen() {
    final ad = _appOpen;
    if (ad == null || fullScreenVisible.value) return;
    if (!policy.canShowAppOpen(adsRemoved: storage.adsRemoved)) return;
    _appOpen = null;
    ad.fullScreenContentCallback = _fullScreenCallback(_loadAppOpen);
    ad.show();
  }

  FullScreenContentCallback<T> _fullScreenCallback<T extends Ad>(
    VoidCallback onDone,
  ) {
    return FullScreenContentCallback<T>(
      onAdShowedFullScreenContent: (_) {
        fullScreenVisible.value = true;
        policy.markFullScreenShown();
      },
      onAdDismissedFullScreenContent: (ad) {
        fullScreenVisible.value = false;
        policy.markFullScreenShown();
        ad.dispose();
        onDone();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        fullScreenVisible.value = false;
        ad.dispose();
        onDone();
      },
    );
  }
}
