import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_colors.dart';

/// Soft animated blobs for splash & home backgrounds.
class FloatingOrbsBackground extends StatefulWidget {
  final List<Color>? colors;
  final bool vivid;

  const FloatingOrbsBackground({
    super.key,
    this.colors,
    this.vivid = false,
  });

  @override
  State<FloatingOrbsBackground> createState() => _FloatingOrbsBackgroundState();
}

class _FloatingOrbsBackgroundState extends State<FloatingOrbsBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.colors ??
        (widget.vivid
            ? AppColors.splashGradient
            : [
                AppColors.coral.withValues(alpha: 0.35),
                AppColors.sky.withValues(alpha: 0.3),
                AppColors.sunny.withValues(alpha: 0.28),
                AppColors.violet.withValues(alpha: 0.25),
              ]);
    final alpha = widget.vivid ? 0.55 : 0.45;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 2 * math.pi;
        return Stack(
          fit: StackFit.expand,
          children: [
            _Orb(
              color: palette[0 % palette.length],
              alpha: alpha,
              size: 220,
              top: 40 + math.sin(t) * 18,
              left: -40 + math.cos(t * 0.8) * 12,
            ),
            _Orb(
              color: palette[1 % palette.length],
              alpha: alpha,
              size: 180,
              top: 180 + math.cos(t * 1.1) * 22,
              right: -30 + math.sin(t * 0.7) * 10,
            ),
            _Orb(
              color: palette[2 % palette.length],
              alpha: alpha,
              size: 140,
              bottom: 120 + math.sin(t * 0.9) * 16,
              left: 40 + math.cos(t) * 14,
            ),
            if (palette.length > 3)
              _Orb(
                color: palette[3 % palette.length],
                alpha: alpha,
                size: 110,
                bottom: 40 + math.cos(t * 1.2) * 12,
                right: 30 + math.sin(t * 0.6) * 10,
              ),
          ],
        );
      },
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double alpha;
  final double size;
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;

  const _Orb({
    required this.color,
    required this.alpha,
    required this.size,
    this.top,
    this.left,
    this.right,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
