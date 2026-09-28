import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// One multiple-choice question from `lib/data/questions.json`.
class Question {
  final int id;
  final String category;

  /// 1 = easy (questions 1-5), 2 = medium (6-10), 3 = hard (11-15).
  final int difficulty;
  final String text;
  final List<String> options;
  final int answer;

  const Question({
    required this.id,
    required this.category,
    required this.difficulty,
    required this.text,
    required this.options,
    required this.answer,
  });

  factory Question.fromJson(Map<String, dynamic> j) => Question(
    id: j['id'] as int,
    category: j['c'] as String,
    difficulty: j['d'] as int,
    text: j['q'] as String,
    options: List<String>.unmodifiable(j['o'] as List),
    answer: j['a'] as int,
  );
}

/// Holds every question and hands out non-repeating ones for the session.
///
/// "Session" = the current app run: ids already asked are remembered in
/// memory, so the same question never appears twice until the whole pool
/// for that difficulty has been used.
class QuestionBank {
  static const assetPath = 'lib/data/questions.json';

  final List<Question> all;
  final Map<String, String> categories;
  final Set<int> _asked = {};
  final Random _random;

  QuestionBank(this.all, this.categories, {Random? random})
    : _random = random ?? Random();

  factory QuestionBank.fromJsonString(String source, {Random? random}) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    final questions = (data['questions'] as List)
        .map((e) => Question.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    final cats = (data['categories'] as Map).cast<String, String>();
    return QuestionBank(questions, cats, random: random);
  }

  static Future<QuestionBank> load() async {
    final raw = await rootBundle.loadString(assetPath);
    // Decode off the UI thread to keep the splash animation smooth.
    final parsed = await compute(_decode, raw);
    return QuestionBank(parsed.$1, parsed.$2);
  }

  static (List<Question>, Map<String, String>) _decode(String raw) {
    final b = QuestionBank.fromJsonString(raw);
    return (b.all, b.categories);
  }

  int get askedCount => _asked.length;

  /// Number of questions available in [category] (null = all categories).
  int countFor(String? category) => category == null
      ? all.length
      : all.where((q) => q.category == category).length;

  /// Returns a random not-yet-asked question of [difficulty], preferring
  /// [category]. Falls back to other categories when the category pool is
  /// empty, and recycles the difficulty only after every question of that
  /// difficulty has been asked this session.
  Question next(
    int difficulty, {
    String? category,
    Set<int> exclude = const {},
  }) {
    bool fresh(Question q) =>
        q.difficulty == difficulty &&
        !_asked.contains(q.id) &&
        !exclude.contains(q.id);

    var pool = all
        .where((q) => fresh(q) && (category == null || q.category == category))
        .toList();
    if (pool.isEmpty) pool = all.where(fresh).toList();
    if (pool.isEmpty) {
      final tierIds = {
        for (final q in all)
          if (q.difficulty == difficulty) q.id,
      };
      _asked.removeAll(tierIds);
      pool = all.where(fresh).toList();
    }
    final q = pool[_random.nextInt(pool.length)];
    _asked.add(q.id);
    return q;
  }
}
