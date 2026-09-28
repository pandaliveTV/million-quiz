import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../services/ad_service.dart';
import '../services/storage_service.dart';

/// TODO(EliteP): replace with the published EliteP privacy policy URL.
const privacyPolicyUrl = 'https://elitep.com/privacy';

class AppColors {
  static const bgTop = Color(0xFF050A26);
  static const bgBottom = Color(0xFF1C0F4F);
  static const gold = Color(0xFFF5C542);
  static const goldDeep = Color(0xFFB8860B);
  static const tile = Color(0xFF0E1A4F);
  static const tileBorder = Color(0xFF3F63C8);
  static const locked = Color(0xFFFF9F1C);
  static const correct = Color(0xFF22C55E);
  static const wrong = Color(0xFFE53935);
  static const muted = Colors.white60;
}

/// Studio-style background: deep gradient with slowly sweeping spotlights.
/// [intensity] 0..1 brightens and speeds the beams for suspense moments.
class StageBackground extends StatefulWidget {
  final Widget child;
  final double intensity;
  final Color? tint;
  const StageBackground({
    super.key,
    required this.child,
    this.intensity = 0.4,
    this.tint,
  });

  @override
  State<StageBackground> createState() => _StageBackgroundState();
}

class _StageBackgroundState extends State<StageBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.bgTop, AppColors.bgBottom],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: _SpotlightPainter(
                _c,
                widget.intensity,
                widget.tint ?? const Color(0xFF7FA7FF),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Animation<double> t;
  final double intensity;
  final Color tint;
  _SpotlightPainter(this.t, this.intensity, this.tint) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final phase = t.value * 2 * pi;
    final speed = 1 + intensity * 2;
    final beams = [(0.15, 0.0), (0.5, 2.1), (0.85, 4.2)];
    for (final (x, offset) in beams) {
      final origin = Offset(size.width * x, -20);
      final angle = pi / 2 + sin(phase * speed + offset) * 0.45;
      final len = size.height * 1.1;
      final spread = 0.16 + intensity * 0.06;
      final path = Path()
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(
          origin.dx + cos(angle - spread) * len,
          origin.dy + sin(angle - spread) * len,
        )
        ..lineTo(
          origin.dx + cos(angle + spread) * len,
          origin.dy + sin(angle + spread) * len,
        )
        ..close();
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            tint.withValues(alpha: 0.10 + intensity * 0.18),
            tint.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: origin, radius: len));
      canvas.drawPath(path, paint);
    }
    // Floor glow.
    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.gold.withValues(alpha: 0.05 + intensity * 0.10),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width / 2, size.height * 1.05),
              radius: size.width,
            ),
          );
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.intensity != intensity || old.tint != tint;
}

/// Game logo text used on splash / home.
class GameLogo extends StatelessWidget {
  final double size;
  const GameLogo({super.key, this.size = 1});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 110 * size,
          height: 110 * size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFF2A3F9E), Color(0xFF0B1240)],
            ),
            border: Border.all(color: AppColors.gold, width: 4 * size),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.45),
                blurRadius: 30 * size,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '١٠٠٠٠٠٠',
            style: TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w900,
              fontSize: 20 * size,
            ),
          ),
        ),
        SizedBox(height: 14 * size),
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            colors: [Color(0xFFFFE08A), AppColors.gold, AppColors.goldDeep],
          ).createShader(r),
          child: Text(
            'مسابقة المليون',
            style: TextStyle(
              fontSize: 38 * size,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: const [Shadow(blurRadius: 12, color: Colors.black54)],
            ),
          ),
        ),
      ],
    );
  }
}

class CoinBadge extends StatelessWidget {
  const CoinBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final coins = context.select<StorageService, int>((s) => s.coins);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on, color: AppColors.gold, size: 20),
          const SizedBox(width: 6),
          Text(
            '$coins',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

/// Quick mute toggle shown in app bars.
class MuteButton extends StatelessWidget {
  const MuteButton({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<StorageService>();
    return IconButton(
      tooltip: s.muted ? 'تشغيل الصوت' : 'كتم الصوت',
      icon: Icon(s.muted ? Icons.volume_off : Icons.volume_up),
      onPressed: () => s.setMuted(!s.muted),
    );
  }
}

class BigButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;
  const BigButton(
    this.label, {
    super.key,
    this.icon,
    this.onPressed,
    this.primary = true,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320, minHeight: 54),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: primary ? AppColors.gold : AppColors.tile,
            foregroundColor: primary ? Colors.black87 : Colors.white,
            side: primary
                ? null
                : const BorderSide(color: AppColors.tileBorder, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          onPressed: onPressed,
          icon: Icon(icon ?? Icons.play_arrow),
          label: Text(label),
        ),
      ),
    );
  }
}

/// Banner shown only on menu screens (Home, Categories) — never in gameplay.
/// Waits for consent/SDK init and the first-run grace period before loading.
class BannerSlot extends StatefulWidget {
  const BannerSlot({super.key});

  @override
  State<BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<BannerSlot> {
  BannerAd? _ad;
  bool _loaded = false;
  Timer? _retry;
  late final AdService _ads = context.read<AdService>();

  @override
  void initState() {
    super.initState();
    _ads.ready.addListener(_tryLoad);
    _tryLoad();
  }

  void _tryLoad() {
    if (_ad != null || !mounted) return;
    if (!_ads.ready.value) return;
    final wait = _ads.policy.graceRemaining;
    if (wait > Duration.zero) {
      _retry?.cancel();
      _retry = Timer(wait + const Duration(seconds: 1), _tryLoad);
      return;
    }
    _ad = _ads.createBanner(() {
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    _ads.ready.removeListener(_tryLoad);
    _retry?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final removed = context.select<StorageService, bool>((s) => s.adsRemoved);
    final ad = _ad;
    if (removed || !_loaded || ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}

/// Glassy rounded panel.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.tileBorder.withValues(alpha: 0.6)),
      ),
      child: child,
    );
  }
}
