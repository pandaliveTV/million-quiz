import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/question.dart';
import 'lifelines.dart';
import 'prize_ladder.dart';

enum GamePhase {
  /// Waiting for the player to pick an answer (timer running).
  asking,

  /// Answer chosen, suspense before the reveal (timer stopped).
  locked,

  /// Correct answer revealed; about to move to the next question.
  correct,

  /// Wrong answer or timeout; the player may still take a second chance.
  failed,

  /// Round finished (won, walked away, or lost without second chance).
  over,
}

enum EndReason { won, wrong, timeout, walkedAway }

/// Whole game state for one round of 15 questions. Pure logic, no widgets:
/// the UI drives the suspense timing by calling [lock] → [reveal] → [next].
class QuizGame extends ChangeNotifier {
  static const secondsPerQuestion = 30;

  final QuestionBank bank;
  final LifelineEngine lifelines;
  final String? category;

  /// When false the caller drives the clock with [tick] (used by tests).
  final bool autoTimer;

  QuizGame(
    this.bank, {
    this.category,
    LifelineEngine? engine,
    this.autoTimer = true,
  }) : lifelines = engine ?? LifelineEngine();

  int level = 0;
  late Question question;
  GamePhase phase = GamePhase.asking;
  int secondsLeft = secondsPerQuestion;
  int? selected;
  EndReason? endReason;

  final Set<Lifeline> used = {};
  final Set<Lifeline> restored = {};
  Set<int> removed = {};
  Map<int, int>? audienceResult;
  FriendHint? friendHint;
  bool secondChanceUsed = false;
  int correctCount = 0;

  Timer? _timer;
  bool _paused = false;
  final Set<int> _roundIds = {};

  void start() {
    level = 0;
    _loadQuestion();
  }

  int get difficulty => PrizeLadder.difficultyFor(level);
  int get currentPrize => PrizeLadder.prizeAt(level);
  bool get isLastQuestion => level == PrizeLadder.length - 1;
  bool get canUseLifelines => phase == GamePhase.asking;
  bool get canTakeSecondChance =>
      phase == GamePhase.failed && !secondChanceUsed;

  /// Points the player leaves with, given how the round ended.
  int get winnings => switch (endReason) {
    EndReason.won => PrizeLadder.prizes.last,
    EndReason.walkedAway => PrizeLadder.bankedBefore(level),
    EndReason.wrong || EndReason.timeout => PrizeLadder.guaranteedBefore(level),
    null => PrizeLadder.bankedBefore(level),
  };

  /// Coins rewarded at the end of a round.
  int get coinsEarned =>
      correctCount * 10 + (endReason == EndReason.won ? 500 : 0);

  bool isAvailable(Lifeline l) => !used.contains(l);
  bool canRestore(Lifeline l) => used.contains(l) && !restored.contains(l);

  void _loadQuestion({Set<int> exclude = const {}}) {
    question = bank.next(
      difficulty,
      category: category,
      exclude: {..._roundIds, ...exclude},
    );
    _roundIds.add(question.id);
    selected = null;
    removed = {};
    audienceResult = null;
    friendHint = null;
    phase = GamePhase.asking;
    secondsLeft = secondsPerQuestion;
    _startTimer();
    notifyListeners();
  }

  // ------------------------------------------------------------- timer
  void _startTimer() {
    _timer?.cancel();
    if (!autoTimer) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  /// Advances the countdown by one second.
  void tick() {
    if (phase != GamePhase.asking || _paused) return;
    secondsLeft--;
    if (secondsLeft <= 0) {
      secondsLeft = 0;
      _timer?.cancel();
      endReason = EndReason.timeout;
      phase = GamePhase.failed;
    }
    notifyListeners();
  }

  /// Pauses the countdown (app in background, full-screen ad, dialogs).
  void pause() => _paused = true;
  void resume() => _paused = false;
  bool get isPaused => _paused;

  // ------------------------------------------------------------ answers
  /// Player picked [index] as the final answer.
  void lock(int index) {
    if (phase != GamePhase.asking || removed.contains(index)) return;
    selected = index;
    phase = GamePhase.locked;
    _timer?.cancel();
    notifyListeners();
  }

  /// Reveals whether the locked answer is right. Returns true if correct.
  bool reveal() {
    if (phase != GamePhase.locked) return false;
    final ok = selected == question.answer;
    if (ok) {
      correctCount++;
      phase = GamePhase.correct;
      if (isLastQuestion) {
        endReason = EndReason.won;
        phase = GamePhase.over;
      }
    } else {
      endReason = EndReason.wrong;
      phase = GamePhase.failed;
    }
    notifyListeners();
    return ok;
  }

  /// Moves to the next question after a correct answer.
  void next() {
    if (phase != GamePhase.correct) return;
    level++;
    _loadQuestion();
  }

  /// Player keeps the banked points and leaves.
  void walkAway() {
    if (phase != GamePhase.asking) return;
    _timer?.cancel();
    endReason = EndReason.walkedAway;
    phase = GamePhase.over;
    notifyListeners();
  }

  /// Ends the round after a failure the player chose not to rescue.
  void finish() {
    if (phase != GamePhase.failed) return;
    phase = GamePhase.over;
    notifyListeners();
  }

  /// "Second chance" (rewarded ad, once per round): same level, new question.
  bool takeSecondChance() {
    if (!canTakeSecondChance) return false;
    secondChanceUsed = true;
    endReason = null;
    _loadQuestion();
    return true;
  }

  // ---------------------------------------------------------- lifelines
  bool useLifeline(Lifeline l) {
    if (!canUseLifelines || used.contains(l)) return false;
    used.add(l);
    switch (l) {
      case Lifeline.fiftyFifty:
        removed = lifelines.fiftyFifty(question);
      case Lifeline.audience:
        audienceResult = lifelines.audience(question, removed: removed);
      case Lifeline.phoneFriend:
        friendHint = lifelines.phoneFriend(question, removed: removed);
      case Lifeline.switchQuestion:
        _loadQuestion(exclude: {question.id});
        return true;
    }
    notifyListeners();
    return true;
  }

  /// Gives back a used lifeline (via rewarded ad or coins), once per lifeline.
  bool restoreLifeline(Lifeline l) {
    if (!canRestore(l)) return false;
    used.remove(l);
    restored.add(l);
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
