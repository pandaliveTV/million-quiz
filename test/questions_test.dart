import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:millionquiz/data/question.dart';

/// Strips diacritics/punctuation so near-identical questions are caught.
String _norm(String s) => s
    .replaceAll(RegExp('[ً-ْـ]'), '')
    .replaceAll(RegExp('[إأآ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .replaceAll(RegExp(r'[\s؟?،,:"«»()]+'), '');

void main() {
  final raw = File(QuestionBank.assetPath).readAsStringSync();
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final bank = QuestionBank.fromJsonString(raw);

  test('has at least 1500 questions', () {
    expect(bank.all.length, greaterThanOrEqualTo(1500));
  });

  test('every question is well-formed', () {
    final cats = (data['categories'] as Map).keys.toSet();
    for (final q in bank.all) {
      final where = 'question ${q.id}';
      expect(q.text.trim(), isNotEmpty, reason: where);
      expect(q.options.length, 4, reason: where);
      expect(
        q.options.every((o) => o.trim().isNotEmpty),
        isTrue,
        reason: where,
      );
      expect(
        q.options.map(_norm).toSet().length,
        4,
        reason: '$where has duplicate options: ${q.options}',
      );
      expect(q.answer, inInclusiveRange(0, 3), reason: where);
      expect(q.difficulty, inInclusiveRange(1, 3), reason: where);
      expect(cats, contains(q.category), reason: where);
    }
  });

  test('ids and question texts are unique', () {
    expect(bank.all.map((q) => q.id).toSet().length, bank.all.length);
    final seen = <String, int>{};
    for (final q in bank.all) {
      // "Which number is prime?" is reused on purpose with different options.
      final key = q.text.contains('عدد أولي')
          ? '${_norm(q.text)}|${q.options[q.answer]}'
          : _norm(q.text);
      expect(
        seen.containsKey(key),
        isFalse,
        reason: 'duplicate of question ${seen[key]}: ${q.text}',
      );
      seen[key] = q.id;
    }
  });

  test('every difficulty tier is deep enough for many rounds', () {
    for (final d in [1, 2, 3]) {
      final n = bank.all.where((q) => q.difficulty == d).length;
      expect(n, greaterThanOrEqualTo(200), reason: 'difficulty $d has $n');
    }
  });

  test('every category has questions', () {
    final cats = (data['categories'] as Map).keys;
    for (final c in cats) {
      expect(bank.countFor(c as String), greaterThanOrEqualTo(80), reason: c);
    }
  });

  test('correct answers are spread over all four positions', () {
    final counts = List.filled(4, 0);
    for (final q in bank.all) {
      counts[q.answer]++;
    }
    for (final c in counts) {
      expect(c, greaterThan(bank.all.length ~/ 6));
    }
  });

  test('bank never repeats a question in one session', () {
    final seen = <int>{};
    final total = bank.all.where((q) => q.difficulty == 1).length;
    for (var i = 0; i < total; i++) {
      expect(seen.add(bank.next(1).id), isTrue);
    }
    // Pool exhausted: it recycles instead of failing.
    expect(bank.next(1).difficulty, 1);
  });

  test('category filter is respected while the pool lasts', () {
    final b = QuestionBank.fromJsonString(raw);
    for (var i = 0; i < 20; i++) {
      expect(b.next(2, category: 'islamic').category, 'islamic');
    }
  });
}
