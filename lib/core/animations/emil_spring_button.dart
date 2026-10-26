import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tombol mikro-interaksi taktil ala Emil Kowalski:
/// Memberikan efek squish (scale 0.94) saat ditekan dan spring overshoot (1.03 -> 1.0) saat dilepas.
/// Menghormati pengaturan reduce motion milik sistem.
class EmilSpringButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressScale;
  final Duration duration;
  final bool enableHaptics;

  const EmilSpringButton({
    super.key,
    required this.child,
    required this.onTap,
    this.pressScale = 0.94,
    this.duration = const Duration(milliseconds: 180),
    this.enableHaptics = true,
  });

  @override
  State<EmilSpringButton> createState() => _EmilSpringButtonState();
}

class _EmilSpringButtonState extends State<EmilSpringButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: const Duration(milliseconds: 220),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.pressScale).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInQuad,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap == null) return;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reduceMotion) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap == null) return;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reduceMotion) {
      _controller.reverse();
    }
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    widget.onTap?.call();
  }

  void _onTapCancel() {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reduceMotion) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (reduceMotion) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (widget.enableHaptics) HapticFeedback.lightImpact();
          widget.onTap?.call();
        },
        child: widget.child,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            alignment: Alignment.center,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
