import 'dart:math';

import 'package:flutter/material.dart';

import '../game/lifelines.dart';
import '../game/prize_ladder.dart';
import 'common.dart';

enum TileState { idle, hidden, locked, correct, wrong, reveal }

/// One answer option in the classic elongated-hexagon style.
class AnswerTile extends StatefulWidget {
  final int index;
  final String text;
  final TileState state;
  final VoidCallback? onTap;
  const AnswerTile({
    super.key,
    required this.index,
    required this.text,
    required this.state,
    this.onTap,
  });

  @override
  State<AnswerTile> createState() => _AnswerTileState();
}

class _AnswerTileState extends State<AnswerTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void didUpdateWidget(AnswerTile old) {
    super.didUpdateWidget(old);
    if (widget.state == TileState.correct && old.state != TileState.correct) {
      _blink.repeat(reverse: true);
      Future.delayed(const Duration(milliseconds: 1300), () {
        if (mounted) _blink.stop();
      });
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hidden = widget.state == TileState.hidden;
    final (Color fill, Color border) = switch (widget.state) {
      TileState.locked => (AppColors.locked, const Color(0xFFFFD08A)),
      TileState.correct => (AppColors.correct, const Color(0xFFB9F6CA)),
      TileState.reveal => (
        AppColors.correct.withValues(alpha: 0.75),
        AppColors.correct,
      ),
      TileState.wrong => (AppColors.wrong, const Color(0xFFFFB4B4)),
      _ => (AppColors.tile, AppColors.tileBorder),
    };
    final dark = widget.state == TileState.idle || hidden;
    return AnimatedBuilder(
      animation: _blink,
      builder: (context, child) => Opacity(
        opacity: widget.state == TileState.correct
            ? 0.55 + 0.45 * (1 - _blink.value)
            : 1,
        child: child,
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: hidden ? 0.25 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const _HexBorder(),
            onTap: hidden ? null : widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              constraints: const BoxConstraints(minHeight: 54),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: ShapeDecoration(
                shape: _HexBorder(side: BorderSide(color: border, width: 2)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(fill, Colors.white, 0.12)!, fill],
                ),
                shadows: [
                  if (!dark)
                    BoxShadow(
                      color: fill.withValues(alpha: 0.55),
                      blurRadius: 18,
                    ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    '${optionLetters[widget.index]}:',
                    style: TextStyle(
                      color: dark ? AppColors.gold : Colors.black87,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hidden ? '' : widget.text,
                      style: TextStyle(
                        color: dark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Elongated hexagon (pointed left/right ends).
class _HexBorder extends ShapeBorder {
  final BorderSide side;
  const _HexBorder({this.side = BorderSide.none});

  Path _path(Rect r) {
    final tip = min(18.0, r.height / 2);
    return Path()
      ..moveTo(r.left, r.center.dy)
      ..lineTo(r.left + tip, r.top)
      ..lineTo(r.right - tip, r.top)
      ..lineTo(r.right, r.center.dy)
      ..lineTo(r.right - tip, r.bottom)
      ..lineTo(r.left + tip, r.bottom)
      ..close();
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect.deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(_path(rect.deflate(side.width / 2)), side.toPaint());
  }

  @override
  ShapeBorder scale(double t) => _HexBorder(side: side.scale(t));
}

/// Circular 30-second countdown that turns red in the last 10 seconds.
class TimerRing extends StatelessWidget {
  final int seconds;
  final int total;
  final bool active;
  const TimerRing({
    super.key,
    required this.seconds,
    required this.total,
    this.active = true,
  });

  @override
  Widget build(BuildContext context) {
    final danger = seconds <= 10;
    final color = !active
        ? Colors.white38
        : (danger ? AppColors.wrong : AppColors.gold);
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        fit: StackFit.expand,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: seconds / total),
            duration: const Duration(milliseconds: 900),
            builder: (_, v, _) => CircularProgressIndicator(
              value: v,
              strokeWidth: 6,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Center(
            child: Text(
              '$seconds',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical prize ladder (top = 1,000,000). Used in the game drawer.
class PrizeLadderView extends StatelessWidget {
  final int currentLevel;
  const PrizeLadderView({super.key, required this.currentLevel});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: PrizeLadder.length,
      itemBuilder: (context, i) {
        final level = PrizeLadder.length - 1 - i;
        final current = level == currentLevel;
        final passed = level < currentLevel;
        final safe = PrizeLadder.isSafe(level);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: current ? AppColors.locked : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '${level + 1}',
                  style: TextStyle(
                    color: current ? Colors.black : AppColors.muted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(
                passed
                    ? Icons.check_circle
                    : (safe ? Icons.shield : Icons.circle),
                size: passed || safe ? 16 : 6,
                color: current
                    ? Colors.black87
                    : (passed ? AppColors.correct : AppColors.gold),
              ),
              const Spacer(),
              Text(
                PrizeLadder.format(PrizeLadder.prizeAt(level)),
                style: TextStyle(
                  fontWeight: safe || current
                      ? FontWeight.w900
                      : FontWeight.w600,
                  color: current
                      ? Colors.black
                      : (safe ? AppColors.gold : Colors.white),
                  fontSize: safe ? 17 : 15,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Round lifeline button; used lifelines show a restore badge.
class LifelineButton extends StatelessWidget {
  final Lifeline lifeline;
  final bool used;
  final bool enabled;
  final bool canRestore;
  final VoidCallback onTap;
  const LifelineButton({
    super.key,
    required this.lifeline,
    required this.used,
    required this.enabled,
    required this.canRestore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = switch (lifeline) {
      Lifeline.fiftyFifty => null,
      Lifeline.audience => Icons.groups,
      Lifeline.phoneFriend => Icons.phone_in_talk,
      Lifeline.switchQuestion => Icons.swap_horiz,
    };
    final color = used ? Colors.white30 : AppColors.gold;
    return Tooltip(
      message: lifeline.title,
      child: InkResponse(
        onTap: enabled || (used && canRestore) ? onTap : null,
        radius: 34,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 58,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: AppColors.tile,
                border: Border.all(color: color, width: 2),
              ),
              alignment: Alignment.center,
              child: icon == null
                  ? Text(
                      '50:50',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    )
                  : Icon(icon, color: color, size: 22),
            ),
            if (used)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _CrossPainter()),
                ),
              ),
            if (used && canRestore)
              const Positioned(
                top: -6,
                left: -6,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: AppColors.correct,
                  child: Icon(Icons.replay, size: 13, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.wrong
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      const Offset(10, 8),
      Offset(size.width - 10, size.height - 8),
      p,
    );
    canvas.drawLine(Offset(size.width - 10, 8), Offset(10, size.height - 8), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bar chart for the audience poll.
class AudienceChart extends StatelessWidget {
  final Map<int, int> votes;
  const AudienceChart({super.key, required this.votes});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < 4; i++)
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${votes[i] ?? 0}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: (votes[i] ?? 0) / 100),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => Container(
                    width: 36,
                    height: max(2, 110 * v),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                      gradient: const LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [AppColors.goldDeep, AppColors.gold],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  optionLetters[i],
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
