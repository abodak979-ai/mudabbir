# مُدبِّر — Mudabbir

تطبيق جوال (Android و iOS) يقسّم الراتب يوم نزوله إلى: التزامات ثابتة، ادخار، استثمار، وميزانية صرف — ويعرض **كم تقدر تصرف اليوم**.

Flutter + Supabase. Offline-first: كل شيء يُحفظ على الجهاز أولاً (SQLite) ثم يتزامن.

## ما تم بناؤه (MVP)

| PRD | الحالة |
|---|---|
| US-01 إعداد الراتب ويوم نزوله، قوالب 50/30/20 · 70/20/10 · 40/30/30 · مخصص | ✅ `lib/ui/onboarding.dart` (5 شاشات) |
| US-02 الالتزامات الثابتة + تحذير > 50% واقتراح 70/20/10 | ✅ |
| US-03 الادخار والاستثمار بنسبة أو مبلغ، منع تجاوز الراتب | ✅ `lib/ui/plan_editor.dart` |
| US-04 الحد اليومي يُعاد حسابه بعد كل مصروف وبداية كل يوم | ✅ `lib/core/budget_math.dart` |
| US-05 تسجيل مصروف بـ 3 ضغطات، يعمل دون إنترنت | ✅ `lib/ui/add_expense.dart` + `lib/data/sync.dart` |
| US-06 تنبيه 80% و100% لكل فئة وللحد اليومي، قابل للإيقاف | ✅ |
| US-07 أهداف ادخار بتاريخ، المبلغ الشهري، تنبيه التأخر، صندوق الطوارئ | ✅ `lib/ui/goals_screen.dart` |
| US-08 تذكير قبل 3 أيام ويوم الاستحقاق + «تم الدفع» | ✅ إشعارات محلية |
| US-09 ملخص الدورة: المخطط مقابل الفعلي، فائض/عجز، رسوم دائرية وخطية | ✅ `lib/ui/reports_screen.dart` |
| US-10 قفل بالبصمة/الوجه/PIN، إخفاء الأرقام، إخفاء المحتوى في التطبيقات المفتوحة | ✅ |
| العربية RTL + الإنجليزية، أرقام عربية/هندية، هجري + ميلادي، وضع ليلي | ✅ |
| دخل إضافي يُوزع بنفس النسب / للادخار / للصرف | ✅ |
| حذف الحساب من داخل التطبيق (PDPL) | ✅ `delete_my_account()` |

## Supabase

المشروع: `app` (`vjagryktdtdbsazucuqm`). الجداول: `profiles`, `budget_plans`, `incomes`, `fixed_obligations`, `categories`, `expenses`, `savings_goals`, `investments` — كلها بـ RLS (كل مستخدم يرى صفوفه فقط)، وحاوية تخزين خاصة `receipts`.

السكيمة محفوظة في `supabase/migrations/`.

### خطوات مطلوبة منك في لوحة Supabase

1. **رمز الدخول بالبريد**: Authentication → Email Templates → Magic Link: أضف `{{ .Token }}` في نص الرسالة ليصل رمز من 6 أرقام بدل الرابط.
2. **الدخول برقم الجوال**: Authentication → Providers → Phone: فعّله واربط مزود SMS (Twilio / MessageBird / Vonage …). بدونه يعمل الدخول بالبريد فقط.
3. **منطقة الاستضافة**: المشروع الحالي في طوكيو (ap-northeast-1). نظام PDPL يتطلب الاستضافة داخل المملكة أو موافقة صريحة — راجع هذا قبل الإطلاق.

## البناء على Codemagic

`codemagic.yaml` فيه ثلاث workflows:

- **android-debug**: analyze + tests + APK تثبّته مباشرة. يعمل بدون أي إعداد.
- **ios-simulator**: يتأكد أن نسخة iOS تُبنى (بدون توقيع).
- **release**: AAB + IPA ورفع إلى TestFlight عند tag يبدأ بـ `v`. يحتاج:
  - رفع keystore في Codemagic باسم `mudabbir_keystore`
  - ربط App Store Connect باسم `mudabbir_asc` وتسجيل bundle id `com.mudabbir.mudabbir`

## التشغيل محلياً

```bash
flutter pub get
flutter test
flutter run
```

## لاحقاً (الإصدار 2 حسب PRD)

قراءة SMS، OCR للإيصال، ترحيل الفائض، المحفظة الاستثمارية (الجدول `investments` جاهز)، الودجت، الزكاة، Google/Apple Sign-in، باقة بريميوم عبر RevenueCat.
