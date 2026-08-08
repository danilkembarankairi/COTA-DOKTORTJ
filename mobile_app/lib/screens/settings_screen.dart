import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'threshold_screen.dart';
import 'device_management_screen.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  bool _isNotificationEnabled = true;

  // ✅ BARU: Avatar emoji yang dipilih di Edit Profile
  String? _avatarEmoji;

  // ✅ ANIMASI CONTROLLER (sama dengan dashboard)
  AnimationController? _gc;
  Animation<double>? _ga;

  // ✅ BARU: Animasi entrance untuk body
  late AnimationController _entranceController;
  late Animation<double> _entranceFade;
  late Animation<Offset> _entranceSlide;

  AnimationController get _gradientController => _gc ??= AnimationController(
        vsync: this,
        duration: const Duration(seconds: 3),
      )..repeat(reverse: true);

  Animation<double> get _gradientAnimation =>
      _ga ??= Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _gradientController, curve: Curves.easeInOut),
      );

  void initState() {
    super.initState();
    _loadNotificationPreference();
    _loadAvatar(); // ✅ BARU: muat emoji avatar

    // ✅ BARU: Animasi entrance
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _entranceFade = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));
    _entranceController.forward();
  }

  void dispose() {
    _gc?.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _loadNotificationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isNotificationEnabled = prefs.getBool('isNotificationEnabled') ?? true;
    });
  }

  // ✅ BARU: Muat emoji avatar dari SharedPreferences
  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _avatarEmoji = prefs.getString('avatarEmoji');
      });
    }
  }

  // ✅ BARU: Buka Edit Profile lalu refresh avatar & preferensi saat kembali
  Future<void> _openEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (mounted) {
      _loadAvatar();
      _loadNotificationPreference();
    }
  }

  Future<void> _toggleNotification(bool value) async {
    setState(() {
      _isNotificationEnabled = value;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isNotificationEnabled', value);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  value
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value ? 'Notifikasi diaktifkan' : 'Notifikasi dinonaktifkan',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor:
              value ? const Color(0xFF10B981) : const Color(0xFF64748B),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark; // 🌙
    final userName = authService.user?.name ?? 'Petani';
    final userEmail = authService.user?.email ?? 'user@cota.com';
    final firstName = userName.split(' ').first;

    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // 🌿 HEADER PREMIUM DENGAN ANIMATED GRADIENT (adaptif dark)
          AnimatedBuilder(
            animation: _gradientAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            // 🌙 GELAP: emerald dalam (tidak nabrak)
                            const Color(0xFF022C22),
                            Color.lerp(
                              const Color(0xFF064E3B),
                              const Color(0xFF065F46),
                              _gradientAnimation.value,
                            )!,
                            const Color(0xFF064E3B),
                            const Color(0xFF022C22),
                          ]
                        : [
                            const Color(0xFF10B981),
                            Color.lerp(
                              const Color(0xFF059669),
                              const Color(0xFF047857),
                              _gradientAnimation.value,
                            )!,
                            const Color(0xFF047857),
                            Color.lerp(
                              const Color(0xFF065F46),
                              const Color(0xFF064E3B),
                              _gradientAnimation.value,
                            )!,
                          ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981)
                          .withOpacity(isDark ? 0.12 : 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // 🎨 Grid Pattern Overlay
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.05,
                        child: CustomPaint(
                          painter: _GridPatternPainter(),
                        ),
                      ),
                    ),

                    // 🎨 Floating Circles (animated)
                    AnimatedBuilder(
                      animation: _gradientAnimation,
                      builder: (context, child) {
                        return Positioned(
                          top: -10 + (_gradientAnimation.value * 10),
                          right: -10,
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white.withOpacity(0.12),
                                  Colors.white.withOpacity(0.08),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    AnimatedBuilder(
                      animation: _gradientAnimation,
                      builder: (context, child) {
                        return Positioned(
                          bottom: -30 - (_gradientAnimation.value * 10),
                          left: -20,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white.withOpacity(0.08),
                                  Colors.white.withOpacity(0.05),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 20, 24),
                        child: Column(
                          children: [
                            // ✅ ROW: Back Button + Title + Verified Badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildGlassIconButton(
                                  icon: Icons.arrow_back_ios_new_rounded,
                                  onTap: () => Navigator.pop(context),
                                ),
                                const Text(
                                  'PENGATURAN',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 2.5,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.25),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified_rounded,
                                          color: Colors.white, size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        'Aktif',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Profile Info Card (Glassmorphic) + ✅ Avatar Emoji
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      // ✅ BARU: Emoji jika sudah dipilih, else inisial
                                      child: (_avatarEmoji != null &&
                                              _avatarEmoji!.isNotEmpty)
                                          ? Text(
                                              _avatarEmoji!,
                                              style:
                                                  const TextStyle(fontSize: 24),
                                            )
                                          : Text(
                                              _getInitials(userName),
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF047857),
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          userName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          userEmail,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color:
                                                Colors.white.withOpacity(0.8),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // ✅ Tombol Edit (refresh avatar saat kembali)
                                  GestureDetector(
                                    onTap: _openEditProfile,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF10B981)
                                                .withOpacity(0.4),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.edit_rounded,
                                          color: Colors.white, size: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // 📋 BODY (Scrollable Settings) dengan animasi entrance
          Expanded(
            child: SlideTransition(
              position: _entranceSlide,
              child: FadeTransition(
                opacity: _entranceFade,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildSectionTitle(
                        'Preferensi Aplikasi', Icons.palette_outlined),
                    const SizedBox(height: 12),

                    _buildPremiumTile(
                      context,
                      icon: Icons.notifications_active_rounded,
                      iconBgColor: const Color(0xFFDBEAFE),
                      iconColor: const Color(0xFF2563EB),
                      title: 'Notifikasi Push',
                      subtitle: 'Peringatan status penyiraman & pH',
                      trailing: Switch(
                        value: _isNotificationEnabled,
                        onChanged: _toggleNotification,
                        activeColor: const Color(0xFF10B981),
                        activeTrackColor:
                            const Color(0xFF10B981).withOpacity(0.4),
                      ),
                    ),

                    const SizedBox(height: 28),

                    _buildSectionTitle(
                        'Sistem & Perangkat', Icons.settings_outlined),
                    const SizedBox(height: 12),

                    _buildPremiumTile(
                      context,
                      icon: Icons.tune_rounded,
                      iconBgColor: const Color(0xFFFEF3C7),
                      iconColor: const Color(0xFFD97706),
                      title: 'Pengaturan Threshold',
                      subtitle: 'Atur batas min/max kelembaban & suhu',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ThresholdScreen()),
                        );
                      },
                    ),

                    _buildPremiumTile(
                      context,
                      icon: Icons.devices_rounded,
                      iconBgColor: const Color(0xFFE0E7FF),
                      iconColor: const Color(0xFF4F46E5),
                      title: 'Manajemen Device',
                      subtitle: 'Lihat dan kelola ESP32 yang terdaftar',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const DeviceManagementScreen()),
                        );
                      },
                    ),

                    _buildPremiumTile(
                      context,
                      icon: Icons.help_outline_rounded,
                      iconBgColor: const Color(0xFFF3F4F6),
                      iconColor: const Color(0xFF4B5563),
                      title: 'Bantuan & FAQ',
                      subtitle: 'Panduan penggunaan dan troubleshooting',
                      onTap: () {
                        _showHelpDialog(context);
                      },
                    ),

                    const SizedBox(height: 28),

                    _buildSectionTitle(
                        'Informasi', Icons.account_circle_outlined),
                    const SizedBox(height: 12),

                    _buildPremiumTile(
                      context,
                      icon: Icons.info_outline_rounded,
                      iconBgColor: const Color(0xFFE0F2FE),
                      iconColor: const Color(0xFF0284C7),
                      title: 'Tentang Aplikasi',
                      subtitle: 'COTA Smart Irrigation v1.0.0',
                      onTap: () {
                        _showAboutDialog(context);
                      },
                    ),

                    const SizedBox(height: 24),

                    // Logout Button (adaptif dark)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFF450A0A),
                                  const Color(0xFF7F1D1D),
                                ]
                              : [
                                  const Color(0xFFFEE2E2),
                                  const Color(0xFFFECACA)
                                ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFDC2626)
                              .withOpacity(isDark ? 0.4 : 0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFDC2626)
                                .withOpacity(isDark ? 0.2 : 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _showLogoutDialog(context, authService),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.logout_rounded,
                                    color: isDark
                                        ? const Color(0xFFFCA5A5)
                                        : const Color(0xFFDC2626),
                                    size: 22),
                                const SizedBox(width: 12),
                                Text(
                                  'Keluar dari Aplikasi',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? const Color(0xFFFCA5A5)
                                        : const Color(0xFFDC2626),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Footer (adaptif)
                    Center(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 1,
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.eco_rounded,
                                  color: Color(0xFF10B981), size: 16),
                              const SizedBox(width: 12),
                              Container(
                                width: 40,
                                height: 1,
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Made with 💚 for Indonesian Farmers',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey[500],
                              fontStyle: FontStyle.italic,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '© 2026 COTA Smart Irrigation',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 GLASSMORPHIC ICON BUTTON
  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: Icon(icon, color: Colors.white, size: 18)),
      ),
    );
  }

  // 🎨 SECTION TITLE (adaptif dark)
  Widget _buildSectionTitle(String title, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF10B981).withOpacity(isDark ? 0.25 : 0.18),
                  const Color(0xFF10B981).withOpacity(isDark ? 0.10 : 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF10B981), size: 14),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 PREMIUM TILE (adaptif dark)
  Widget _buildPremiumTile(
    BuildContext context, {
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          splashColor: Colors.grey.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              iconColor.withOpacity(0.22),
                              iconColor.withOpacity(0.10),
                            ]
                          : [
                              iconBgColor,
                              iconBgColor.withOpacity(0.7),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark
                              ? Colors.grey.shade400
                              : const Color(0xFF64748B),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing ??
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.grey.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF94A3B8),
                        size: 22,
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🎨 DIALOG LOGOUT (adaptif dark)
  void _showLogoutDialog(BuildContext context, AuthService authService) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? Theme.of(context).cardColor : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF7F1D1D),
                          const Color(0xFF991B1B),
                        ]
                      : [const Color(0xFFFEE2E2), const Color(0xFFFECACA)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFDC2626), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Konfirmasi Keluar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar? Anda harus login kembali untuk mengakses dashboard dan mengontrol perangkat.',
          style: TextStyle(
            color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
            height: 1.5,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal',
                style: TextStyle(
                    color:
                        isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                    fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await authService.logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 0,
            ),
            child: const Text('Ya, Keluar',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 🎨 DIALOG TENTANG (adaptif dark)
  void _showAboutDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? Theme.of(context).cardColor : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF064E3B),
                          const Color(0xFF065F46),
                        ]
                      : [const Color(0xFFD1FAE5), const Color(0xFFA7F3D0)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.eco_rounded,
                  color: Color(0xFF10B981), size: 24),
            ),
            const SizedBox(width: 12),
            Text('Tentang COTA',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isDark ? Colors.white : const Color(0xFF0F172A))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'COTA Smart Irrigation',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            Text(
              'Version 1.0.0 (Build 2024)',
              style: TextStyle(
                  color:
                      isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                  fontSize: 13),
            ),
            const SizedBox(height: 16),
            Text(
              'Sistem irigasi pintar berbasis IoT yang membantu petani Indonesia mengoptimalkan penggunaan air, memantau kondisi tanah, dan meningkatkan hasil panen secara efisien.',
              style: TextStyle(
                  height: 1.5,
                  color:
                      isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                  fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildFeatureTag('💧 Hemat Air', isDark),
                const SizedBox(width: 6),
                _buildFeatureTag('🌾 Maksimal', isDark),
                const SizedBox(width: 6),
                _buildFeatureTag('✨ Mudah', isDark),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 0,
            ),
            child: const Text('Tutup',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTag(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(isDark ? 0.3 : 0.2),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
        ),
      ),
    );
  }

  // 🎨 DIALOG BANTUAN (adaptif dark)
  void _showHelpDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? Theme.of(context).cardColor : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF312E81),
                          const Color(0xFF3730A3),
                        ]
                      : [const Color(0xFFE0E7FF), const Color(0xFFC7D2FE)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.help_outline_rounded,
                  color: Color(0xFF818CF8), size: 24),
            ),
            const SizedBox(width: 12),
            Text('Bantuan',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isDark ? Colors.white : const Color(0xFF0F172A))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hubungi dukungan teknis jika Anda mengalami kendala:',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 16),
            _buildContactItem(
              icon: Icons.email_outlined,
              label: 'Email',
              value: 'danielsantosoopl1@gmail.com',
              color: const Color(0xFF4F46E5),
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _buildContactItem(
              icon: Icons.phone_outlined,
              label: 'WhatsApp',
              value: '+62 852-1279-3050',
              color: const Color(0xFF10B981),
              isDark: isDark,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Tutup',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.10 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(isDark ? 0.25 : 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 🎨 CUSTOM PAINTER: Grid Pattern
class _GridPatternPainter extends CustomPainter {
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 20.0;

    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
