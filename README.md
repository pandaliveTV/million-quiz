# مسابقة المليون — EliteP

لعبة أسئلة ثقافية عربية على نمط برامج المسابقات الكبرى: 15 سؤالاً متدرج الصعوبة للوصول إلى المليون (نقاط افتراضية).
Flutter + Dart 3 • Provider • Android (طولي فقط) • Package: `com.elitep.millionquiz`

> الجوائز في اللعبة نقاط افتراضية للتسلية فقط. اللعبة لا تستخدم اسم أو شعار أي برنامج تلفزيوني.

## المزايا
- **15 سؤالاً** متدرجة: 1–5 سهلة، 6–10 متوسطة، 11–15 صعبة. **سلم جوائز** افتراضي حتى 1,000,000 مع **نقطتي أمان** عند السؤال 5 (1,000) والسؤال 10 (32,000).
- **مؤقت 30 ثانية** لكل سؤال (دقات تحذير في آخر 10 ثوانٍ). يتوقف المؤقت أثناء النوافذ والإعلانات وعند الخروج من التطبيق.
- **وسائل المساعدة الأربع**: حذف إجابتين، سؤال الجمهور (نسب عشوائية ذكية تميل للصحيح حسب الصعوبة)، الاتصال بصديق (دقته تقل مع الصعوبة)، تغيير السؤال.
- **استرجاع وسيلة مستخدمة** بإعلان Rewarded (أو 150 عملة) — مرة لكل وسيلة في الجولة.
- **فرصة ثانية** بعد الخسارة بإعلان Rewarded — مرة واحدة في الجولة (سؤال جديد بنفس المستوى).
- **الانسحاب** في أي وقت مع الاحتفاظ بالرصيد.
- **2,226 سؤالاً** في `lib/data/questions.json` مصنفة حسب الصعوبة و10 مجالات، **بدون تكرار في نفس الجلسة**.
- أجواء استوديو: أضواء كاشفة متحركة تشتد مع التشويق، لحظة "الإجابة النهائية" البرتقالية، وميض الإجابة الصحيحة، موسيقى توتر وموسيقى قائمة، ومؤثرات صوتية (كلها مولَّدة وأصلية).
- حفظ محلي: المستوى (XP)، العملات، أعلى نتيجة، أبعد سؤال، الإعدادات.
- إعدادات: الأصوات (كتم)، الموسيقى، الاهتزاز، إزالة الإعلانات، استعادة المشتريات، خيارات الخصوصية (UMP)، سياسة الخصوصية.

## التشغيل
```bash
flutter pub get
flutter run            # جهاز أندرويد أو محاكي
flutter analyze        # يجب أن يكون نظيفاً
flutter test           # منطق اللعبة + صحة ملف الأسئلة + قواعد الإعلانات + اختبار واجهة
```

## بنية المشروع
```
lib/
  main.dart                 التهيئة، Providers، اللغة العربية RTL، الوضع الطولي
  data/      question.dart  نموذج السؤال + QuestionBank (عدم التكرار في الجلسة)
             game_data.dart
             questions.json بنك الأسئلة (مولَّد — لا تعدله يدوياً)
  game/      quiz_game.dart حالة الجولة (المؤقت، الإجابة، الانسحاب، الفرصة الثانية)
             lifelines.dart منطق وسائل المساعدة
             prize_ladder.dart سلم الجوائز ونقاط الأمان
  screens/   splash, home, categories (شاشة المستويات), game, result, settings
  services/  ad_service.dart, ad_policy.dart, iap_service.dart, storage_service.dart, audio_service.dart
  widgets/   common.dart (الخلفية، البانر، الأزرار), game_widgets.dart (الإجابات، المؤقت، السلم)
assets/sounds/              مؤثرات وموسيقى (WAV)
tool/questions/             مصدر الأسئلة + سكربت البناء والتحقق
tool/sounds/                سكربت توليد الأصوات
tool/icon/                  سكربت توليد أيقونة التطبيق
store/icon-512.png          أيقونة المتجر
test/                       الاختبارات
```

