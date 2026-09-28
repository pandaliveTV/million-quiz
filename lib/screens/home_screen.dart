import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/prize_ladder.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../widgets/common.dart';
import 'categories_screen.dart';
import 'game_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AudioService>().playMusic(MusicTrack.menu);
  }

  Future<void> _open(Widget screen) async {
    final audio = context.read<AudioService>();
    audio.play('click');
    audio.tap();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    audio.playMusic(MusicTrack.menu);
  }

  void _howToPlay() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('كيف تلعب؟'),
        content: const SingleChildScrollView(
          child: Text(
            '• أجب عن 15 سؤالاً متدرج الصعوبة للوصول إلى المليون.\n'
            '• لديك 30 ثانية لكل سؤال.\n'
            '• السؤالان 5 و10 نقطتا أمان: لا تخسر ما بعدهما.\n'
            '• وسائل المساعدة: حذف إجابتين، سؤال الجمهور، الاتصال بصديق، تغيير السؤال.\n'
            '• يمكنك استرجاع وسيلة مستخدمة بمشاهدة إعلان أو بالعملات.\n'
            '• عند الخسارة يمكنك أخذ فرصة ثانية مرة واحدة.\n'
            '• يمكنك الانسحاب في أي وقت والاحتفاظ بما ربحته.\n\n'
            'الجوائز افتراضية (نقاط) للتسلية فقط.',
            style: TextStyle(height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('فهمت'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<StorageService>();
    return Scaffold(
      body: StageBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    const CoinBadge(),
                    const Spacer(),
                    const MuteButton(),
                    IconButton(
                      tooltip: 'الإعدادات',
                      icon: const Icon(Icons.settings),
                      onPressed: () => _open(const SettingsScreen()),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 12),
                          GameLogo(size: c.maxHeight < 560 ? 0.75 : 1),
                          const SizedBox(height: 22),
                          _StatsCard(storage: s),
                          const SizedBox(height: 26),
                          BigButton(
                            'ابدأ اللعب',
                            icon: Icons.play_arrow_rounded,
                            onPressed: () => _open(const GameScreen()),
                          ),
                          const SizedBox(height: 12),
                          BigButton(
                            'اختر المجال',
                            icon: Icons.category,
                            primary: false,
                            onPressed: () => _open(const CategoriesScreen()),
                          ),
                          const SizedBox(height: 12),
                          BigButton(
                            'كيف تلعب؟',
                            icon: Icons.help_outline,
                            primary: false,
                            onPressed: _howToPlay,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
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

class _StatsCard extends StatelessWidget {
  final StorageService storage;
  const _StatsCard({required this.storage});

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, String value, IconData icon) => Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.gold, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Panel(
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'المستوى ${storage.level}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: storage.levelProgress,
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                stat(
                  'أعلى نتيجة',
                  PrizeLadder.format(storage.bestScore),
                  Icons.emoji_events,
                ),
                stat(
                  'أبعد سؤال',
                  storage.bestQuestion == 0
                      ? '-'
                      : '${storage.bestQuestion}/15',
                  Icons.stairs,
                ),
                stat('جولات', '${storage.gamesPlayed}', Icons.sports_esports),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
