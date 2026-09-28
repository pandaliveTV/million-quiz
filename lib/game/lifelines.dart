import 'dart:math';

import '../data/question.dart';

enum Lifeline { fiftyFifty, audience, phoneFriend, switchQuestion }

extension LifelineInfo on Lifeline {
  String get title => switch (this) {
    Lifeline.fiftyFifty => 'حذف إجابتين',
    Lifeline.audience => 'سؤال الجمهور',
    Lifeline.phoneFriend => 'الاتصال بصديق',
    Lifeline.switchQuestion => 'تغيير السؤال',
  };
}

/// Arabic option letters used on the answer tiles.
const optionLetters = ['أ', 'ب', 'ج', 'د'];

/// Result of the "phone a friend" lifeline.
class FriendHint {
  final String name;
  final int suggestion;
  final bool confident;
  const FriendHint(this.name, this.suggestion, this.confident);

  String get message {
    final letter = optionLetters[suggestion];
    return confident
        ? 'أنا متأكد تقريباً… الإجابة هي ($letter).'
        : 'لست متأكداً تماماً، لكنني أميل إلى ($letter).';
  }
}

/// Pure lifeline logic so it can be unit-tested with a seeded [Random].
class LifelineEngine {
  final Random random;
  LifelineEngine([Random? random]) : random = random ?? Random();

  static const friends = [
    'أحمد',
    'سارة',
    'خالد',
    'مريم',
    'يوسف',
    'ليلى',
    'عمر',
  ];

  /// Picks two wrong options to remove.
  Set<int> fiftyFifty(Question q) {
    final wrong = [
      for (var i = 0; i < q.options.length; i++)
        if (i != q.answer) i,
    ]..shuffle(random);
    return wrong.take(2).toSet();
  }

  /// Audience percentages per option (sum = 100, removed options get 0).
  ///
  /// The crowd leans towards the right answer: how strongly depends on the
  /// difficulty, and on hard questions the crowd is occasionally misled.
  Map<int, int> audience(Question q, {Set<int> removed = const {}}) {
    final live = [
      for (var i = 0; i < q.options.length; i++)
        if (!removed.contains(i)) i,
    ];
    final (minShare, maxShare, reliability) = switch (q.difficulty) {
      1 => (55, 80, 1.0),
      2 => (42, 65, 0.9),
      _ => (32, 52, 0.75),
    };
    final favourite = random.nextDouble() < reliability
        ? q.answer
        : (live.where((i) => i != q.answer).toList()..shuffle(random)).first;

    var top = minShare + random.nextInt(maxShare - minShare + 1);
    if (live.length == 2) top = max(top, 55 + random.nextInt(25));
    final others = live.where((i) => i != favourite).toList();
    final weights = [for (final _ in others) 1 + random.nextInt(10)];
    final weightSum = weights.fold<int>(0, (a, b) => a + b);
    final rest = 100 - top;
    final result = {for (var i = 0; i < q.options.length; i++) i: 0};
    var given = 0;
    for (var k = 0; k < others.length; k++) {
      final share = k == others.length - 1
          ? rest - given
          : (rest * weights[k] / weightSum).floor();
      result[others[k]] = share;
      given += share;
    }
    result[favourite] = top;
    // Keep the favourite strictly on top so the poll reads as a clear lean.
    final maxOther = others.isEmpty
        ? 0
        : others.map((i) => result[i]!).reduce(max);
    if (maxOther >= top) {
      final loser = others.firstWhere((i) => result[i] == maxOther);
      result[loser] = top - 1;
      result[favourite] = top + (maxOther - top + 1);
    }
    return result;
  }

  /// The friend is usually right on easy questions and less reliable later.
  FriendHint phoneFriend(Question q, {Set<int> removed = const {}}) {
    final name = friends[random.nextInt(friends.length)];
    final accuracy = switch (q.difficulty) {
      1 => 0.95,
      2 => 0.8,
      _ => 0.6,
    };
    final right = random.nextDouble() < accuracy;
    final live = [
      for (var i = 0; i < q.options.length; i++)
        if (!removed.contains(i) && i != q.answer) i,
    ];
    final pickIdx = right || live.isEmpty
        ? q.answer
        : live[random.nextInt(live.length)];
    final confident = right
        ? random.nextDouble() < accuracy
        : random.nextBool();
    return FriendHint(name, pickIdx, confident);
  }
}
