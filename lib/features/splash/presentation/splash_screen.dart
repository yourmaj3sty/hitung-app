import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import 'widgets/hitung_splash_animated_logo.dart';

/// SplashScreen - Layar pembuka aplikasi "HITUNG" saat fresh start.
///
/// Fitur Animasi:
/// 1. Ambient Glow: Aura bernafas dengan gradien neon lime & purple.
/// 2. HitungSplashAnimatedLogo: Squircle base spring pop, tiang 'h' minimalis,
///    pantulan titik ungu taktil dengan squash-and-stretch dan purple shockwave ripple ring.
/// 3. Wordmark & Tagline: Muncul halus bertingkat (staggered fade + slide up).
/// 4. Shimmer Sheen: Kilauan cahaya melintas lembut di atas logo.
/// 5. Transisi Keluar: Transisi zoom & fade halus sebelum berpindah ke Beranda.
/// 6. Menghormati pengaturan reduce motion sistem secara penuh.
class SplashScreen extends StatefulWidget {
  final VoidCallback? onCompleted;

  const SplashScreen({super.key, this.onCompleted});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _exitFadeAnimation;
  late Animation<double> _exitScaleAnimation;

  bool _hasTriggeredHaptic = false;
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    );

    // Animasi kemunculan teks 'hitung.' dan tagline
    _textFadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.48, 0.76, curve: Curves.easeOut),
    );

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.48, 0.76, curve: Curves.easeOutCubic),
    ));

    // Animasi keluar menuju Beranda
    _exitFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.85, 1.0, curve: Curves.easeInCubic),
      ),
    );

    _exitScaleAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.85, 1.0, curve: Curves.easeInCubic),
      ),
    );

    _controller.addListener(_onAnimationTick);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          widget.onCompleted?.call();
        }
      }
    });
  }

  void _onAnimationTick() {
    // Picu haptic feedback saat titik ungu pertama kali mendarat (progress ~0.44)
    if (!_hasTriggeredHaptic && _controller.value >= 0.44) {
      _hasTriggeredHaptic = true;
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      _isInit = true;
      final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (reduceMotion) {
        _controller.duration = const Duration(milliseconds: 350);
        _controller.forward();
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onAnimationTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final exitOpacity = reduceMotion ? 1.0 : _exitFadeAnimation.value;
        final exitScale = reduceMotion ? 1.0 : _exitScaleAnimation.value;

        return Theme(
          data: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF0F172A),
          ),
          child: Scaffold(
            backgroundColor: const Color(0xFF0F172A).withOpacity(exitOpacity),
            body: Opacity(
              opacity: exitOpacity,
              child: Transform.scale(
                scale: exitScale,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. Ambient Dynamic Glow Aura di latar belakang
                    _buildAmbientGlow(reduceMotion),

                    // 2. Konten Utama: Animated Logo + Wordmark
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Animasi Logo (Squircle + Huruf h + Pantulan Titik Ungu + Shimmer)
                          HitungSplashAnimatedLogo(
                            size: 112,
                            progress: _controller.value,
                            reduceMotion: reduceMotion,
                          ),
                          const SizedBox(height: 22),

                          // Wordmark 'hitung.' & Tagline (Putih Kontras Tinggi & Anti-Nyaru)
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
                                      const Text(
                                        'hitung',
                                        style: TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 38,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -1.0,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Container(
                                        width: 9,
                                        height: 9,
                                        margin: const EdgeInsets.only(left: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.brandPurple,
                                          borderRadius: BorderRadius.circular(2.5),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.brandPurple.withOpacity(0.8),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'catat duit, tanpa ribet',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      color: Colors.white.withOpacity(0.88),
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

                    // 3. Footer Version Tag (Aksen Neon Lime Kontras)
                    Positioned(
                      bottom: 30,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          'v2.0 • gen z edition',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            color: AppColors.neonLime.withOpacity(0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAmbientGlow(bool reduceMotion) {
    final progress = _controller.value;
    final pulseScale = reduceMotion ? 1.0 : 0.92 + 0.16 * math.sin(progress * math.pi);

    return Center(
      child: Transform.scale(
        scale: pulseScale,
        child: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.neonLime.withOpacity(0.12),
                AppColors.brandPurple.withOpacity(0.06),
                Colors.transparent,
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}
