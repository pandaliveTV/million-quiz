import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/game_data.dart';
import '../game/lifelines.dart';
import '../game/prize_ladder.dart';
import '../game/quiz_game.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../widgets/common.dart';
import '../widgets/game_widgets.dart';
import 'result_screen.dart';

class GameScreen extends StatefulWidget {
  /// null = questions from every category.
  final String? category;
  const GameScreen({super.key, this.category});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  static const restoreCost = 150;

  late final QuizGame game;
  late final AudioService audio = context.read<AudioService>();
  late final AdService ads = context.read<AdService>();
  final Set<String> _pauseReasons = {};
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _lastSecond = QuizGame.secondsPerQuestion;
  bool _busy = false;
  bool _failureHandled = false;
  String? _flash;

  @override
  void initState() {
    super.initState();
    game = QuizGame(context.read<GameData>().bank, category: widget.category)
      ..start();
    game.addListener(_onGameChanged);
    WidgetsBinding.instance.addObserver(this);
    ads.fullScreenVisible.addListener(_onAdVisibility);
    audio.playMusic(MusicTrack.tension);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ads.fullScreenVisible.removeListener(_onAdVisibility);
    game.removeListener(_onGameChanged);
    game.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------- pausing
  void _setPaused(String reason, bool paused) {
    paused ? _pauseReasons.add(reason) : _pauseReasons.remove(reason);
    _pauseReasons.isEmpty ? game.resume() : game.pause();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _setPaused('background', state != AppLifecycleState.resumed);
  }

  void _onAdVisibility() => _setPaused('ad', ads.fullScreenVisible.value);

  Future<T?> _dialog<T>(
    WidgetBuilder builder, {
    bool dismissible = true,
  }) async {
    _setPaused('dialog', true);
    final r = await showDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      builder: builder,
    );
    if (mounted) _setPaused('dialog', false);
    return r;
  }

  // ------------------------------------------------------------ game flow
  void _onGameChanged() {
    if (!mounted) return;
    if (game.phase == GamePhase.asking && game.secondsLeft != _lastSecond) {
      _lastSecond = game.secondsLeft;
      if (_lastSecond <= 10 && _lastSecond > 0) audio.play('tick');
    }
    if (game.phase == GamePhase.failed &&
        game.endReason == EndReason.timeout &&
        !_failureHandled) {
      _failureHandled = true;
      audio.play('wrong');
      audio.heavy();
      Future.delayed(const Duration(milliseconds: 900), _onFailure);
    }
    setState(() {});
  }

