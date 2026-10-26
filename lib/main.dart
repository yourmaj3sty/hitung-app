import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'features/navigation/main_nav_screen.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/onboarding/providers/onboarding_provider.dart';
import 'features/settings/presentation/biometric_lock_screen.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/splash/presentation/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Aplikasi 100% offline: font Plus Jakarta Sans dibundel di assets/google_fonts/,
  // jadi google_fonts tidak boleh mencoba mengunduh dari internet.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Plus Jakarta Sans'], license);
  });

  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const HitungApp(),
    ),
  );
}

class HitungApp extends ConsumerStatefulWidget {
  const HitungApp({super.key});

  @override
  ConsumerState<HitungApp> createState() => _HitungAppState();
}

class _HitungAppState extends ConsumerState<HitungApp> with WidgetsBindingObserver {
  DateTime? _pausedTime;
  bool _splashCompleted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initial check: if biometric lock is enabled on startup, lock the app immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isBioEnabled = ref.read(isBiometricEnabledProvider);
      final isOnboarded = ref.read(isOnboardedProvider);
      if (isBioEnabled && isOnboarded) {
        ref.read(isAppLockedProvider.notifier).state = true;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // FR-08: Kunci aplikasi saat benar-benar diminimalkan ke background, tanpa relock loop saat dialog sidik jari terbuka
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final isAuthenticating = ref.read(isAuthenticatingProvider);
      if (isAuthenticating) {
        // Abaikan event resumed yang berasal dari penutupan BiometricPrompt dialog
        return;
      }

      if (_pausedTime != null) {
        final elapsed = DateTime.now().difference(_pausedTime!);
        _pausedTime = null;
        if (elapsed.inMilliseconds >= 800) {
          final isBioEnabled = ref.read(isBiometricEnabledProvider);
          final isOnboarded = ref.read(isOnboardedProvider);
          if (isBioEnabled && isOnboarded) {
            ref.read(isAppLockedProvider.notifier).state = true;
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnboarded = ref.watch(isOnboardedProvider);
    final isLocked = ref.watch(isAppLockedProvider);

    return MaterialApp(
      title: 'HITUNG',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      // Fullscreen Splash Screen saat awal buka aplikasi
      home: !_splashCompleted
          ? SplashScreen(
              onCompleted: () {
                setState(() {
                  _splashCompleted = true;
                });
              },
            )
          : (isLocked
              ? const BiometricLockScreen()
              : (isOnboarded ? const MainNavScreen() : const OnboardingScreen())),
    );
  }
}
