import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/auth_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      final user = ref.read(authStateProvider).valueOrNull;
      context.go(user != null ? '/home' : '/login');
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E1A), Color(0xFF0D1830), Color(0xFF0A0E1A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Decorative background circles
            Positioned(
              top: -80, right: -80,
              child: Container(
                width: 260, height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.teal.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -100, left: -60,
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.purple.withOpacity(0.07),
                ),
              ),
            ),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo icon with glow
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, __) => Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.bg2,
                        border: Border.all(
                          color: AppColors.teal.withOpacity(
                              0.4 + _pulseController.value * 0.4),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.teal.withOpacity(
                                0.15 + _pulseController.value * 0.2),
                            blurRadius: 30 + _pulseController.value * 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('🏟', style: TextStyle(fontSize: 52)),
                      ),
                    ),
                  )
                      .animate()
                      .scale(
                        duration: 700.ms,
                        curve: Curves.elasticOut,
                        begin: const Offset(0.3, 0.3),
                      ),

                  const SizedBox(height: 28),

                  // App name
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [AppColors.teal, AppColors.gold],
                    ).createShader(bounds),
                    child: const Text(
                      'ARENA GAMES',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 5,
                      ),
                    ),
                  ).animate().fadeIn(delay: 500.ms, duration: 600.ms),

                  const SizedBox(height: 8),

                  const Text(
                    'Play · Win · Earn',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      letterSpacing: 3,
                    ),
                  ).animate().fadeIn(delay: 700.ms, duration: 600.ms),

                  const SizedBox(height: 60),

                  // Game icons row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _gameIcon('♟', AppColors.purple, 'Chess'),
                      const SizedBox(width: 24),
                      _gameIcon('🃏', AppColors.teal, 'Whot'),
                      const SizedBox(width: 24),
                      _gameIcon('🎲', AppColors.textMuted, 'Ludo'),
                    ],
                  ).animate().fadeIn(delay: 900.ms, duration: 500.ms),

                  const SizedBox(height: 60),

                  // Loading dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.teal,
                      ),
                    ).animate(
                      onPlay: (c) => c.repeat(),
                    ).fadeIn(
                      delay: Duration(milliseconds: 1000 + i * 180),
                    ).then().fadeOut(
                      duration: 500.ms,
                    ).then().fadeIn(duration: 500.ms)),
                  ),
                ],
              ),
            ),

            // Version tag
            const Positioned(
              bottom: 24,
              left: 0, right: 0,
              child: Text(
                'v1.0.0',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ).animate().fadeIn(delay: 1200.ms),
          ],
        ),
      ),
    );
  }

  Widget _gameIcon(String emoji, Color color, String label) {
    return Column(
      children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 26)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(
            color: color.withOpacity(0.7), fontSize: 10, letterSpacing: 1)),
      ],
    );
  }
}