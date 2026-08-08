import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _step = 1;
  bool _isLoading = false;

  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _animationController!, curve: Curves.easeOutQuart),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
          parent: _animationController!, curve: Curves.easeOutQuart),
    );

    _animationController!.forward();
  }

  void dispose() {
    _animationController?.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _snack(String msg, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded,
                color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        backgroundColor: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 6,
      ),
    );
  }

  // ✅ STEP 1: kirim OTP
  Future<void> _sendOtp() async {
    if (!_step1Key.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      final res =
          await ApiService.sendRegisterOtp(_emailController.text.trim());
      if (!mounted) return;

      if (res['success'] == true) {
        setState(() => _step = 2);
        final demoCode = res['demoCode']?.toString() ?? '';
        if (demoCode.isNotEmpty) {
          _showDemoCodeDialog(demoCode);
        } else {
          _snack(
              '📧 Kode OTP dikirim ke ${_emailController.text.trim()}', true);
        }
      } else {
        _snack(res['message'] ?? 'Gagal mengirim kode', false);
      }
    } catch (e) {
      if (mounted) _snack('Koneksi error: $e', false);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ✅ STEP 2: verifikasi OTP + daftar
  Future<void> _register() async {
    if (!_step2Key.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await authService.register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
      _otpController.text.trim(),
    );

    if (!mounted) return;
    if (success) {
      _snack('🎉 Registrasi berhasil! Silakan login.', true);
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } else {
      _snack(authService.errorMessage ?? 'Registrasi gagal', false);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showDemoCodeDialog(String code) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF0369A1)]),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF0284C7).withOpacity(0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 8)),
                  ],
                ),
                child: const Icon(Icons.mail_rounded,
                    color: Colors.white, size: 44),
              ),
              const SizedBox(height: 20),
              const Text('Kode OTP Anda',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A))),
              const SizedBox(height: 6),
              const Text('Mode Demo: gunakan kode ini untuk verifikasi',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFF0284C7).withOpacity(0.25),
                      width: 2),
                ),
                child: Text(
                  code,
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                      color: Color(0xFF0284C7),
                      fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Masukkan Kode',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget build(BuildContext context) {
    if (_fadeAnimation == null || _slideAnimation == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
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
        child: SafeArea(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: -120,
                right: -160,
                child: Transform.rotate(
                  angle: -0.35,
                  child: Container(
                    width: 420,
                    height: 240,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              Positioned(
                bottom: -60,
                right: -60,
                child: FadeTransition(
                  opacity: _fadeAnimation!,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
              ),
              SlideTransition(
                position: _slideAnimation!,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.25)),
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      FadeTransition(
                        opacity: _fadeAnimation!,
                        child: Column(
                          children: [
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
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Icon(Icons.eco_rounded,
                                          color: Color(0xFF6EE7B7), size: 58),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 9),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(colors: [
                                  Colors.white.withOpacity(0.15),
                                  Colors.white.withOpacity(0.05),
                                ]),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.20),
                                    width: 1),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('COTA',
                                      style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 6,
                                          shadows: [
                                            Shadow(
                                                color: Colors.black26,
                                                offset: Offset(0, 2),
                                                blurRadius: 4)
                                          ])),
                                  const SizedBox(height: 4),
                                  Text('CONTROL TANAMAN',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white.withOpacity(0.90),
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 3)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              _step == 1
                                  ? 'Lengkapi data diri Anda'
                                  : 'Masukkan kode OTP dari email',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.85),
                                  fontWeight: FontWeight.w500,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Step indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _stepDot(1, 'Data Diri'),
                          Container(
                            width: 48,
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              gradient: _step == 2
                                  ? const LinearGradient(colors: [
                                      Color(0xFF34D399),
                                      Color(0xFF10B981)
                                    ])
                                  : null,
                              color: _step == 2
                                  ? null
                                  : Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          _stepDot(2, 'OTP'),
                        ],
                      ),
                      const SizedBox(height: 19),

                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: _step == 1 ? _buildStep1() : _buildStep2(),
                      ),

                      const SizedBox(height: 22),

                      FadeTransition(
                        opacity: _fadeAnimation!,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Sudah memiliki akun?',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const LoginScreen()),
                                  (route) => false,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.25)),
                                ),
                                child: const Text('Login di sini',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ STEP 1: DATA DIRI ============
  Widget _buildStep1() {
    return Form(
      key: _step1Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Buat Akun Baru',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          Text('Silakan lengkapi data diri Anda untuk memulai.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          const SizedBox(height: 22),
          _buildLoginStyleField(
            controller: _nameController,
            hint: 'Nama Lengkap',
            icon: Icons.person_outline,
            validator: (val) => val!.trim().isEmpty ? 'Nama wajib diisi' : null,
          ),
          const SizedBox(height: 14),
          _buildLoginStyleField(
            controller: _emailController,
            hint: 'Alamat Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (val) {
              if (val!.isEmpty) return 'Email tidak boleh kosong';
              if (!val.contains('@')) return 'Format email tidak valid';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _buildLoginStyleField(
            controller: _passwordController,
            hint: 'Kata Sandi',
            icon: Icons.lock_outline,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey.shade500,
                  size: 20),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (val) {
              if (val!.isEmpty) return 'Kata sandi tidak boleh kosong';
              if (val.length < 6) return 'Minimal 6 karakter';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _buildLoginStyleField(
            controller: _confirmPasswordController,
            hint: 'Konfirmasi Kata Sandi',
            icon: Icons.lock_outline,
            obscureText: _obscureConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey.shade500,
                  size: 20),
              onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            validator: (val) {
              if (val!.isEmpty) return 'Konfirmasi kata sandi wajib diisi';
              if (val != _passwordController.text)
                return 'Kata sandi tidak cocok';
              return null;
            },
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('KIRIM KODE OTP',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.5)),
                        SizedBox(width: 10),
                        Icon(Icons.send_rounded, size: 18, color: Colors.white),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ STEP 2: OTP ============
  Widget _buildStep2() {
    return Form(
      key: _step2Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Verifikasi Email',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          Text('Masukkan kode 6 digit yang kami kirim ke email Anda.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.email_outlined,
                    color: Color(0xFF10B981), size: 14),
                const SizedBox(width: 6),
                Flexible(
                  child: Text('Kode dikirim ke: ${_emailController.text}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF047857),
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildLoginStyleField(
            controller: _otpController,
            hint: '• • • • • •',
            icon: Icons.pin_outlined,
            iconColor: const Color(0xFF0284C7),
            keyboardType: TextInputType.number,
            letterSpacing: 6,
            validator: (val) => val!.length != 6 ? 'Kode harus 6 digit' : null,
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0369A1)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF0284C7).withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('VERIFIKASI & DAFTAR',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.5)),
                        SizedBox(width: 10),
                        Icon(Icons.verified_user_rounded,
                            size: 18, color: Colors.white),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _isLoading ? null : _sendOtp,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Kirim ulang kode',
                    style: TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() {
                  _step = 1;
                  _otpController.clear();
                }),
                child: const Text('Ubah data',
                    style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepDot(int step, String label) {
    final active = _step >= step;
    final current = _step == step;
    return Row(
      children: [
        Container(
          width: current ? 32 : 26,
          height: current ? 32 : 26,
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [Color(0xFF34D399), Color(0xFF10B981)])
                : null,
            color: active ? null : Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text('$step',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                color: active ? Colors.white : Colors.white.withOpacity(0.6),
                fontSize: 12,
                fontWeight: current ? FontWeight.w800 : FontWeight.w600)),
      ],
    );
  }

  Widget _buildLoginStyleField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    Color iconColor = const Color(0xFF10B981),
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    double letterSpacing = 0,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(
          fontSize: 15,
          color: const Color(0xFF0F172A),
          fontWeight: FontWeight.w500,
          letterSpacing: letterSpacing),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: const Color(0xFF94A3B8),
            fontSize: 14,
            letterSpacing: letterSpacing),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: iconColor, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade300, width: 1)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade400, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator,
    );
  }
}
