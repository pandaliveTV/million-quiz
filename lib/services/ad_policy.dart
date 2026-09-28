/// Pure frequency rules for ads, kept separate from the SDK so they can be
/// unit-tested with a fake clock.
///
/// * No ad of any kind during the first 60 s after the very first launch.
/// * At least 120 s between any two full-screen ads (interstitial, app open,
///   and rewarded all count as full-screen).
/// * Interstitial after every [roundsPerInterstitial] finished rounds.
/// * "Remove Ads" disables banner / interstitial / app open, never rewarded.
class AdPolicy {
  static const minGap = Duration(seconds: 120);
  static const firstRunGrace = Duration(seconds: 60);

  /// The general EliteP rule is "every 3 rounds"; this game's spec asks for
  /// an interstitial after every complete round (15 questions or a loss),
  /// still subject to [minGap]. Change here to tune the frequency.
  static const roundsPerInterstitial = 1;

  final int firstLaunchMs;
  final DateTime Function() now;

  AdPolicy({required this.firstLaunchMs, DateTime Function()? clock})
    : now = clock ?? DateTime.now;

  DateTime? lastFullScreen;
  int rounds = 0;

  bool get inGrace =>
      now().millisecondsSinceEpoch - firstLaunchMs <
      firstRunGrace.inMilliseconds;

  /// Time left until ads may be shown after first launch.
  Duration get graceRemaining {
    final left =
        firstRunGrace.inMilliseconds -
        (now().millisecondsSinceEpoch - firstLaunchMs);
    return Duration(milliseconds: left.clamp(0, firstRunGrace.inMilliseconds));
  }

  bool get gapOk =>
      lastFullScreen == null || now().difference(lastFullScreen!) >= minGap;

  bool canShowBanner({required bool adsRemoved}) => !adsRemoved && !inGrace;

  bool canShowAppOpen({required bool adsRemoved}) =>
      !adsRemoved && !inGrace && gapOk;

  /// Rewarded ads are always player-initiated, so the gap does not block
  /// them; only the first-run grace period does.
  bool get canShowRewarded => !inGrace;

  /// Counts a finished round; returns true if an interstitial should show.
  bool onRoundFinished({required bool adsRemoved}) {
    rounds++;
    if (rounds % roundsPerInterstitial != 0) return false;
    return !adsRemoved && !inGrace && gapOk;
  }

  void markFullScreenShown() => lastFullScreen = now();
}
