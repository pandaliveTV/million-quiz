import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists progress (level/XP, coins, best score, settings) locally.
class StorageService extends ChangeNotifier {
  static const xpPerLevel = 25;

  late SharedPreferences _p;

  int coins = 0;

  /// Highest winnings reached in a single round (the "best score").
  int bestScore = 0;

  /// Highest question number reached (1-15).
  int bestQuestion = 0;

  /// Total correct answers ever; drives the player level.
  int xp = 0;
  int gamesPlayed = 0;
  int wins = 0;

  bool muted = false;
  bool music = true;
  bool vibration = true;
  bool adsRemoved = false;

  /// Milliseconds since epoch of the very first launch.
  int firstLaunch = 0;

  int get level => 1 + xp ~/ xpPerLevel;
  double get levelProgress => (xp % xpPerLevel) / xpPerLevel;

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    coins = _p.getInt('coins') ?? 0;
    bestScore = _p.getInt('bestScore') ?? 0;
    bestQuestion = _p.getInt('bestQuestion') ?? 0;
    xp = _p.getInt('xp') ?? 0;
    gamesPlayed = _p.getInt('gamesPlayed') ?? 0;
    wins = _p.getInt('wins') ?? 0;
    muted = _p.getBool('muted') ?? false;
    music = _p.getBool('music') ?? true;
    vibration = _p.getBool('vibration') ?? true;
    adsRemoved = _p.getBool('adsRemoved') ?? false;
    firstLaunch = _p.getInt('firstLaunch') ?? 0;
    if (firstLaunch == 0) {
      firstLaunch = DateTime.now().millisecondsSinceEpoch;
      await _p.setInt('firstLaunch', firstLaunch);
    }
  }

  void addCoins(int n) {
    coins += n;
    _p.setInt('coins', coins);
    notifyListeners();
  }

  bool spend(int n) {
    if (coins < n) return false;
    addCoins(-n);
    return true;
  }

  /// Records a finished round. Returns true when [score] is a new record.
  bool recordRound({
    required int score,
    required int questionReached,
    required int correct,
    required bool won,
  }) {
    gamesPlayed++;
    xp += correct;
    if (won) wins++;
    if (questionReached > bestQuestion) bestQuestion = questionReached;
    final record = score > bestScore;
    if (record) bestScore = score;
    _p
      ..setInt('gamesPlayed', gamesPlayed)
      ..setInt('xp', xp)
      ..setInt('wins', wins)
      ..setInt('bestQuestion', bestQuestion)
      ..setInt('bestScore', bestScore);
    notifyListeners();
    return record;
  }

  void setMuted(bool v) {
    muted = v;
    _p.setBool('muted', v);
    notifyListeners();
  }

  void setMusic(bool v) {
    music = v;
    _p.setBool('music', v);
    notifyListeners();
  }

  void setVibration(bool v) {
    vibration = v;
    _p.setBool('vibration', v);
    notifyListeners();
  }

  void setAdsRemoved(bool v) {
    adsRemoved = v;
    _p.setBool('adsRemoved', v);
    notifyListeners();
  }
}
