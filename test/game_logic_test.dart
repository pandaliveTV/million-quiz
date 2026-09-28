import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:millionquiz/data/question.dart';
import 'package:millionquiz/game/lifelines.dart';
import 'package:millionquiz/game/prize_ladder.dart';
import 'package:millionquiz/game/quiz_game.dart';

/// Small synthetic bank: 30 questions per difficulty, answer = id % 4.
QuestionBank fakeBank([int seed = 1]) {
  final qs = <Question>[
    for (var d = 1; d <= 3; d++)
      for (var i = 0; i < 30; i++)
        Question(
          id: d * 100 + i,
          category: i.isEven ? 'a' : 'b',
          difficulty: d,
          text: 'q$d-$i',
          options: const ['w', 'x', 'y', 'z'],
          answer: (d * 100 + i) % 4,
        ),
  ];
  return QuestionBank(qs, const {'a': 'A', 'b': 'B'}, random: Random(seed));
}

QuizGame newGame({int seed = 1}) => QuizGame(
  fakeBank(seed),
  engine: LifelineEngine(Random(seed)),
  autoTimer: false,
)..start();

void answerCorrectly(QuizGame g) {
  g.lock(g.question.answer);
  expect(g.reveal(), isTrue);
  if (g.phase == GamePhase.correct) g.next();
}

void answerWrongly(QuizGame g) {
  g.lock((g.question.answer + 1) % 4);
  expect(g.reveal(), isFalse);
}

