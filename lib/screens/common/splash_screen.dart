import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/modern_theme.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../core/sacco_service.dart';
import '../auth/professional_login_screen.dart';
import '../admin/admin_dashboard.dart';
import '../farmer/farmer_dashboard.dart';

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

  void _navigate() async {
    if (!mounted) return;
    
    // Check if user is already authenticated
    try {
      print('🔍 Checking auth state...');
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        print('✅ User already authenticated: ${user.uid}');
        // User is logged in, navigate to appropriate dashboard
        final doc = await FirebaseFirestore.instance
            .collection('saccoplus-users')
            .doc(user.uid)
            .get();
            
        if (doc.exists) {
          final data = doc.data()!;
          final role = data['role'] as String?;
          
          print('✅ User role: $role');
          
          // Restore session in FirebaseService
          FirebaseService.setSession(user.uid, data);
          
          // Load tenant profile
          await SaccoService.loadForUser(data);
          
          if (!mounted) return;
          
          // Navigate based on role
          Widget destination;
          if (role == 'admin' || role == 'teller' || role == 'super_admin') {
            destination = const AdminDashboard();
          } else {
            destination = FarmerDashboard();
          }
          
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, a, __) => destination,
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 600),
            ),
          );
          return;
        }
      }
      
      print('❌ No authenticated user, showing login screen');
    } catch (e) {
      print('❌ Error checking auth state: $e');
    }
    
    // No valid session, go to login
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
          // Background image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/splash.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Premium gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0D2B6B).withOpacity(0.92),
                  const Color(0xFF1565C0).withOpacity(0.88),
                  ModernTheme.primaryBlue.withOpacity(0.90),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Decorative circles with blur
          Positioned(
            top: -80, right: -60,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.1),
                    blurRadius: 60,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 60, right: 20,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -100, left: -60,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.08),
                    blurRadius: 60,
                    spreadRadius: 20,
                  ),
                ],
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
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.04),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Logo - clean without glow
                Center(
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: ClipOval(
                      child: Image.asset(
                        AppConstants.logoPath,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                      .animate()
                      .scale(
                          begin: const Offset(0.5, 0.5),
                          duration: 600.ms,
                          curve: Curves.easeOut)
                      .fadeIn(duration: 400.ms),
                ),

                const SizedBox(height: 40),

                Text(
                  AppConstants.appName,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                      Shadow(
                        color: ModernTheme.accent.withOpacity(0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 600.ms)
                    .slideY(begin: 0.3, end: 0, curve: Curves.easeOut),

                const SizedBox(height: 8),

                Text(
                  AppConstants.appTagline,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                    height: 1.4,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                )
                    .animate()
                    .fadeIn(delay: 600.ms, duration: 600.ms)
                    .slideY(begin: 0.2, end: 0),

                const SizedBox(height: 20),

                Container(
                  width: 60, height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        ModernTheme.accent,
                        ModernTheme.accent,
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: ModernTheme.accent.withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 700.ms, duration: 400.ms)
                    .scaleX(begin: 0, end: 1, curve: Curves.easeOut),

                const Spacer(flex: 2),

                // Starting text
                Text(
                  'Starting MBADIFA SACCO',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 750.ms, duration: 500.ms),

                const SizedBox(height: 12),

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
                      'assets/images/logo2.png',
                      width: 32,
                      height: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'SACCO PLUS',
                      style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SACCO PLUS is a product of',
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
