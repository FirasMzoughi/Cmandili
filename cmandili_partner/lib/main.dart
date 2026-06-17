import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/home/presentation/home_screen.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'core/providers/localization_provider.dart';
import 'core/providers/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'core/config/supabase_config.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/push/push_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // dotenv MUST resolve first — SupabaseConfig and the Mapbox token both
  // read from it. Then run Supabase + Firebase in parallel.
  await dotenv.load(fileName: '.env');

  MapboxOptions.setAccessToken(dotenv.env['MAPBOX_PUBLIC_TOKEN'] ?? '');

  await Future.wait([
    Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    ),
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
        .catchError((_) => Firebase.app()),
  ]);

  // MUST be registered before runApp(). Firebase spawns a separate Dart
  // isolate for background/terminated FCM messages and calls this handler
  // directly via the @pragma('vm:entry-point') annotation. If it is
  // registered after runApp() (e.g. in addPostFrameCallback), Android never
  // wires it up and data-only alarm messages are silently dropped.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: MyApp()));

  // Defer the rest of push init (token fetch + Supabase upsert + foreground
  // listener) off the critical path so it doesn't stall first frame.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    PushService.instance.initialize().catchError((_) {});
  });
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final locale = ref.watch(localizationProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Cmandili Partner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
        Locale('fr'),
      ],
      home: authState.when(
        data: (user) => user != null ? const HomeScreen() : const AuthScreen(),
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const AuthScreen(),
      ),
    );
  }
}
