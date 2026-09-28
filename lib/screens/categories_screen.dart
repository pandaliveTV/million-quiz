import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/game_data.dart';
import '../services/audio_service.dart';
import '../widgets/common.dart';
import 'game_screen.dart';

/// The "levels" screen: pick a knowledge field (or mix them all).
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  static const icons = <String, IconData>{
    'islamic': Icons.mosque,
    'history': Icons.account_balance,
    'geography': Icons.public,
    'science': Icons.science,
    'language': Icons.menu_book,
    'arts': Icons.palette,
    'sports': Icons.sports_soccer,
    'tech': Icons.computer,
    'general': Icons.lightbulb,
    'math': Icons.calculate,
  };

  @override
  Widget build(BuildContext context) {
    final bank = context.read<GameData>().bank;
    final entries = <(String?, String, IconData)>[
      (null, 'كل المجالات', Icons.all_inclusive),
      for (final e in bank.categories.entries)
        (e.key, e.value, icons[e.key] ?? Icons.quiz),
    ];
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('اختر المجال')),
      body: StageBackground(
        intensity: 0.25,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final cols = c.maxWidth > 600 ? 3 : 2;
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.35,
                      ),
                      itemCount: entries.length,
                      itemBuilder: (context, i) {
                        final (key, name, icon) = entries[i];
                        return _CategoryCard(
                          name: name,
                          icon: icon,
                          count: bank.countFor(key),
                          highlight: key == null,
                          onTap: () {
                            final audio = context.read<AudioService>();
                            audio.play('click');
                            audio.tap();
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => GameScreen(category: key),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const BannerSlot(),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final int count;
  final bool highlight;
  final VoidCallback onTap;
  const _CategoryCard({
    required this.name,
    required this.icon,
    required this.count,
    required this.highlight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlight
          ? AppColors.gold.withValues(alpha: 0.18)
          : Colors.black.withValues(alpha: 0.28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: highlight ? AppColors.gold : AppColors.tileBorder,
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.gold, size: 32),
              const SizedBox(height: 8),
              FittedBox(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '$count سؤال',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
