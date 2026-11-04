import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'data/local_db.dart';
import 'services/notifications.dart';
import 'state/app_state.dart';
import 'ui/auth_screen.dart';
import 'ui/onboarding.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  await initializeDateFormatting('en');
  // Digits follow the user's numerals setting, not the locale default.
  DateFormat.useNativeDigitsByDefaultFor('ar', false);
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
  await Notifications.init();
  final state = AppState(await LocalDb.open(), await SharedPreferences.getInstance());
  await state.init();
  runApp(AppScope(state: state, child: const MudabbirApp()));
}

class MudabbirApp extends StatelessWidget {
  const MudabbirApp({super.key});

  ThemeData _theme(Brightness b) => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F7A63), brightness: b),
        useMaterial3: true,
        cardTheme: const CardThemeData(elevation: 0),
      );

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return MaterialApp(
      title: 'Mudabbir',
      debugShowCheckedModeBanner: false,
      locale: Locale(app.language),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: !app.loaded
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : !app.signedIn
              ? const AuthScreen()
              : app.profile == null
                  ? const Scaffold(body: Center(child: CircularProgressIndicator()))
                  : !app.profile!.onboarded
                      ? const Onboarding()
                      : const Shell(),
    );
  }
}
