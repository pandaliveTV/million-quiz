import 'package:flutter_test/flutter_test.dart';
import 'package:millionquiz/services/ad_policy.dart';

void main() {
  late DateTime now;
  final start = DateTime(2026, 1, 1, 12);
  AdPolicy policy() {
    now = start;
    return AdPolicy(
      firstLaunchMs: start.millisecondsSinceEpoch,
      clock: () => now,
    );
  }

  test('no ads at all in the first 60 seconds after first launch', () {
    final p = policy();
    now = start.add(const Duration(seconds: 59));
    expect(p.inGrace, isTrue);
    expect(p.canShowBanner(adsRemoved: false), isFalse);
    expect(p.canShowAppOpen(adsRemoved: false), isFalse);
    expect(p.canShowRewarded, isFalse);
    expect(p.onRoundFinished(adsRemoved: false), isFalse);
    now = start.add(const Duration(seconds: 61));
    expect(p.canShowBanner(adsRemoved: false), isTrue);
    expect(p.canShowRewarded, isTrue);
  });

  test('at least 120 seconds between full-screen ads', () {
    final p = policy();
    now = start.add(const Duration(minutes: 5));
    expect(p.onRoundFinished(adsRemoved: false), isTrue);
    p.markFullScreenShown();
    now = now.add(const Duration(seconds: 119));
    expect(p.onRoundFinished(adsRemoved: false), isFalse);
    expect(p.canShowAppOpen(adsRemoved: false), isFalse);
    now = now.add(const Duration(seconds: 2));
    expect(p.canShowAppOpen(adsRemoved: false), isTrue);
    expect(p.onRoundFinished(adsRemoved: false), isTrue);
  });

  test('rewarded is never blocked by the gap (player-initiated)', () {
    final p = policy();
    now = start.add(const Duration(minutes: 5));
    p.markFullScreenShown();
    expect(p.canShowRewarded, isTrue);
  });

  test('remove-ads blocks banner, interstitial and app open only', () {
    final p = policy();
    now = start.add(const Duration(minutes: 5));
    expect(p.canShowBanner(adsRemoved: true), isFalse);
    expect(p.canShowAppOpen(adsRemoved: true), isFalse);
    expect(p.onRoundFinished(adsRemoved: true), isFalse);
    expect(p.canShowRewarded, isTrue);
  });

  test('interstitial cadence follows roundsPerInterstitial', () {
    final p = policy();
    now = start.add(const Duration(minutes: 5));
    var shown = 0;
    for (var i = 0; i < 6; i++) {
      if (p.onRoundFinished(adsRemoved: false)) shown++;
      // Plenty of time between rounds so the gap never blocks.
      now = now.add(const Duration(minutes: 3));
    }
    expect(shown, 6 ~/ AdPolicy.roundsPerInterstitial);
  });
}
