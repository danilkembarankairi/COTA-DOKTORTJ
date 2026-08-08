import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart'; // ✅ BARU: untuk getMe()
import '../config/api_config.dart';
import '../providers/theme_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with TickerProviderStateMixin {
  final _nameFormKey = GlobalKey<FormState>();
  final _passFormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _isLoadingName = false;
  bool _isLoadingPass = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  // ✅ Preferensi
  String _selectedEmoji = '👨‍🌾';
  String _tempUnit = 'C';
  String _language = 'id';
  bool _pushEnabled = true;
  bool _emailAlert = false;
  String _digestFreq = 'daily';

  // ✅ Tanggal bergabung (otomatis dari backend)
  String _joinDate = 'Memuat...';

  // ✅ Lazy animation controllers
  AnimationController? _ec;
  Animation<double>? _fa;
  final Map<int, Animation<Offset>> _slides = {};

  AnimationController get _entranceController => _ec ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      )..forward();

  Animation<double> get _fadeAnim => _fa ??=
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);

  Animation<Offset> _slideFor(int index) {
    return _slides[index] ??=
        Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Interval(
          0.0 + index * 0.08,
          0.5 + index * 0.08,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }

  static const List<String> _emojiOptions = [
    '👨‍🌾',
    '👩‍',
    '‍🌾',
    '🌱',
    '🌿',
    '🌾',
    '💧',
    '🌻',
    '🍅',
    '️',
    '🥕',
    '🌽',
    '🍇',
    '🍓',
    '',
    '🌳',
    '☀️',
    '🌧️',
  ];

  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    _nameController.text = auth.user?.name ?? '';

    _newPassController.addListener(_refresh);
    _confirmPassController.addListener(_refresh);

    _loadPreferences();
    _loadJoinDate();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedEmoji = prefs.getString('avatarEmoji') ?? '👨‍🌾';
      _tempUnit = prefs.getString('tempUnit') ?? 'C';
      _language = prefs.getString('language') ?? 'id';
      _pushEnabled = prefs.getBool('isNotificationEnabled') ?? true;
      _emailAlert = prefs.getBool('emailAlert') ?? false;
      _digestFreq = prefs.getString('digestFreq') ?? 'daily';
    });
  }

  // ✅ FIX UTAMA: Pakai ApiService.getMe() — otomatis attach token + path benar
  Future<void> _loadJoinDate() async {
    try {
      final res = await ApiService.getMe();
      if (!mounted) return;

      if (res['success'] == true && res['data'] != null) {
        final createdAtStr = res['data']['createdAt'];
        if (createdAtStr != null) {
          final date = DateTime.parse(createdAtStr.toString());
          if (mounted) {
            setState(() {
              _joinDate = DateFormat('d MMMM yyyy', 'id_ID').format(date);
            });
          }
        } else {
          if (mounted) setState(() => _joinDate = 'Tidak tersedia');
        }
      } else {
        if (mounted) setState(() => _joinDate = 'Tidak tersedia');
      }
    } catch (e) {
      if (mounted) setState(() => _joinDate = 'Tidak tersedia');
    }
  }

  Future<void> _savePref(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  void dispose() {
    _ec?.dispose();
    _nameController.dispose();
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  double _passwordStrength(String p) {
    int score = 0;
    if (p.length >= 6) score++;
    if (p.length >= 10) score++;
    if (RegExp(r'[A-Z]').hasMatch(p)) score++;
    if (RegExp(r'[0-9]').hasMatch(p)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) score++;
    return (score / 5).clamp(0.0, 1.0);
  }

  Color _strengthColor(double s) => s < 0.4
      ? const Color(0xFFEF4444)
      : (s < 0.7 ? const Color(0xFFF59E0B) : const Color(0xFF10B981));

  String _strengthLabel(double s) =>
      s < 0.4 ? 'Lemah' : (s < 0.7 ? 'Cukup' : 'Kuat');

  bool get _passMatch =>
      _confirmPassController.text.isNotEmpty &&
      _confirmPassController.text == _newPassController.text;

  void _snack(String msg, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              ok ? Icons.check_circle_rounded : Icons.error_rounded,
              color: Colors.white,
              size: 20,
            ),
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
      ),
    );
  }

  Future<void> _saveName() async {
    if (!_nameFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoadingName = true);
    final result = await Provider.of<AuthService>(context, listen: false)
        .updateProfile(_nameController.text.trim());
    if (!mounted) return;
    setState(() => _isLoadingName = false);
    _snack(
      result['success'] == true
          ? 'Nama berhasil diperbarui'
          : (result['message'] ?? 'Gagal memperbarui nama'),
      result['success'] == true,
    );
  }

  Future<void> _changePassword() async {
    if (!_passFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoadingPass = true);
    final result = await Provider.of<AuthService>(context, listen: false)
        .changePassword(_currentPassController.text, _newPassController.text);
    if (!mounted) return;
    setState(() => _isLoadingPass = false);
    if (result['success'] == true) {
      _currentPassController.clear();
      _newPassController.clear();
      _confirmPassController.clear();
      _snack('Password berhasil diubah', true);
    } else {
      _snack(result['message'] ?? 'Gagal mengubah password', false);
    }
  }

  // 🌙 Emoji picker adaptif
  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text('Pilih Avatar Emoji',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  )),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _emojiOptions.length,
                itemBuilder: (context, index) {
                  final emoji = _emojiOptions[index];
                  final isSelected = emoji == _selectedEmoji;
                  return GestureDetector(
                    onTap: () async {
                      setState(() => _selectedEmoji = emoji);
                      await _savePref('avatarEmoji', emoji);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF10B981).withOpacity(0.15)
                            : (isDark
                                ? Colors.white.withOpacity(0.06)
                                : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF10B981)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child:
                            Text(emoji, style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // 🌙 Dialog hapus akun adaptif
  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor:
              isDark ? Theme.of(dialogContext).cardColor : Colors.white,
          title: Row(
            children: [
              const Icon(Icons.warning_rounded,
                  color: Color(0xFFEF4444), size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Hapus Akun Permanen?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    )),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tindakan ini TIDAK BISA dibatalkan. Semua data Anda akan dihapus:',
                style: TextStyle(
                    color: isDark
                        ? Colors.grey.shade300
                        : const Color(0xFF475569)),
              ),
              const SizedBox(height: 12),
              _DeleteBullet(text: 'Data profil & preferensi', isDark: isDark),
              _DeleteBullet(text: 'Device yang terhubung', isDark: isDark),
              _DeleteBullet(text: 'Riwayat sensor & jadwal', isDark: isDark),
              _DeleteBullet(text: 'Akses permanen ke aplikasi', isDark: isDark),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Batal',
                  style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade400
                          : const Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _snack('Fitur penghapusan akun belum tersedia di versi ini',
                    false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Ya, Hapus Akun Saya',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode; // 🌙
    final userName = authService.user?.name ?? 'User';
    final userEmail = authService.user?.email ?? '-';
    final userRole = authService.user?.role ?? 'farmer';

    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // 🎨 HEADER (adaptif: emerald dalam saat dark)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF022C22),
                        const Color(0xFF064E3B),
                        const Color(0xFF065F46),
                        const Color(0xFF022C22),
                      ]
                    : [
                        const Color(0xFF10B981),
                        const Color(0xFF059669),
                        const Color(0xFF047857),
                        const Color(0xFF065F46),
                      ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -30,
                  right: -30,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.07),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -40,
                  left: -20,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 20, 24),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.25)),
                                ),
                                child: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: Colors.white,
                                    size: 18),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'PROFIL & PENGATURAN',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 2.0,
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: _showEmojiPicker,
                              child: Stack(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [
                                          Colors.white,
                                          Color(0xFFD1FAE5),
                                        ],
                                      ),
                                    ),
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          _selectedEmoji,
                                          style: const TextStyle(fontSize: 36),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(Icons.camera_alt,
                                          color: Colors.white, size: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    userEmail,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      userRole == 'admin'
                                          ? '👑 Admin'
                                          : '🌾 Petani',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 📋 BODY
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              children: [
                // ============ SECTION 1: INFO AKUN ============
                _slideWrap(
                    0,
                    _sectionTitle('Informasi Akun', Icons.info_outline_rounded,
                        color: const Color(0xFF0284C7))),
                const SizedBox(height: 10),
                _slideWrap(
                    0,
                    _infoCard(
                      email: userEmail,
                      role: userRole,
                      joinDate: _joinDate,
                    )),
                const SizedBox(height: 24),

                // ============ SECTION 2: NAMA LENGKAP ============
                _slideWrap(
                    1,
                    _sectionTitle(
                        'Informasi Pribadi', Icons.person_outline_rounded,
                        color: const Color(0xFF10B981))),
                const SizedBox(height: 10),
                _slideWrap(
                    1,
                    _card(
                      child: Form(
                        key: _nameFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nama Lengkap',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.grey.shade300
                                        : const Color(0xFF475569))),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _nameController,
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A)),
                              decoration: InputDecoration(
                                hintText: 'Masukkan nama baru',
                                hintStyle: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade500
                                        : const Color(0xFF94A3B8)),
                                prefixIcon: const Icon(Icons.badge_outlined,
                                    color: Color(0xFF10B981)),
                                filled: true,
                                fillColor: isDark
                                    ? Colors.white.withOpacity(0.04)
                                    : const Color(0xFFF1F5F9),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.08)
                                          : Colors.grey.shade200,
                                      width: 1.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF10B981), width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().length < 3) {
                                  return 'Nama minimal 3 karakter';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _gradientButton(
                              colors: const [
                                Color(0xFF10B981),
                                Color(0xFF059669)
                              ],
                              shadow: const Color(0xFF10B981),
                              isLoading: _isLoadingName,
                              onTap: _saveName,
                              icon: Icons.save_rounded,
                              label: 'Simpan Nama',
                            ),
                          ],
                        ),
                      ),
                    )),
                const SizedBox(height: 24),

                // ============ SECTION 4: PREFERENSI TAMPILAN ============
                _slideWrap(
                    3,
                    _sectionTitle('Preferensi Tampilan', Icons.palette_outlined,
                        color: const Color(0xFFF59E0B))),
                const SizedBox(height: 10),
                _slideWrap(
                    3,
                    _card(
                      child: Column(
                        children: [
                          _prefSwitchTile(
                            icon: Icons.dark_mode_rounded,
                            iconColor: const Color(0xFF7C3AED),
                            iconBg: const Color(0xFFEDE9FE),
                            title: 'Mode Gelap',
                            subtitle: 'Tampilan gelap untuk kenyamanan mata',
                            value: themeProvider.isDarkMode,
                            onChanged: (v) => themeProvider.toggleTheme(),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 24),

                // ============ SECTION 5: ZONA BERBAHAYA ============
                _slideWrap(
                    5,
                    _sectionTitle('Zona Berbahaya', Icons.warning_amber_rounded,
                        color: const Color(0xFFEF4444))),
                const SizedBox(height: 10),
                _slideWrap(
                    5,
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFF450A0A),
                                  const Color(0xFF7F1D1D).withOpacity(0.6),
                                ]
                              : [
                                  const Color(0xFFFEE2E2),
                                  const Color(0xFFFECACA).withOpacity(0.5),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: const Color(0xFFEF4444)
                                .withOpacity(isDark ? 0.4 : 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444)
                                      .withOpacity(isDark ? 0.25 : 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.dangerous_rounded,
                                    color: Color(0xFFEF4444), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Hapus Akun Permanen',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? const Color(0xFFFCA5A5)
                                        : const Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Tindakan ini tidak dapat dibatalkan. Semua data Anda akan hilang permanen.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFFFECACA)
                                  : const Color(0xFF7F1D1D),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _showDeleteAccountDialog,
                              icon: const Icon(Icons.delete_forever_rounded,
                                  size: 18),
                              label: const Text('Hapus Akun Saya',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark
                                    ? const Color(0xFFFCA5A5)
                                    : const Color(0xFFDC2626),
                                side: BorderSide(
                                    color: isDark
                                        ? const Color(0xFFFCA5A5)
                                        : const Color(0xFFDC2626),
                                    width: 1.5),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _slideWrap(int index, Widget child) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(position: _slideFor(index), child: child),
    );
  }

  // 🌙 Info card adaptif
  Widget _infoCard({
    required String email,
    required String role,
    required String joinDate,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF082F49),
                  const Color(0xFF0C4A6E).withOpacity(0.5),
                ]
              : [
                  const Color(0xFFE0F2FE),
                  const Color(0xFFDBEAFE).withOpacity(0.5),
                ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: const Color(0xFF0284C7).withOpacity(isDark ? 0.35 : 0.2)),
      ),
      child: Column(
        children: [
          _infoRow(icon: Icons.email_outlined, label: 'Email', value: email),
          const SizedBox(height: 10),
          _infoRow(
            icon: Icons.badge_outlined,
            label: 'Peran',
            value: role == 'admin' ? 'Administrator' : 'Petani',
          ),
          const SizedBox(height: 10),
          _infoRow(
            icon: Icons.calendar_month_outlined,
            label: 'Bergabung Sejak',
            value: joinDate,
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0C4A6E) : Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0284C7),
              size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? const Color(0xFF7DD3FC)
                          : const Color(0xFF0369A1),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  // 🌙 Switch tile adaptif
  Widget _prefSwitchTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: isDark ? iconColor.withOpacity(0.18) : iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A))),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.grey.shade400
                          : const Color(0xFF64748B))),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF10B981),
          activeTrackColor: const Color(0xFF10B981).withOpacity(0.3),
          inactiveTrackColor:
              isDark ? Colors.grey.shade700 : Colors.grey.shade300,
        ),
      ],
    );
  }

  Widget _prefSegmentedTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: isDark ? iconColor.withOpacity(0.18) : iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A))),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.04)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: options.entries.map((e) {
              final isSelected = e.key == value;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF10B981)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                  ? Colors.grey.shade400
                                  : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStrengthMeter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = _passwordStrength(_newPassController.text);
    final color = _strengthColor(s);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: s,
            minHeight: 6,
            backgroundColor:
                isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text('Kekuatan: ${_strengthLabel(s)}',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _gradientButton({
    required List<Color> colors,
    required Color shadow,
    required bool isLoading,
    required VoidCallback onTap,
    required IconData icon,
    required String label,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: shadow.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isLoading ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🌙 Section title adaptif
  Widget _sectionTitle(String title, IconData icon, {required Color color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              color.withOpacity(isDark ? 0.25 : 0.2),
              color.withOpacity(isDark ? 0.10 : 0.08),
            ]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color:
                    isDark ? Colors.grey.shade200 : const Color(0xFF334155))),
      ],
    );
  }

  // 🌙 Card adaptif
  Widget _card({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color:
                isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // 🌙 Password field adaptif
  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback toggle,
    required String? Function(String?) validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B)),
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF10B981)),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.grey.shade500,
            size: 20,
          ),
          onPressed: toggle,
        ),
        filled: true,
        fillColor:
            isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.grey.shade200,
              width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
    );
  }
}

// 🌙 Helper bullet adaptif
class _DeleteBullet extends StatelessWidget {
  final String text;
  final bool isDark;
  const _DeleteBullet({required this.text, required this.isDark});

  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.remove_circle_outline,
              color: Color(0xFFEF4444), size: 16),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(
                  color:
                      isDark ? Colors.grey.shade300 : const Color(0xFF475569))),
        ],
      ),
    );
  }
}
