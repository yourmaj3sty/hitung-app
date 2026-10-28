import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hitung/core/providers/database_provider.dart';
import 'package:hitung/core/database/app_database.dart';
import 'package:hitung/features/onboarding/providers/onboarding_provider.dart';
import 'package:drift/native.dart';
import 'package:hitung/features/dashboard/presentation/dashboard_screen.dart';
import 'package:hitung/features/splash/presentation/splash_screen.dart';
import 'package:hitung/features/splash/presentation/widgets/hitung_splash_animated_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('HitungSplashAnimatedLogo Tests', () {
    testWidgets('Merender HitungSplashAnimatedLogo di berbagai titik waktu progress tanpa error', (tester) async {
      final progressPoints = [0.0, 0.15, 0.35, 0.44, 0.50, 0.70, 0.85, 1.0];

      for (final p in progressPoints) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: HitungSplashAnimatedLogo(
                  size: 112,
                  progress: p,
                  reduceMotion: false,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(HitungSplashAnimatedLogo), findsOneWidget);
      }
    });

    testWidgets('Merender HitungSplashAnimatedLogo dalam mode reduceMotion secara statis', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: HitungSplashAnimatedLogo(
                size: 112,
                progress: 0.5,
                reduceMotion: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(HitungSplashAnimatedLogo), findsOneWidget);
    });
  });

  group('SplashScreen Animation & Transition Tests', () {
    testWidgets('SplashScreen menyelesaikan animasi dan memanggil onCompleted', (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            onCompleted: () {
              completed = true;
            },
          ),
        ),
      );

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(completed, isFalse);

      // Pompa waktu hingga melewati 1350ms
      await tester.pump(const Duration(milliseconds: 500));
      expect(completed, isFalse);

      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
    });

    testWidgets('SplashScreen dalam mode reduceMotion selesai lebih cepat', (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: SplashScreen(
              onCompleted: () {
                completed = true;
              },
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
    });
  });

  group('DashboardScreen Entrance Animation Tests', () {
    testWidgets('DashboardScreen memulai animasi masuk dan menetap di layar', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      expect(find.byType(DashboardScreen), findsOneWidget);

      // Pompa frame animasi masuk
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(DashboardScreen), findsOneWidget);

      await db.close();
    });
  });
}
