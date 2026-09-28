import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:millionquiz/data/game_data.dart';
import 'package:millionquiz/data/question.dart';
import 'package:millionquiz/screens/home_screen.dart';
import 'package:millionquiz/services/ad_service.dart';
import 'package:millionquiz/services/audio_service.dart';
import 'package:millionquiz/services/iap_service.dart';
import 'package:millionquiz/services/storage_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the real screens on a small (320x568 dp) phone to catch layout overflows and
/// broken navigation. Sound is muted so no platform audio is touched.
void main() {
  late StorageService storage;
  late QuestionBank bank;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'muted': true,
      'firstLaunch': DateTime.now().millisecondsSinceEpoch,
    });
    storage = StorageService();
    await storage.init();
    bank = QuestionBank.fromJsonString(
      File(QuestionBank.assetPath).readAsStringSync(),
    );
  });

  Widget app() => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: storage),
      Provider.value(value: AdService(storage)),
      Provider.value(value: IapService(storage)),
      Provider.value(value: AudioService(storage)),
      Provider.value(value: GameData(bank)),
    ],
    child: const MaterialApp(
      locale: Locale('ar'),
      supportedLocales: [Locale('ar')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: HomeScreen(),
    ),
  );

  /// Advances time in 50 ms frames (animations and delays run as on device).
  Future<void> step(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> useSmallPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  testWidgets('home → game → answer → result flow renders', (tester) async {
    await useSmallPhone(tester);
    await tester.pumpWidget(app());
    await step(tester, 100);
    expect(find.text('مسابقة المليون'), findsOneWidget);

    await tester.tap(find.text('ابدأ اللعب'));
    await step(tester, 600);
    expect(find.text('السؤال 1 من 15'), findsOneWidget);

    // 50:50 hides two options.
    await tester.tap(find.text('50:50'));
    await step(tester, 400);

    // Walk away immediately → result screen.
    await tester.tap(find.byIcon(Icons.close));
    await step(tester, 400);
    await tester.tap(find.text('انسحب'));
    await step(tester, 800);
    expect(find.text('القائمة الرئيسية'), findsOneWidget);
    expect(storage.gamesPlayed, 1);

    await tester.tap(find.text('القائمة الرئيسية'));
    await step(tester, 800);
    expect(find.text('ابدأ اللعب'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('answering the first question reveals and advances or ends', (
    tester,
  ) async {
    await useSmallPhone(tester);
    await tester.pumpWidget(app());
    await step(tester, 100);
    await tester.tap(find.text('ابدأ اللعب'));
    await step(tester, 600);

    await tester.tap(find.textContaining('أ:'));
    // Suspense + reveal + transition.
    await step(tester, 4000);
    final advanced = find.text('السؤال 2 من 15').evaluate().isNotEmpty;
    final failed = find.text('إجابة خاطئة ❌').evaluate().isNotEmpty;
    expect(advanced || failed, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('categories screen lists every field', (tester) async {
    await useSmallPhone(tester);
    await tester.pumpWidget(app());
    await step(tester, 100);
    await tester.tap(find.text('اختر المجال'));
    await step(tester, 600);
    expect(find.text('كل المجالات'), findsOneWidget);
    expect(find.text('ثقافة إسلامية'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
