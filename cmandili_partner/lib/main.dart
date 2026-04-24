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
import 'core/config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
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
