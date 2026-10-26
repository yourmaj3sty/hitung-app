import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/hitung_logo_widget.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback? onCompleted;

  const SplashScreen({super.key, this.onCompleted});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _textController;
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _textSlideAnimation;
  Timer? _textTimer;
  Timer? _completeTimer;
  bool _timersInitialized = false;

  @override
  void initState() {
    super.initState();
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _textFadeAnimation = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeIn,
    );

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_timersInitialized) {
      _timersInitialized = true;
      final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

      if (reduceMotion) {
        _completeTimer = Timer(const Duration(milliseconds: 350), () {
          if (mounted) widget.onCompleted?.call();
        });
      } else {
        // Munculkan teks setelah animasi pantulan titik logo (frame ~35 atau 550ms)
        _textTimer = Timer(const Duration(milliseconds: 550), () {
          if (mounted) {
            _textController.forward();
          }
        });

        // Durasi total splash 1.35 detik (maksimal 1.5 detik)
        _completeTimer = Timer(const Duration(milliseconds: 1350), () {
          if (mounted) {
            widget.onCompleted?.call();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _textTimer?.cancel();
    _completeTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Deep matte navy background
      body: Stack(
        children: [
          // Background subtle ambient glow
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.neonLime.withOpacity(0.06),
              ),
            ),
          ),

          // Central Lottie Logo and Wordmark
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Lottie Animation: Titik ungu memantul sebentar di atas logo "h"
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Lottie.asset(
                    'assets/lottie/splash_logo.json',
                    repeat: false,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback bila asset lottie belum termuat
                      return const HitungLogoWidget(
                        size: 96,
                        showText: false,
                        variant: HitungLogoVariant.lime,
                        animate: true,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Wordmark: 'hitung.' dan Tagline
                FadeTransition(
                  opacity: reduceMotion ? const AlwaysStoppedAnimation(1.0) : _textFadeAnimation,
                  child: SlideTransition(
                    position: reduceMotion ? const AlwaysStoppedAnimation(Offset.zero) : _textSlideAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              'hitung',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                color: Colors.white,
                              ),
                            ),
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 4),
                              decoration: BoxDecoration(
                                color: AppColors.brandPurple,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'catat duit, tanpa ribet',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white60,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Footer version tag
          Positioned(
            bottom: 28,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'v2.0 • gen z edition',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white30,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
