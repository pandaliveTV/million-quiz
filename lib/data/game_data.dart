import 'question.dart';

/// Holds the question bank once the splash screen has loaded it.
class GameData {
  QuestionBank? _bank;
  GameData([this._bank]);

  QuestionBank get bank => _bank!;
  bool get isLoaded => _bank != null;

  Future<void> load() async {
    _bank ??= await QuestionBank.load();
  }
}