void main() {
  group('PrizeLadder', () {
    test('15 steps ending at one million with safe points at 5 and 10', () {
      expect(PrizeLadder.length, 15);
      expect(PrizeLadder.prizes.last, 1000000);
      expect(PrizeLadder.isSafe(4), isTrue);
      expect(PrizeLadder.isSafe(9), isTrue);
      expect(
        PrizeLadder.prizes,
        orderedEquals([...PrizeLadder.prizes]..sort()),
      );
    });

    test('guaranteed amounts', () {
      expect(PrizeLadder.guaranteedBefore(0), 0);
      expect(PrizeLadder.guaranteedBefore(4), 0);
      expect(PrizeLadder.guaranteedBefore(5), 1000);
      expect(PrizeLadder.guaranteedBefore(9), 1000);
      expect(PrizeLadder.guaranteedBefore(10), 32000);
      expect(PrizeLadder.guaranteedBefore(14), 32000);
    });

    test('difficulty tiers', () {
      expect(
        [for (var i = 0; i < 15; i++) PrizeLadder.difficultyFor(i)],
        [...List.filled(5, 1), ...List.filled(5, 2), ...List.filled(5, 3)],
      );
    });

    test('format', () {
      expect(PrizeLadder.format(1000000), '1,000,000');
      expect(PrizeLadder.format(500), '500');
    });
  });

  group('QuizGame', () {
    test('answering 15 correctly wins the million', () {
      final g = newGame();
      final ids = <int>{};
      for (var i = 0; i < 15; i++) {
        expect(g.question.difficulty, PrizeLadder.difficultyFor(i));
        expect(ids.add(g.question.id), isTrue, reason: 'no repeats in a round');
        answerCorrectly(g);
      }
      expect(g.phase, GamePhase.over);
      expect(g.endReason, EndReason.won);
      expect(g.winnings, 1000000);
      expect(g.correctCount, 15);
      expect(g.coinsEarned, 15 * 10 + 500);
    });

    test('wrong answer after first safe point keeps 1,000', () {
      final g = newGame();
      for (var i = 0; i < 7; i++) {
        answerCorrectly(g);
      }
      answerWrongly(g);
      expect(g.phase, GamePhase.failed);
      expect(g.winnings, 1000);
      g.finish();
      expect(g.phase, GamePhase.over);
    });

    test('wrong answer before a safe point leaves with nothing', () {
      final g = newGame();
      answerCorrectly(g);
      answerWrongly(g);
      expect(g.winnings, 0);
    });

    test('timeout after 30 ticks fails the question', () {
      final g = newGame();
      for (var i = 0; i < 29; i++) {
        g.tick();
      }
      expect(g.phase, GamePhase.asking);
      expect(g.secondsLeft, 1);
      g.tick();
      expect(g.phase, GamePhase.failed);
      expect(g.endReason, EndReason.timeout);
    });

    test('paused timer does not count down', () {
      final g = newGame()..pause();
      g.tick();
      expect(g.secondsLeft, QuizGame.secondsPerQuestion);
      g.resume();
      g.tick();
      expect(g.secondsLeft, QuizGame.secondsPerQuestion - 1);
    });

    test('walking away keeps the banked prize', () {
      final g = newGame();
      for (var i = 0; i < 3; i++) {
        answerCorrectly(g);
      }
      g.walkAway();
      expect(g.endReason, EndReason.walkedAway);
      expect(g.winnings, 300);
    });

    test('second chance works once and keeps the level', () {
      final g = newGame();
      for (var i = 0; i < 6; i++) {
        answerCorrectly(g);
      }
      final before = g.question.id;
      answerWrongly(g);
      expect(g.takeSecondChance(), isTrue);
      expect(g.phase, GamePhase.asking);
      expect(g.level, 6);
      expect(g.question.id, isNot(before));
      expect(g.secondsLeft, QuizGame.secondsPerQuestion);
      answerWrongly(g);
      expect(g.canTakeSecondChance, isFalse);
      expect(g.takeSecondChance(), isFalse);
    });

    test('timer resets on each new question', () {
      final g = newGame();
      for (var i = 0; i < 12; i++) {
        g.tick();
      }
      answerCorrectly(g);
      expect(g.secondsLeft, QuizGame.secondsPerQuestion);
    });
  });

  group('Lifelines', () {
    test('50:50 removes exactly two wrong options', () {
      for (var seed = 0; seed < 50; seed++) {
        final g = newGame(seed: seed);
        expect(g.useLifeline(Lifeline.fiftyFifty), isTrue);
        expect(g.removed.length, 2);
        expect(g.removed.contains(g.question.answer), isFalse);
        expect(
          g.useLifeline(Lifeline.fiftyFifty),
          isFalse,
          reason: 'single use',
        );
      }
    });

    test('cannot lock a removed option', () {
      final g = newGame()..useLifeline(Lifeline.fiftyFifty);
      g.lock(g.removed.first);
      expect(g.phase, GamePhase.asking);
    });

    test('audience poll sums to 100 and leans to the right answer', () {
      final engine = LifelineEngine(Random(7));
      final bank = fakeBank();
      var rightOnTop = 0;
      const runs = 300;
      for (var i = 0; i < runs; i++) {
        final q = bank.all[i % bank.all.length];
        final removed = i.isEven ? engine.fiftyFifty(q) : <int>{};
        final poll = engine.audience(q, removed: removed);
        expect(poll.values.fold<int>(0, (a, b) => a + b), 100);
        expect(poll.values.every((v) => v >= 0), isTrue);
        for (final r in removed) {
          expect(poll[r], 0);
        }
        final top = poll.entries.reduce((a, b) => a.value >= b.value ? a : b);
        final second = poll.values.toList()..sort();
        expect(
          top.value,
          greaterThan(second[second.length - 2]),
          reason: 'clear favourite',
        );
        if (top.key == q.answer) rightOnTop++;
      }
      expect(rightOnTop / runs, greaterThan(0.8));
    });

    test('easy-question audience is always right', () {
      final engine = LifelineEngine(Random(3));
      final bank = fakeBank();
      for (final q in bank.all.where((q) => q.difficulty == 1)) {
        final poll = engine.audience(q);
        final top = poll.entries.reduce((a, b) => a.value >= b.value ? a : b);
        expect(top.key, q.answer);
      }
    });

    test('friend never suggests a removed option', () {
      final engine = LifelineEngine(Random(11));
      final bank = fakeBank();
      for (final q in bank.all) {
        final removed = engine.fiftyFifty(q);
        final hint = engine.phoneFriend(q, removed: removed);
        expect(removed.contains(hint.suggestion), isFalse);
        expect(hint.message, isNotEmpty);
      }
    });

    test('switch question gives a new question of the same difficulty', () {
      final g = newGame();
      final before = g.question;
      g.tick();
      expect(g.useLifeline(Lifeline.switchQuestion), isTrue);
      expect(g.question.id, isNot(before.id));
      expect(g.question.difficulty, before.difficulty);
      expect(g.secondsLeft, QuizGame.secondsPerQuestion);
    });

    test('used lifeline can be restored once', () {
      final g = newGame()..useLifeline(Lifeline.audience);
      expect(g.isAvailable(Lifeline.audience), isFalse);
      expect(g.canRestore(Lifeline.audience), isTrue);
      expect(g.restoreLifeline(Lifeline.audience), isTrue);
      expect(g.isAvailable(Lifeline.audience), isTrue);
      g.useLifeline(Lifeline.audience);
      expect(g.canRestore(Lifeline.audience), isFalse);
      expect(g.restoreLifeline(Lifeline.audience), isFalse);
    });

    test('lifelines are blocked while an answer is locked', () {
      final g = newGame()..lock(0);
      expect(g.useLifeline(Lifeline.phoneFriend), isFalse);
    });
  });
}