## بنك الأسئلة
- المصدر: `tool/questions/src/*.txt` (سطر لكل سؤال: `الصعوبة|السؤال|الصحيحة|خطأ1|خطأ2|خطأ3`) + جداول حقائق موثقة في `tool/questions/tables.py` (العواصم، العملات، العناصر، كأس العالم…) + أسئلة رياضيات محسوبة آلياً.
- لإعادة البناء بعد أي تعديل:
  ```bash
  python3 tool/questions/build_questions.py
  flutter test test/questions_test.dart
  ```
  السكربت يرفض: الأسئلة المكررة (بعد إزالة التشكيل)، الخيارات المكررة، الصفوف الناقصة. ترتيب الخيارات يُخلط بشكل ثابت (seeded).

## الإعلانات (AdMob) — أين تغيّر المعرفات
حالياً تُستخدم **معرفات Google التجريبية**. قبل النشر:
1. `lib/services/ad_service.dart` ← الصنف `AdIds` (banner, interstitial, rewarded, appOpen) — ضع معرفات EliteP.
2. `android/app/src/main/AndroidManifest.xml` ← `com.google.android.gms.ads.APPLICATION_ID` — ضع App ID الخاص بـ EliteP.
3. في AdMob ← Privacy & messaging: أنشئ رسالة GDPR (UMP مدمج ويُطلب قبل تحميل أي إعلان).

قواعد العرض (كلها في `AdService` + `AdPolicy`):
| النوع | متى |
|---|---|
| Banner | أسفل الشاشة الرئيسية وشاشة المجالات (المستويات) فقط — لا يظهر أثناء اللعب |
| Interstitial | بعد كل جولة كاملة (عند مغادرة شاشة النتيجة)، مع فاصل ≥ 120 ثانية بين أي إعلانين كاملين. عدّل `AdPolicy.roundsPerInterstitial` (مثلاً 3) لتغيير التكرار |
| Rewarded | باختيار اللاعب فقط: استرجاع وسيلة مساعدة، فرصة ثانية، مضاعفة العملات |
| App Open | عند العودة من الخلفية، بنفس فاصل 120 ثانية |
| الكل | لا إعلانات في أول 60 ثانية من أول تشغيل؛ المؤقت يتوقف أثناء أي إعلان كامل |

"إزالة الإعلانات" تلغي Banner/Interstitial/App Open فقط، وتبقى إعلانات Rewarded الاختيارية.

## الشراء داخل التطبيق
أنشئ منتجاً مُداراً (غير قابل للاستهلاك) بالمعرف `remove_ads` في Play Console (المعرف في `lib/services/iap_service.dart`).

## سياسة الخصوصية
ضع رابط EliteP في `lib/widgets/common.dart` ← `privacyPolicyUrl`، وأضفه أيضاً في Play Console.

## بناء AAB للنشر على Google Play
1. أنشئ مفتاح الرفع (مرة واحدة):
   ```bash
   keytool -genkey -v -keystore ~/elitep-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. أنشئ الملف `android/key.properties` (مُستثنى من git — لا ترفعه):
   ```properties
   storePassword=...
   keyPassword=...
   keyAlias=upload
   storeFile=/home/you/elitep-upload.jks
   ```
   `android/app/build.gradle.kts` يقرأه تلقائياً ويوقّع نسخة release به (وبدونه يستخدم مفتاح debug للتجربة فقط).
3. حدّث `version:` في `pubspec.yaml` (مثلاً `1.0.1+2`) ثم:
   ```bash
   flutter build appbundle --release
   ```
4. ارفع `build/app/outputs/bundle/release/app-release.aab` إلى Play Console.
5. في Play Console: فئة المحتوى (Trivia)، استبيان الإعلانات = "يحتوي على إعلانات"، نموذج أمان البيانات (AdMob يجمع معرف الإعلانات)، سياسة الخصوصية.

## الأصول المولَّدة
```bash
python3 tool/sounds/make_sounds.py   # الأصوات (مكتبة بايثون القياسية فقط)
python3 tool/icon/make_icon.py       # الأيقونات (يتطلب pillow)
```
