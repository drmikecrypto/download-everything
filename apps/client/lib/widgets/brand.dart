import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.25),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accent, AppColors.success],
        ),
      ),
      child: Icon(Icons.download_rounded, color: Colors.white, size: size * 0.55),
    );
  }
}

class TypeBadge extends StatelessWidget {
  const TypeBadge({super.key, required this.label, required this.kind});

  final String label;
  final String kind;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (kind) {
      case 'video':
        bg = AppColors.accent.withValues(alpha: 0.2);
        fg = const Color(0xFFA29BFE);
      case 'audio':
        bg = AppColors.success.withValues(alpha: 0.15);
        fg = AppColors.success;
      default:
        bg = AppColors.surface2;
        fg = AppColors.muted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: fg,
        ),
      ),
    );
  }
}

class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.8, -0.9),
          radius: 1.2,
          colors: [Color(0x221A1530), Colors.transparent],
        ),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(1.1, 1.0),
            radius: 0.9,
            colors: [Color(0x1800D2A0), Colors.transparent],
          ),
        ),
        child: child,
      ),
    );
  }
}
