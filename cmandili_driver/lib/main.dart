import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/profile/presentation/vehicle_info_screen.dart';
import 'core/services/background_location_service.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'core/providers/localization_provider.dart';
import 'core/providers/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/config/supabase_config.dart';
import 'core/push/push_service.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // dotenv MUST resolve first — SupabaseConfig and the Mapbox token both
  // read from it. Then run the remaining independent cold-start work in
  // parallel (Firebase init + SharedPreferences load + Supabase bootstrap).
  await dotenv.load(fileName: '.env');

  MapboxOptions.setAccessToken(dotenv.env['MAPBOX_PUBLIC_TOKEN'] ?? '');

  late SharedPreferences prefs;
  await Future.wait([
    Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    ),
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
        .catchError((_) => Firebase.app()),
    SharedPreferences.getInstance().then((p) => prefs = p),
  ]);

  // Persist Supabase credentials so the background isolate can initialize.
  // Fire-and-forget — these reads happen later from a different isolate.
  unawaited(prefs.setString('supabase_url', SupabaseConfig.url));
  unawaited(prefs.setString('supabase_anon_key', SupabaseConfig.anonKey));

  runApp(const ProviderScope(child: MyApp()));

  // Defer push registration AND background-location config off the critical
  // path — both touch native plugins / network and aren't needed for the
  // first frame.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    PushService.instance.initialize().catchError((_) {});
    BackgroundLocationService.initialize().catchError((_) {});
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
      title: 'Cmandili Driver',
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
        Locale('en'), // English
        Locale('ar'), // Arabic
        Locale('fr'), // French
      ],
      home: authState.when(
        data: (user) {
          if (user != null) {
            return const _PostAuthGate();
          }
          return const AuthScreen();
        },
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, stack) => const AuthScreen(),
      ),
    );
  }
}

/// After sign-in, require the driver to complete vehicle registration
/// before reaching the main app. Reads drivers.vehicle_type; if null/empty,
/// forces VehicleInfoScreen. Saving there pops back here and re-checks.
class _PostAuthGate extends StatefulWidget {
  const _PostAuthGate();

  @override
  State<_PostAuthGate> createState() => _PostAuthGateState();
}

class _PostAuthGateState extends State<_PostAuthGate> {
  Future<bool>? _vehicleReady;

  @override
  void initState() {
    super.initState();
    _vehicleReady = _checkVehicle();
  }

  void _recheck() {
    if (!mounted) return;
    setState(() {
      _vehicleReady = _checkVehicle();
    });
  }

  Future<bool> _checkVehicle() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      final row = await Supabase.instance.client
          .from('drivers')
          .select('vehicle_type')
          .eq('user_id', userId)
          .maybeSingle();
      final type = row?['vehicle_type'] as String?;
      return type != null && type.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _vehicleReady,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) {
          return const HomeScreen();
        }
        return PopScope(
          canPop: false,
          child: Navigator(
            observers: [_GatePopObserver(onPop: _recheck)],
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => VehicleInfoScreen(onSaved: _recheck),
            ),
          ),
        );
      },
    );
  }
}

class _GatePopObserver extends NavigatorObserver {
  final VoidCallback onPop;
  _GatePopObserver({required this.onPop});

  @override
  void didPop(Route route, Route? previousRoute) {
    onPop();
    super.didPop(route, previousRoute);
  }
}
