import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/providers/database_provider.dart';
import 'core/constants/app_constants.dart';
import 'core/services/notification_service.dart';
import 'core/services/privacy_guard.dart';
import 'features/backup_restore/services/json_backup_service.dart';
import 'core/theme/app_theme.dart';
import 'features/navigation/main_nav_screen.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/onboarding/providers/onboarding_provider.dart';
import 'features/settings/presentation/biometric_lock_screen.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'shared/widgets/app_logo.dart';

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
  bool _isPrivacyShieldActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initial check: if biometric or PIN lock is enabled on startup, lock the app immediately
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final isBioEnabled = ref.read(isBiometricEnabledProvider);
      final isPinEnabled = ref.read(isPinEnabledProvider);
      final isOnboarded = ref.read(isOnboardedProvider);
      if ((isBioEnabled || isPinEnabled) && isOnboarded) {
        ref.read(isAppLockedProvider.notifier).state = true;
      }

      await _runStartupTasks();
    });
  }

  /// Tugas latar saat aplikasi dibuka. Setiap langkah berdiri sendiri: kegagalan satu
  /// langkah tidak boleh menghentikan langkah lain atau menampilkan error ke pengguna.
  Future<void> _runStartupTasks() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await PrivacyGuard.setSecure(ref.read(isPrivacyScreenEnabledProvider));

    try {
      await NotificationService().init();
      await NotificationService().rescheduleDailyReminderIfEnabled(
        enabled: prefs.getBool(AppConstants.prefDailyReminderEnabled) ?? false,
        hour: prefs.getInt(AppConstants.prefDailyReminderHour) ?? 20,
        minute: prefs.getInt(AppConstants.prefDailyReminderMinute) ?? 0,
      );
    } catch (_) {}

    if (!ref.read(isOnboardedProvider)) return;
    final db = ref.read(databaseProvider);
    try {
      await db.processDueRecurringTransactions();
    } catch (_) {}
    try {
      await JsonBackupService(db).runScheduledAutoBackup(prefs);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // FR-08 & Feature 9: Kunci aplikasi saat diminimalkan & Privacy Screen saat di App Switcher
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final privacyEnabled = ref.read(isPrivacyScreenEnabledProvider);

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (privacyEnabled && !_isPrivacyShieldActive) {
        setState(() => _isPrivacyShieldActive = true);
      }
      if (state == AppLifecycleState.paused) {
        _pausedTime = DateTime.now();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isPrivacyShieldActive) {
        setState(() => _isPrivacyShieldActive = false);
      }

      final isAuthenticating = ref.read(isAuthenticatingProvider);
      if (isAuthenticating) {
        return;
      }

      if (_pausedTime != null) {
        final elapsed = DateTime.now().difference(_pausedTime!);
        _pausedTime = null;
        if (elapsed.inMilliseconds >= 800) {
          final isBioEnabled = ref.read(isBiometricEnabledProvider);
          final isPinEnabled = ref.read(isPinEnabledProvider);
          final isOnboarded = ref.read(isOnboardedProvider);
          if ((isBioEnabled || isPinEnabled) && isOnboarded) {
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
      darkTheme: AppTheme.darkTheme,
      // Dikunci ke mode terang sampai semua layar memakai warna dari tema (lihat settings_screen).
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
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            // Privacy Shield Overlay (Feature 9)
            if (_isPrivacyShieldActive)
              const Positioned.fill(
                child: Material(
                  color: Color(0xFF0F172A),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppLogo(size: 72, showText: true),
                        SizedBox(height: 16),
                        Text(
                          'Data Keuangan Terlindungi',
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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
