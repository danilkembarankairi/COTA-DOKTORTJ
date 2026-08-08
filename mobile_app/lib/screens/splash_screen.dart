import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/storage_service.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _controller.forward();
    _route();
  }

  Future<void> _route() async {
    // ✅ UPGRADE: Splash 2,5 detik (sebelumnya 1,5)
    await Future.delayed(
      const Duration(milliseconds: 2500),
    );

    if (!mounted) return;

    final authService = Provider.of<AuthService>(
      context,
      listen: false,
    );

    // Tetap restore session biar user object siap kalau auto-login
    await authService.restoreSession();

    if (!mounted) return;

    // ✅ FIX UTAMA: Routing berdasarkan "Ingat saya", BUKAN isLoggedIn
    // Token selalu ada (biar request HTTP jalan), tapi auto-login hanya
    // kalau user centang "Ingat saya".
    final rememberMe = await StorageService.getRememberMe();
    final token = await StorageService.getToken();
    final goDashboard = rememberMe && token != null && token.isNotEmpty;

    debugPrint(
      '🚦 [SPLASH] rememberMe=$rememberMe, token=${token != null} → '
      '${goDashboard ? "DASHBOARD" : "LOGIN"}',
    );

    final Widget destination =
        goDashboard ? const DashboardScreen() : const LoginScreen();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => destination,
      ),
      (route) => false,
    );
  }

  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF064E3B),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF064E3B),
              Color(0xFF047857),
              Color(0xFF059669),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Dekorasi kanan atas
            Positioned(
              top: -120,
              right: -160,
              child: IgnorePointer(
                child: Transform.rotate(
                  angle: -0.35,
                  child: Container(
                    width: 420,
                    height: 240,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
            ),

            // Dekorasi kiri bawah
            Positioned(
              bottom: -80,
              left: -100,
              child: IgnorePointer(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo tanpa ring dan background
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: Transform.scale(
                            scale: 1.45,
                            alignment: Alignment.center,
                            child: Image.asset(
                              'assets/logo_cota.png',
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              filterQuality: FilterQuality.high,
                              gaplessPlayback: true,
                              errorBuilder: (
                                context,
                                error,
                                stackTrace,
                              ) {
                                return const Center(
                                  child: Icon(
                                    Icons.eco_rounded,
                                    color: Color(0xFF6EE7B7),
                                    size: 58,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 1),

                        Text(
                          'Smart Irrigation System',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
