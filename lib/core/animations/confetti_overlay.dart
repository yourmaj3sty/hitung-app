import 'dart:math';
import 'package:flutter/material.dart';

/// Konfeti ringan untuk selebrasi target tabungan tercapai.
/// Menggunakan palet brand Hitung (Lime, Ungu, Pink, Cyan).
/// Berjalan pada 60 fps di atas CustomPainter tanpa lag.
class ConfettiOverlay {
  static void show(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return;

    final overlayState = Overlay.maybeOf(context);
    if (overlayState == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ConfettiWidget(
        onFinished: () {
          if (entry.mounted) {
            entry.remove();
          }
        },
      ),
    );

    overlayState.insert(entry);
  }
}

class _ConfettiWidget extends StatefulWidget {
  final VoidCallback onFinished;

  const _ConfettiWidget({required this.onFinished});

  @override
  State<_ConfettiWidget> createState() => _ConfettiWidgetState();
}

class _ConfettiWidgetState extends State<_ConfettiWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_ConfettiParticle> _particles = [];
  final Random _random = Random();

  static const List<Color> _brandColors = [
    Color(0xFFC8F031), // Lime
    Color(0xFF6D28D9), // Ungu
    Color(0xFFFF6FA8), // Pink
    Color(0xFF00AED6), // GoPay Cyan
    Color(0xFF00AA13), // Gojek Green
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Generate 45 lightweight particles
    for (int i = 0; i < 45; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 150 + _random.nextDouble() * 320;
      _particles.add(
        _ConfettiParticle(
          dx: cos(angle) * speed,
          dy: sin(angle) * speed - 120, // initial upward burst
          rotation: _random.nextDouble() * 2 * pi,
          rotationSpeed: (_random.nextDouble() - 0.5) * 8,
          color: _brandColors[_random.nextInt(_brandColors.length)],
          size: 6 + _random.nextDouble() * 6,
          isCircle: _random.nextBool(),
        ),
      );
    }

    _controller.forward().then((_) {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          final opacity = (1.0 - progress * 0.9).clamp(0.0, 1.0);

          return Opacity(
            opacity: opacity,
            child: CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _ConfettiPainter(
                particles: _particles,
                progress: progress,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ConfettiParticle {
  final double dx;
  final double dy;
  final double rotation;
  final double rotationSpeed;
  final Color color;
  final double size;
  final bool isCircle;

  _ConfettiParticle({
    required this.dx,
    required this.dy,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
    required this.size,
    required this.isCircle,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);

    for (final p in particles) {
      final x = center.dx + p.dx * progress;
      // Gravity acceleration curve
      final y = center.dy + p.dy * progress + (450 * progress * progress);
      final rot = p.rotation + p.rotationSpeed * progress;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);

      final paint = Paint()
        ..color = p.color
        ..style = PaintingStyle.fill;

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.7),
          paint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
