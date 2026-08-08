import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // ✅ BARU: untuk akses DeviceProvider
import '../services/api_service.dart';
import '../providers/device_provider.dart'; // ✅ BARU: untuk ambil deviceId aktif

class ThresholdScreen extends StatefulWidget {
  const ThresholdScreen({Key? key}) : super(key: key);

  State<ThresholdScreen> createState() => _ThresholdScreenState();
}

class _ThresholdScreenState extends State<ThresholdScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isAutoWateringEnabled = true;
  String? _activeDeviceId; // ✅ BARU: ID device yang sedang dipilih

  // Controllers
  final _moistureMinController = TextEditingController(text: '70');
  final _moistureMaxController = TextEditingController(text: '90');
  final _phMinController = TextEditingController(text: '5.5');
  final _phMaxController = TextEditingController(text: '6.5');
  final _tempMinController = TextEditingController(text: '25');
  final _tempMaxController = TextEditingController(text: '30');

  void initState() {
    super.initState();
    // ✅ BARU: ambil device aktif dari Provider
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    _activeDeviceId = deviceProvider.selectedDevice?.deviceId;

    if (_activeDeviceId != null) {
      _loadThreshold();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadThreshold() async {
    if (_activeDeviceId == null) return;

    setState(() => _isLoading = true);
    try {
      print(
          '📡 [FLUTTER] Memanggil API getThreshold untuk device: $_activeDeviceId');
      // ✅ BARU: kirim deviceId ke ApiService
      final response = await ApiService.getThreshold(_activeDeviceId!);

      if (response['success'] == true) {
        final data = response['data'];
        print('📊 [FLUTTER LOAD] Data mentah dari DB: $data');

        final rawAutoWatering = data['isAutoWateringEnabled'];
        print(
            '🔍 [FLUTTER LOAD] Nilai isAutoWateringEnabled mentah: $rawAutoWatering (Tipe: ${rawAutoWatering.runtimeType})');

        setState(() {
          _moistureMinController.text =
              (data['moistureMin'] ?? 70).toDouble().toString();
          _moistureMaxController.text =
              (data['moistureMax'] ?? 90).toDouble().toString();
          _phMinController.text = (data['phMin'] ?? 5.5).toDouble().toString();
          _phMaxController.text = (data['phMax'] ?? 6.5).toDouble().toString();
          _tempMinController.text =
              (data['temperatureMin'] ?? 25).toDouble().toString();
          _tempMaxController.text =
              (data['temperatureMax'] ?? 30).toDouble().toString();

          _isAutoWateringEnabled = rawAutoWatering == false ? false : true;

          print(
              '🎛️ [FLUTTER LOAD] Status Toggle SETELAH di-set: $_isAutoWateringEnabled');
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ [FLUTTER] Error load: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal memuat data: $e'),
              backgroundColor: Colors.red.shade500,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
        );
      }
    }
  }

  Future<void> _saveThreshold() async {
    if (_activeDeviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pilih device terlebih dahulu di Dashboard!'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      try {
        final payload = {
          'moistureMin': double.tryParse(_moistureMinController.text) ?? 70.0,
          'moistureMax': double.tryParse(_moistureMaxController.text) ?? 90.0,
          'phMin': double.tryParse(_phMinController.text) ?? 5.5,
          'phMax': double.tryParse(_phMaxController.text) ?? 6.5,
          'temperatureMin': double.tryParse(_tempMinController.text) ?? 25.0,
          'temperatureMax': double.tryParse(_tempMaxController.text) ?? 30.0,
          'isAutoWateringEnabled': _isAutoWateringEnabled,
        };

        print('📤 [FLUTTER SAVE] Device: $_activeDeviceId');
        print('📤 [FLUTTER SAVE] Payload: $payload');

        // ✅ BARU: kirim deviceId + payload ke ApiService
        final response =
            await ApiService.updateThreshold(_activeDeviceId!, payload);

        if (response['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Threshold berhasil disimpan!',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                backgroundColor: Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(),
              ),
            );
            await _loadThreshold();
          }
        } else {
          throw Exception(response['message'] ?? 'Gagal menyimpan');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: $e'),
                backgroundColor: Colors.red.shade500,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          );
        }
      } finally {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ BARU: tampilkan pesan kalau belum ada device
    if (_activeDeviceId == null && !_isLoading) {
      return Scaffold(
        backgroundColor: isDark
            ? Theme.of(context).scaffoldBackgroundColor
            : const Color(0xFFF8FAFC),
        appBar: _buildAppBar(isDark),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF10B981).withOpacity(isDark ? 0.15 : 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        const Color(0xFF10B981).withOpacity(isDark ? 0.3 : 0.2),
                    width: 2,
                  ),
                ),
                child: Icon(Icons.devices_rounded,
                    size: 64,
                    color: isDark
                        ? const Color(0xFF6EE7B7)
                        : const Color(0xFF10B981)),
              ),
              const SizedBox(height: 20),
              Text('Pilih Device Dahulu',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A))),
              const SizedBox(height: 8),
              Text('Silakan pilih device di Dashboard terlebih dahulu.',
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark
            ? Theme.of(context).scaffoldBackgroundColor
            : const Color(0xFFF8FAFC),
        body: const Center(
            child: CircularProgressIndicator(color: Color(0xFF10B981))),
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF8FAFC),
      appBar: _buildAppBar(isDark),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ BARU: Banner info device aktif
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0284C7).withOpacity(0.12)
                      : const Color(0xFF0284C7).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF0284C7)
                          .withOpacity(isDark ? 0.3 : 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.memory_rounded,
                        color: isDark
                            ? const Color(0xFF7DD3FC)
                            : const Color(0xFF0284C7),
                        size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Threshold untuk: $_activeDeviceId',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFF7DD3FC)
                              : const Color(0xFF0284C7),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 1. Info Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF10B981).withOpacity(0.12)
                      : const Color(0xFF10B981).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF10B981)
                        .withOpacity(isDark ? 0.30 : 0.20),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.info_outline_rounded,
                          color: Color(0xFF10B981), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Atur batas sensor agar sistem bekerja optimal. Penyiraman otomatis akan aktif jika nilai melewati batas yang ditentukan.',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFFA7F3D0)
                              : const Color(0xFF047857),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 2. Auto Watering Toggle
              _buildSectionTitle('Mode Penyiraman', isDark),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: isDark ? Theme.of(context).cardColor : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isAutoWateringEnabled
                        ? const Color(0xFF10B981)
                            .withOpacity(isDark ? 0.45 : 0.3)
                        : (isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.grey.shade200),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isAutoWateringEnabled
                          ? const Color(0xFF10B981)
                              .withOpacity(isDark ? 0.18 : 0.1)
                          : Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SwitchListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isAutoWateringEnabled
                                ? [
                                    const Color(0xFF10B981),
                                    const Color(0xFF059669)
                                  ]
                                : [
                                    isDark
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade300,
                                    isDark
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade400,
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Penyiraman Otomatis',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Berdasarkan data sensor real-time',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  value: _isAutoWateringEnabled,
                  onChanged: (val) =>
                      setState(() => _isAutoWateringEnabled = val),
                  activeColor: Colors.white,
                  activeTrackColor: const Color(0xFF10B981),
                  inactiveThumbColor:
                      isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                  inactiveTrackColor:
                      isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
              ),

              const SizedBox(height: 28),

              _buildSectionTitle('Batas Sensor', isDark),
              const SizedBox(height: 12),

              _buildModernInputCard(
                title: 'Kelembaban Tanah',
                subtitle: 'Persentase air dalam tanah',
                icon: Icons.water_drop_rounded,
                iconBgColor: const Color(0xFFDBEAFE),
                iconColor: const Color(0xFF2563EB),
                minLabel: 'Min (%)',
                maxLabel: 'Max (%)',
                minController: _moistureMinController,
                maxController: _moistureMaxController,
                isDark: isDark,
              ),
              const SizedBox(height: 12),

              _buildModernInputCard(
                title: 'pH Tanah',
                subtitle: 'Tingkat keasaman tanah',
                icon: Icons.science_rounded,
                iconBgColor: const Color(0xFFEDE9FE),
                iconColor: const Color(0xFF7C3AED),
                minLabel: 'Min (pH)',
                maxLabel: 'Max (pH)',
                minController: _phMinController,
                maxController: _phMaxController,
                isDark: isDark,
              ),
              const SizedBox(height: 12),

              _buildModernInputCard(
                title: 'Suhu Tanah',
                subtitle: 'Temperatur di dalam tanah',
                icon: Icons.thermostat_rounded,
                iconBgColor: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFD97706),
                minLabel: 'Min (°C)',
                maxLabel: 'Max (°C)',
                minController: _tempMinController,
                maxController: _tempMaxController,
                isDark: isDark,
              ),
              const SizedBox(height: 32),

              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveThreshold,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Icon(Icons.save_rounded,
                          color: Colors.white, size: 20),
                  label: Text(
                    _isSaving ? 'Menyimpan...' : 'Simpan Pengaturan',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(bool isDark) {
    return AppBar(
      title: const Text(
        'Pengaturan Threshold',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: Colors.white,
        ),
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    Color(0xFF022C22),
                    Color(0xFF064E3B),
                    Color(0xFF065F46),
                    Color(0xFF022C22),
                  ]
                : const [
                    Color(0xFF10B981),
                    Color(0xFF059669),
                    Color(0xFF047857),
                    Color(0xFF064E3B),
                  ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
      ),
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildModernInputCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String minLabel,
    required String maxLabel,
    required TextEditingController minController,
    required TextEditingController maxController,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? iconColor.withOpacity(0.18) : iconBgColor,
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
                          fontWeight: FontWeight.w600,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade400
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                      minLabel, minController, iconColor, isDark),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? iconColor.withOpacity(0.18) : iconBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_forward_rounded,
                        color: iconColor, size: 16),
                  ),
                ),
                Expanded(
                  child: _buildTextField(
                      maxLabel, maxController, iconColor, isDark),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      Color themeColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.04)
                : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.grey.shade200,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.grey.shade200,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: themeColor, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: (val) {
            if (val == null || val.isEmpty) return 'Wajib';
            if (double.tryParse(val) == null) return 'Angka';
            return null;
          },
        ),
      ],
    );
  }

  void dispose() {
    _moistureMinController.dispose();
    _moistureMaxController.dispose();
    _phMinController.dispose();
    _phMaxController.dispose();
    _tempMinController.dispose();
    _tempMaxController.dispose();
    super.dispose();
  }
}
