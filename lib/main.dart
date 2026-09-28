import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/game_data.dart';
import 'screens/splash_screen.dart';
import 'services/ad_service.dart';
import 'services/audio_service.dart';
import 'services/iap_service.dart';
import 'services/storage_service.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final storage = StorageService();
  await storage.init();
  final ads = AdService(storage);
  final iap = IapService(storage);
  final audio = AudioService(storage);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: storage),
        Provider.value(value: ads),
        Provider.value(value: iap),
        Provider.value(value: audio),
        Provider(create: (_) => GameData()),
      ],
      child: const MillionQuizApp(),
    ),
  );
  // Consent + SDK init run in the background so the splash is not blocked.
  ads.init();
  iap.init();
}

class MillionQuizApp extends StatefulWidget {
  const MillionQuizApp({super.key});

  @override
  State<MillionQuizApp> createState() => _MillionQuizAppState();
}

class _MillionQuizAppState extends State<MillionQuizApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final audio = context.read<AudioService>();
    if (state == AppLifecycleState.paused) audio.suspend();
    if (state == AppLifecycleState.resumed) audio.resumeFromBackground();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مسابقة المليون',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: AppColors.gold,
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bgTop,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
