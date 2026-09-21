import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/modern_theme.dart';
import '../../core/constants.dart';
import '../auth/professional_login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _dotsCtrl;
  late AnimationController _progressCtrl;

  @override
  void initState() {
    super.initState();

    _dotsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    // Progress bar fills over exactly 8 seconds
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..forward().whenComplete(_navigate);
  }

  void _navigate() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => const ProfessionalLoginScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _dotsCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Modern gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ModernTheme.primaryBlue,
                  ModernTheme.primaryBlueLight,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Decorative circles
          Positioned(
            top: -80, right: -60,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            top: 60, right: 20,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -100, left: -60,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),

          // Wave bottom decoration
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: ClipPath(
              clipper: _WaveClipper(),
              child: Container(
                height: 180,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Logo
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 148, height: 148,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.06),
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(
                              begin: const Offset(1, 1),
                              end: const Offset(1.08, 1.08),
                              duration: 1800.ms,
                              curve: Curves.easeInOut),
                      Container(
                        width: 124, height: 124,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.08),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.2), width: 1.5),
                        ),
                      ),
                      Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.4), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: ModernTheme.accent.withOpacity(0.3),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            AppConstants.logoPath,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                          .animate()
                          .scale(
                              begin: const Offset(0.3, 0.3),
                              duration: 800.ms,
                              curve: Curves.elasticOut)
                          .fadeIn(duration: 500.ms),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                Text(
                  AppConstants.appName,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 600.ms)
                    .slideY(begin: 0.3, end: 0, curve: Curves.easeOut),

                const SizedBox(height: 6),

                Text(
                  AppConstants.appTagline,
                  style: GoogleFonts.poppins(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                )
                    .animate()
                    .fadeIn(delay: 600.ms, duration: 600.ms)
                    .slideY(begin: 0.2, end: 0),

                const SizedBox(height: 16),

                Container(
                  width: 48, height: 3,
                  decoration: BoxDecoration(
                    color: ModernTheme.accent,  // orange brand line
                    borderRadius: BorderRadius.circular(2),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 700.ms, duration: 400.ms)
                    .scaleX(begin: 0, end: 1, curve: Curves.easeOut),

                const Spacer(flex: 2),

                // Animated dots
                _DotsLoader(controller: _dotsCtrl)
                    .animate()
                    .fadeIn(delay: 800.ms, duration: 500.ms),

                const SizedBox(height: 10),

                // Progress bar (fills over 5s)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60),
                  child: AnimatedBuilder(
                    animation: _progressCtrl,
                    builder: (_, __) => ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progressCtrl.value,
                        backgroundColor: Colors.white12,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(ModernTheme.accent),
                        minHeight: 2,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 850.ms, duration: 400.ms),

                const SizedBox(height: 24),

                // Company branding footer
                Column(
                  children: [
                    Image.asset(
                      AppConstants.logoPath,
                      width: 28,
                      height: 28,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'A product of',
                      style: GoogleFonts.poppins(
                          color: Colors.white30, fontSize: 10),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppConstants.companyName,
                      style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${AppConstants.companyCity}  •  ${AppConstants.companyWebsite}',
                      style: GoogleFonts.poppins(
                          color: Colors.white38, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 900.ms, duration: 500.ms),

                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Animated Dots Loader ─────────────────────────────────────────────────────
class _DotsLoader extends StatelessWidget {
  final AnimationController controller;
  const _DotsLoader({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (i) {
            final phase = (controller.value - i * 0.25) % 1.0;
            final t = sin(phase * pi).clamp(0.0, 1.0);
            final size = 7.0 + t * 6.0;
            final opacity = 0.35 + t * 0.65;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ModernTheme.accent.withOpacity(opacity),
                  boxShadow: t > 0.5
                      ? [
                          BoxShadow(
                            color: ModernTheme.accent.withOpacity(0.4 * t),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─── Wave Clipper ─────────────────────────────────────────────────────────────
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, size.height * 0.5);
    path.quadraticBezierTo(
        size.width * 0.25, size.height * 0.2,
        size.width * 0.5, size.height * 0.45);
    path.quadraticBezierTo(
        size.width * 0.75, size.height * 0.7,
        size.width, size.height * 0.4);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_WaveClipper old) => false;
}