  Future<void> _answer(int index) async {
    if (_busy || game.phase != GamePhase.asking) return;
    _busy = true;
    audio.tap();
    audio.play('lock');
    game.lock(index);
    // Suspense before the reveal.
    await Future.delayed(Duration(milliseconds: 1400 + game.level * 90));
    if (!mounted) return;
    final ok = game.reveal();
    if (ok) {
      audio.play(game.phase == GamePhase.over ? 'win' : 'correct');
      audio.tap();
      setState(() => _flash = '+ ${PrizeLadder.format(game.currentPrize)}');
      await Future.delayed(const Duration(milliseconds: 1600));
      if (!mounted) return;
      setState(() => _flash = null);
      if (game.phase == GamePhase.over) {
        _goToResult();
      } else {
        final reachedSafe = PrizeLadder.isSafe(game.level);
        game.next();
        _lastSecond = QuizGame.secondsPerQuestion;
        if (reachedSafe) _toast('وصلت إلى نقطة أمان! رصيدك المضمون محفوظ 🛡️');
      }
    } else {
      audio.play('wrong');
      audio.heavy();
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) await _onFailure();
    }
    _busy = false;
  }

  Future<void> _onFailure() async {
    if (!mounted || game.phase != GamePhase.failed) return;
    final canRescue = game.canTakeSecondChance && ads.canShowRewarded;
    final timeout = game.endReason == EndReason.timeout;
    final rescue = await _dialog<bool>(
      (context) => AlertDialog(
        title: Text(timeout ? 'انتهى الوقت! ⏰' : 'إجابة خاطئة ❌'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'رصيدك المضمون: ${PrizeLadder.format(PrizeLadder.guaranteedBefore(game.level))} نقطة',
              textAlign: TextAlign.center,
            ),
            if (canRescue) ...[
              const SizedBox(height: 12),
              const Text(
                'هل تريد فرصة ثانية؟ شاهد إعلاناً قصيراً واستمر من نفس السؤال بسؤال جديد (مرة واحدة فقط).',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إنهاء الجولة'),
          ),
          if (canRescue)
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.ondemand_video),
              label: const Text('فرصة ثانية'),
            ),
        ],
      ),
      dismissible: false,
    );
    if (!mounted) return;
    if (rescue == true && await ads.showRewarded() && mounted) {
      _failureHandled = false;
      _lastSecond = QuizGame.secondsPerQuestion;
      game.takeSecondChance();
      _toast('فرصة ثانية! هذا سؤال جديد بنفس المستوى');
      return;
    }
    if (!mounted) return;
    game.finish();
    _goToResult();
  }

  void _goToResult() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          reason: game.endReason ?? EndReason.walkedAway,
          winnings: game.winnings,
          correct: game.correctCount,
          questionReached: game.level + 1,
          coins: game.coinsEarned,
          category: widget.category,
        ),
      ),
    );
  }

  Future<void> _walkAway() async {
    if (game.phase != GamePhase.asking || _busy) return;
    final banked = PrizeLadder.bankedBefore(game.level);
    final yes = await _dialog<bool>(
      (context) => AlertDialog(
        title: const Text('الانسحاب'),
        content: Text(
          'هل تريد الانسحاب والاحتفاظ بـ ${PrizeLadder.format(banked)} نقطة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('أكمل اللعب'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('انسحب'),
          ),
        ],
      ),
    );
    if (yes == true && mounted && game.phase == GamePhase.asking) {
      game.walkAway();
      _goToResult();
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
  }

  // ------------------------------------------------------------ lifelines
  Future<void> _onLifeline(Lifeline l) async {
    if (_busy) return;
    if (!game.isAvailable(l)) {
      if (game.canRestore(l)) await _restore(l);
      return;
    }
    if (!game.canUseLifelines) return;
    audio.play('lifeline');
    audio.tap();
    game.useLifeline(l);
    switch (l) {
      case Lifeline.audience:
        await _dialog<void>(
          (context) => AlertDialog(
            title: const Text('تصويت الجمهور'),
            content: AudienceChart(votes: game.audienceResult!),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('شكراً'),
              ),
            ],
          ),
        );
      case Lifeline.phoneFriend:
        final hint = game.friendHint!;
        await _dialog<void>(
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.phone_in_talk, color: AppColors.gold),
                const SizedBox(width: 8),
                Text('صديقك ${hint.name}'),
              ],
            ),
            content: Text(
              '"${hint.message}"',
              style: const TextStyle(fontSize: 18),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('شكراً'),
              ),
            ],
          ),
        );
      case Lifeline.switchQuestion:
        _lastSecond = QuizGame.secondsPerQuestion;
        _toast('تم تغيير السؤال');
      case Lifeline.fiftyFifty:
        break;
    }
  }

  Future<void> _restore(Lifeline l) async {
    final storage = context.read<StorageService>();
    final adOk = ads.canShowRewarded;
    final coinsOk = storage.coins >= restoreCost;
    final choice = await _dialog<String>(
      (context) => AlertDialog(
        title: Text('استرجاع "${l.title}"'),
        content: Text(
          adOk || coinsOk
              ? 'يمكنك استرجاع هذه الوسيلة مرة واحدة في الجولة.'
              : 'لا يتوفر إعلان الآن ولا تملك عملات كافية ($restoreCost).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          if (coinsOk)
            TextButton.icon(
              onPressed: () => Navigator.pop(context, 'coins'),
              icon: const Icon(Icons.monetization_on, color: AppColors.gold),
              label: Text('$restoreCost عملة'),
            ),
          if (adOk)
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, 'ad'),
              icon: const Icon(Icons.ondemand_video),
              label: const Text('شاهد إعلاناً'),
            ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    var ok = false;
    if (choice == 'coins') ok = storage.spend(restoreCost);
    if (choice == 'ad') ok = await ads.showRewarded();
    if (ok && mounted && game.restoreLifeline(l)) {
      audio.play('coin');
      _toast('تم استرجاع "${l.title}"');
    }
  }

  // ------------------------------------------------------------------ UI
  TileState _tileState(int i) {
    final q = game.question;
    switch (game.phase) {
      case GamePhase.asking:
        return game.removed.contains(i) ? TileState.hidden : TileState.idle;
      case GamePhase.locked:
        if (game.selected == i) return TileState.locked;
        return game.removed.contains(i) ? TileState.hidden : TileState.idle;
      case GamePhase.correct:
      case GamePhase.over:
      case GamePhase.failed:
        if (i == q.answer) {
          return game.selected == i ? TileState.correct : TileState.reveal;
        }
        if (game.selected == i) return TileState.wrong;
        return game.removed.contains(i) ? TileState.hidden : TileState.idle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = game.question;
    final suspense = switch (game.phase) {
      GamePhase.locked => 0.9,
      GamePhase.asking =>
        0.3 + game.level / 30 + (game.secondsLeft <= 10 ? 0.25 : 0),
      _ => 0.5,
    };
    final tint = switch (game.phase) {
      GamePhase.correct || GamePhase.over
          when game.endReason != EndReason.wrong =>
        AppColors.correct,
      GamePhase.failed => AppColors.wrong,
      GamePhase.locked => AppColors.locked,
      _ => null,
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _walkAway();
      },
      child: Scaffold(
        key: _scaffoldKey,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'انسحاب',
            icon: const Icon(Icons.close),
            onPressed: _walkAway,
          ),
          title: Text('السؤال ${game.level + 1} من ${PrizeLadder.length}'),
          actions: [
            const MuteButton(),
            IconButton(
              tooltip: 'سلم الجوائز',
              icon: const Icon(Icons.format_list_numbered),
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          ],
        ),
        endDrawer: Drawer(
          backgroundColor: AppColors.bgBottom,
          child: SafeArea(child: PrizeLadderView(currentLevel: game.level)),
        ),
        body: StageBackground(
          intensity: suspense.clamp(0.0, 1.0),
          tint: tint,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight - 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _topBar(),
                          const SizedBox(height: 12),
                          _lifelineRow(),
                          const SizedBox(height: 16),
                          _questionPanel(q.text),
                          const SizedBox(height: 16),
                          for (var i = 0; i < 4; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: AnswerTile(
                                key: ValueKey('${q.id}-$i'),
                                index: i,
                                text: q.options[i],
                                state: _tileState(i),
                                onTap: () => _answer(i),
                              ),
                            ),
                          const SizedBox(height: 6),
                          TextButton.icon(
                            onPressed: game.phase == GamePhase.asking
                                ? _walkAway
                                : null,
                            icon: const Icon(Icons.directions_walk),
                            label: Text(
                              'انسحب بـ ${PrizeLadder.format(PrizeLadder.bankedBefore(game.level))}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        TimerRing(
          seconds: game.secondsLeft,
          total: QuizGame.secondsPerQuestion,
          active: game.phase == GamePhase.asking,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سؤال بقيمة',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _flash ?? PrizeLadder.format(game.currentPrize),
                  key: ValueKey(_flash ?? game.level),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: _flash != null ? AppColors.correct : AppColors.gold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'المضمون',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            Row(
              children: [
                const Icon(Icons.shield, size: 16, color: AppColors.gold),
                const SizedBox(width: 4),
                Text(
                  PrizeLadder.format(PrizeLadder.guaranteedBefore(game.level)),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _lifelineRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final l in Lifeline.values)
          LifelineButton(
            lifeline: l,
            used: !game.isAvailable(l),
            enabled: game.canUseLifelines && game.isAvailable(l),
            canRestore: game.canRestore(l) && game.phase == GamePhase.asking,
            onTap: () => _onLifeline(l),
          ),
      ],
    );
  }

  Widget _questionPanel(String text) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(a),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(game.question.id),
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 110),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [Color(0xFF142466), Color(0xFF0B1240)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.8),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.15),
              blurRadius: 24,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}
