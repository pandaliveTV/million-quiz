import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/prize_ladder.dart';
import '../game/quiz_game.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../widgets/common.dart';
import 'game_screen.dart';

/// End-of-round summary. Leaving it counts as a finished round for the
/// interstitial rule.
class ResultScreen extends StatefulWidget {
  final EndReason reason;
  final int winnings;
  final int correct;
  final int questionReached;
  final int coins;
  final String? category;
  const ResultScreen({
    super.key,
    required this.reason,
    required this.winnings,
    required this.correct,
    required this.questionReached,
    required this.coins,
    this.category,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _record = false;
  bool _doubled = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    final audio = context.read<AudioService>();
    audio.playMusic(MusicTrack.menu);
    if (widget.reason == EndReason.won) audio.play('win');
    // Save after the first frame: storage notifies listeners, which must not
    // happen while the widget tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveRound());
  }

  void _saveRound() {
    if (!mounted) return;
    final storage = context.read<StorageService>();
    final record = storage.recordRound(
      score: widget.winnings,
      questionReached: widget.questionReached,
      correct: widget.correct,
      won: widget.reason == EndReason.won,
    );
    if (widget.coins > 0) storage.addCoins(widget.coins);
    setState(() => _record = record);
  }

  Future<void> _double() async {
    final ads = context.read<AdService>();
    final storage = context.read<StorageService>();
    final audio = context.read<AudioService>();
    if (_doubled || !ads.canShowRewarded) return;
    final ok = await ads.showRewarded();
    if (!ok || !mounted) return;
    storage.addCoins(widget.coins);
    audio.play('coin');
    setState(() => _doubled = true);
  }

  void _leave({required bool again}) {
    if (_leaving) return;
    _leaving = true;
    context.read<AudioService>().play('click');
    final ads = context.read<AdService>();
    final nav = Navigator.of(context);
    if (again) {
      nav.pushReplacement(
        MaterialPageRoute(
          builder: (_) => GameScreen(category: widget.category),
        ),
      );
    } else {
      nav.pop();
    }
    // Interstitial after every complete round (the policy enforces the gaps).
    ads.onRoundFinished();
  }

  @override
  Widget build(BuildContext context) {
    final ads = context.read<AdService>();
    final (title, icon, color) = switch (widget.reason) {
      EndReason.won => (
        'مبروك! ربحت المليون 🎉',
        Icons.emoji_events,
        AppColors.gold,
      ),
      EndReason.walkedAway => (
        'انسحاب ذكي 👏',
        Icons.directions_walk,
        AppColors.locked,
      ),
      EndReason.timeout => ('انتهى الوقت', Icons.timer_off, AppColors.wrong),
      EndReason.wrong => (
        'انتهت الجولة',
        Icons.sentiment_dissatisfied,
        AppColors.wrong,
      ),
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave(again: false);
      },
      child: Scaffold(
        body: StageBackground(
          intensity: widget.reason == EndReason.won ? 1 : 0.35,
          tint: widget.reason == EndReason.won ? AppColors.gold : null,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      Icon(icon, size: 84, color: color),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Panel(
                        child: Column(
                          children: [
                            const Text(
                              'رصيدك في هذه الجولة',
                              style: TextStyle(color: AppColors.muted),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${PrizeLadder.format(widget.winnings)} نقطة',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: AppColors.gold,
                              ),
                            ),
                            if (_record && widget.winnings > 0) ...[
                              const SizedBox(height: 8),
                              const Chip(
                                avatar: Icon(Icons.star, color: AppColors.gold),
                                label: Text('رقم قياسي جديد!'),
                              ),
                            ],
                            const Divider(height: 28),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _Stat('إجابات صحيحة', '${widget.correct}'),
                                _Stat(
                                  'العملات',
                                  '+${widget.coins * (_doubled ? 2 : 1)}',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (widget.coins > 0 &&
                          !_doubled &&
                          ads.canShowRewarded) ...[
                        BigButton(
                          'ضاعف العملات (إعلان)',
                          icon: Icons.ondemand_video,
                          primary: false,
                          onPressed: _double,
                        ),
                        const SizedBox(height: 12),
                      ],
                      BigButton(
                        'العب مرة أخرى',
                        icon: Icons.replay,
                        onPressed: () => _leave(again: true),
                      ),
                      const SizedBox(height: 12),
                      BigButton(
                        'القائمة الرئيسية',
                        icon: Icons.home,
                        primary: false,
                        onPressed: () => _leave(again: false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          Text(label, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    ),
  );
}
