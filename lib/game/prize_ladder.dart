/// Virtual prize ladder (points, not real money) with two safe havens.
class PrizeLadder {
  static const List<int> prizes = [
    100,
    200,
    300,
    500,
    1000,
    2000,
    4000,
    8000,
    16000,
    32000,
    64000,
    125000,
    250000,
    500000,
    1000000,
  ];

  /// Zero-based indexes of the safe questions (question 5 and 10).
  static const Set<int> safeLevels = {4, 9};

  static int get length => prizes.length;

  static int prizeAt(int level) => prizes[level];

  static bool isSafe(int level) => safeLevels.contains(level);

  /// Difficulty tier for a zero-based question [level].
  static int difficultyFor(int level) => level < 5 ? 1 : (level < 10 ? 2 : 3);

  /// Points kept when answering question [level] wrongly (or on timeout).
  static int guaranteedBefore(int level) {
    var result = 0;
    for (final s in safeLevels) {
      if (s < level && prizes[s] > result) result = prizes[s];
    }
    return result;
  }

  /// Points banked after correctly answering all questions before [level].
  static int bankedBefore(int level) => level == 0 ? 0 : prizes[level - 1];

  static String format(int value) {
    final s = value.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
}
