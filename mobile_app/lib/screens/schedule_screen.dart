import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/device_provider.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({Key? key}) : super(key: key);

  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _isLoading = true;
  List<dynamic> _schedules = [];
  String? _activeDeviceId; // ✅ BARU: ID device yang sedang dipilih

  void initState() {
    super.initState();
    _loadSchedules();
  }

  // ✅ BARU: Kirim deviceId ke API supaya jadwal difilter per-device
  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);
    try {
      final deviceProvider =
          Provider.of<DeviceProvider>(context, listen: false);
      _activeDeviceId = deviceProvider.selectedDevice?.deviceId;

      print(
          '📡 [FLUTTER] Memanggil getSchedules untuk device: $_activeDeviceId');

      final response = await ApiService.getSchedules(deviceId: _activeDeviceId);

      if (response['success'] == true) {
        setState(() {
          _schedules = response['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ [FLUTTER] Error load schedules: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSchedule(String id) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? Theme.of(context).cardColor : Colors.white,
        title: Text('Hapus Jadwal?',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A))),
        content: Text('Jadwal yang dihapus tidak dapat dikembalikan.',
            style:
                TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal',
                style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final response = await ApiService.deleteSchedule(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['success'] == true
                  ? 'Jadwal berhasil dihapus'
                  : response['message'] ?? 'Gagal menghapus'),
              backgroundColor: response['success'] == true
                  ? const Color(0xFF10B981)
                  : Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
          if (response['success'] == true) _loadSchedules();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  void _toggleScheduleOptimistic(String id, bool isActive, int index) {
    setState(() {
      _schedules[index]['isActive'] = isActive;
    });

    ApiService.updateSchedule(id, {'isActive': isActive}).catchError((e) {
      setState(() {
        _schedules[index]['isActive'] = !isActive;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Gagal mengubah status'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating),
      );
    });
  }

  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Jadwal Penyiraman',
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
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : _activeDeviceId == null
              ? _buildNoDeviceState(
                  isDark) // ✅ BARU: state kalau belum pilih device
              : _schedules.isEmpty
                  ? _buildEmptyState(isDark)
                  : RefreshIndicator(
                      onRefresh: _loadSchedules,
                      color: const Color(0xFF10B981),
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          // ✅ BARU: Banner info device aktif
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
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
                                    'Jadwal untuk: $_activeDeviceId',
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
                          // List jadwal
                          ..._schedules.asMap().entries.map((entry) {
                            final index = entry.key;
                            final schedule = entry.value;
                            return _buildScheduleCard(schedule, index, isDark);
                          }),
                        ],
                      ),
                    ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withOpacity(isDark ? 0.25 : 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddScheduleScreen()),
              ).then((_) => _loadSchedules());
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.add_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text('Tambah Jadwal',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ BARU: State kalau belum pilih device
  Widget _buildNoDeviceState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(isDark ? 0.15 : 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFF59E0B).withOpacity(isDark ? 0.3 : 0.2),
                width: 2,
              ),
            ),
            child: Icon(Icons.devices_rounded,
                size: 64,
                color:
                    isDark ? const Color(0xFFFCD34D) : const Color(0xFFF59E0B)),
          ),
          const SizedBox(height: 20),
          Text('Pilih Device Dahulu',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Silakan pilih device di Dashboard terlebih dahulu untuk melihat jadwal.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 13,
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(isDark ? 0.15 : 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF10B981).withOpacity(isDark ? 0.3 : 0.2),
                width: 2,
              ),
            ),
            child: Icon(Icons.schedule_rounded,
                size: 72,
                color:
                    isDark ? const Color(0xFF6EE7B7) : const Color(0xFF10B981)),
          ),
          const SizedBox(height: 24),
          Text(
            'Belum Ada Jadwal',
            style: TextStyle(
                fontSize: 20,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Atur jadwal penyiraman otomatis agar kebun Anda selalu terjaga.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 14,
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(dynamic schedule, int index, bool isDark) {
    final daysMap = {
      0: 'Minggu',
      1: 'Senin',
      2: 'Selasa',
      3: 'Rabu',
      4: 'Kamis',
      5: 'Jumat',
      6: 'Sabtu'
    };
    final daysList = schedule['days'] is List ? schedule['days'] as List : [];
    final daysText = daysList
        .map((d) {
          int dayInt = int.tryParse(d.toString()) ?? 0;
          return daysMap[dayInt] ?? '';
        })
        .where((d) => d.isNotEmpty)
        .join(', ');

    final isActive = schedule['isActive'] ?? false;
    final name = schedule['name'] ?? 'Tanpa Nama';
    final startTime = schedule['startTime'] ?? '00:00';
    final duration = schedule['durationMinutes'] ?? 5;
    final scheduleId = schedule['_id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isActive
                ? const Color(0xFF10B981).withOpacity(isDark ? 0.5 : 0.2)
                : (isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.grey.shade100)),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? const Color(0xFF10B981).withOpacity(isDark ? 0.2 : 0.1)
                : Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: isActive ? 16 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isActive
                          ? [const Color(0xFF10B981), const Color(0xFF059669)]
                          : isDark
                              ? [Colors.grey.shade700, Colors.grey.shade800]
                              : [Colors.grey.shade300, Colors.grey.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: isActive
                            ? const Color(0xFF10B981).withOpacity(0.3)
                            : Colors.grey.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.water_drop_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 14,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(startTime,
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(width: 12),
                          Icon(Icons.timer_outlined,
                              size: 14,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text('$duration Menit',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isActive,
                  onChanged: (val) =>
                      _toggleScheduleOptimistic(scheduleId, val, index),
                  activeColor: const Color(0xFF10B981),
                  activeTrackColor: const Color(0xFF10B981).withOpacity(0.4),
                  inactiveTrackColor:
                      isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
              ],
            ),
          ),
          if (daysText.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color:
                    const Color(0xFF10B981).withOpacity(isDark ? 0.10 : 0.05),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 14,
                      color: isActive
                          ? (isDark
                              ? const Color(0xFF6EE7B7)
                              : const Color(0xFF059669))
                          : (isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade500)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      daysText,
                      style: TextStyle(
                        color: isActive
                            ? (isDark
                                ? const Color(0xFFA7F3D0)
                                : const Color(0xFF047857))
                            : (isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                EditScheduleScreen(schedule: schedule)),
                      ).then((_) => _loadSchedules());
                    },
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF3B82F6),
                      backgroundColor: const Color(0xFF3B82F6)
                          .withOpacity(isDark ? 0.15 : 0.08),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _deleteSchedule(scheduleId),
                    icon: const Icon(Icons.delete_rounded, size: 18),
                    label: const Text('Hapus'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      backgroundColor: const Color(0xFFEF4444)
                          .withOpacity(isDark ? 0.15 : 0.08),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
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

// ===== ADD SCHEDULE SCREEN =====
class AddScheduleScreen extends StatefulWidget {
  const AddScheduleScreen({Key? key}) : super(key: key);

  State<AddScheduleScreen> createState() => _AddScheduleScreenState();
}

class _AddScheduleScreenState extends State<AddScheduleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _durationController = TextEditingController(text: '5');

  String _startTime = '00:00';
  List<int> _selectedDays = [];
  bool _isSaving = false;

  final List<Map<String, dynamic>> _days = [
    {'value': 1, 'label': 'Sen'},
    {'value': 2, 'label': 'Sel'},
    {'value': 3, 'label': 'Rab'},
    {'value': 4, 'label': 'Kam'},
    {'value': 5, 'label': 'Jum'},
    {'value': 6, 'label': 'Sab'},
    {'value': 0, 'label': 'Min'},
  ];

  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Tambah Jadwal',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
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
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoCard(isDark),
              const SizedBox(height: 24),
              _buildTextField(_nameController, 'Nama Jadwal',
                  'Contoh: Penyiraman Pagi', Icons.edit_note_rounded, isDark,
                  validator: (val) => (val == null || val.trim().isEmpty)
                      ? 'Nama wajib diisi'
                      : null),
              const SizedBox(height: 16),
              _buildTimePicker(isDark),
              const SizedBox(height: 16),
              _buildTextField(_durationController, 'Durasi (Menit)', '5',
                  Icons.timer_outlined, isDark,
                  keyboardType: TextInputType.number, validator: (val) {
                if (val == null || val.isEmpty) return 'Durasi wajib diisi';
                if (int.tryParse(val) == null) return 'Harus berupa angka';
                if (int.parse(val) <= 0) return 'Minimal 1 menit';
                return null;
              }),
              const SizedBox(height: 24),
              Text('Ulangi Setiap Hari',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A))),
              const SizedBox(height: 12),
              _buildDaySelector(isDark),
              const SizedBox(height: 32),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withOpacity(isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFF3B82F6).withOpacity(isDark ? 0.35 : 0.2))),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(isDark ? 0.25 : 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.info_outline_rounded,
              color: Color(0xFF3B82F6), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(
                'Jadwal ini berjalan berdasarkan WAKTU. Untuk penyiraman otomatis berdasarkan Sensor, gunakan menu Threshold.',
                style: TextStyle(
                    color: isDark
                        ? const Color(0xFF93C5FD)
                        : const Color(0xFF3B82F6).withOpacity(0.9),
                    fontSize: 13,
                    height: 1.4))),
      ]),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      String hint, IconData icon, bool isDark,
      {TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
          fontSize: 15,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
            color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
            fontSize: 14,
            fontWeight: FontWeight.w500),
        hintStyle: TextStyle(
            color: isDark ? Colors.grey.shade600 : const Color(0xFF94A3B8),
            fontSize: 14),
        prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(icon, color: const Color(0xFF10B981), size: 20)),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.grey.shade200,
                width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.grey.shade200,
                width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF10B981), width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      validator: validator,
    );
  }

  Widget _buildTimePicker(bool isDark) {
    return InkWell(
      onTap: () async {
        final timeParts = _startTime.split(':');
        final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(
                hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1])),
            builder: (context, child) {
              return Theme(
                  data: Theme.of(context).copyWith(
                      colorScheme: isDark
                          ? const ColorScheme.dark(primary: Color(0xFF10B981))
                          : const ColorScheme.light(
                              primary: Color(0xFF10B981))),
                  child: child!);
            });
        if (time != null)
          setState(() => _startTime =
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.grey.shade200,
                width: 1.5)),
        child: Row(children: [
          const Icon(Icons.access_time_rounded,
              color: Color(0xFF10B981), size: 20),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Waktu Mulai',
                    style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade400
                            : const Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(_startTime,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark ? Colors.white : const Color(0xFF0F172A))),
              ])),
          Icon(Icons.chevron_right_rounded,
              size: 20,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
        ]),
      ),
    );
  }

  Widget _buildDaySelector(bool isDark) {
    return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _days.map((day) {
          final isSelected = _selectedDays.contains(day['value']);
          return GestureDetector(
            onTap: () => setState(() {
              if (isSelected)
                _selectedDays.remove(day['value']);
              else
                _selectedDays.add(day['value']);
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF10B981)
                    : (isDark ? Colors.white.withOpacity(0.04) : Colors.white),
                shape: BoxShape.circle,
                border: Border.all(
                    color: isSelected
                        ? const Color(0xFF10B981)
                        : (isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.grey.shade300),
                    width: 1.5),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4))
                      ]
                    : null,
              ),
              child: Center(
                  child: Text(day['label']!,
                      style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600),
                          fontWeight: FontWeight.bold,
                          fontSize: 13))),
            ),
          );
        }).toList());
  }

  Widget _buildSaveButton() {
    return Container(
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
        onPressed: _isSaving ? null : _saveSchedule,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : const Icon(Icons.save_rounded, color: Colors.white),
        label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Jadwal',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0),
      ),
    );
  }

  Future<void> _saveSchedule() async {
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pilih minimal 1 hari'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating));
      return;
    }
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      try {
        final deviceProvider =
            Provider.of<DeviceProvider>(context, listen: false);
        final currentDeviceId = deviceProvider.selectedDevice?.deviceId;

        if (currentDeviceId == null || currentDeviceId.isEmpty) {
          throw Exception('Pilih device terlebih dahulu di Dashboard!');
        }

        final response = await ApiService.createSchedule({
          'name': _nameController.text,
          'startTime': _startTime,
          'durationMinutes': int.parse(_durationController.text),
          'days': _selectedDays,
          'isActive': true,
          'deviceId': currentDeviceId,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(response['success'] == true
                  ? 'Jadwal berhasil disimpan!'
                  : response['message'] ?? 'Gagal'),
              backgroundColor: response['success'] == true
                  ? const Color(0xFF10B981)
                  : Colors.red,
              behavior: SnackBarBehavior.floating));
          if (response['success'] == true) Navigator.pop(context);
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red));
      } finally {
        setState(() => _isSaving = false);
      }
    }
  }

  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    super.dispose();
  }
}

// ===== EDIT SCHEDULE SCREEN =====
class EditScheduleScreen extends StatefulWidget {
  final dynamic schedule;
  const EditScheduleScreen({Key? key, required this.schedule})
      : super(key: key);

  State<EditScheduleScreen> createState() => _EditScheduleScreenState();
}

class _EditScheduleScreenState extends State<EditScheduleScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _durationController;
  late String _startTime;
  late List<int> _selectedDays;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _days = [
    {'value': 1, 'label': 'Sen'},
    {'value': 2, 'label': 'Sel'},
    {'value': 3, 'label': 'Rab'},
    {'value': 4, 'label': 'Kam'},
    {'value': 5, 'label': 'Jum'},
    {'value': 6, 'label': 'Sab'},
    {'value': 0, 'label': 'Min'},
  ];

  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.schedule['name'] ?? '');
    _startTime = widget.schedule['startTime'] ?? '00:00';
    _durationController = TextEditingController(
        text: (widget.schedule['durationMinutes'] ?? 5).toString());

    final daysData = widget.schedule['days'];
    _selectedDays = daysData is List
        ? daysData.map((e) => int.tryParse(e.toString()) ?? 0).toList()
        : [];
  }

  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Edit Jadwal',
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
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF3B82F6).withOpacity(isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFF3B82F6)
                          .withOpacity(isDark ? 0.35 : 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6)
                            .withOpacity(isDark ? 0.25 : 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.info_outline_rounded,
                          color: Color(0xFF3B82F6), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ubah jadwal penyiraman sesuai kebutuhan Anda.',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFF93C5FD)
                              : const Color(0xFF3B82F6).withOpacity(0.9),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildTextField(
                _nameController,
                'Nama Jadwal',
                'Contoh: Penyiraman Pagi',
                Icons.edit_note_rounded,
                isDark,
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Nama wajib diisi'
                    : null,
              ),
              const SizedBox(height: 16),
              _buildTimePicker(isDark),
              const SizedBox(height: 16),
              _buildTextField(
                _durationController,
                'Durasi (Menit)',
                '5',
                Icons.timer_outlined,
                isDark,
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Durasi wajib diisi';
                  if (int.tryParse(val) == null) return 'Harus berupa angka';
                  if (int.parse(val) <= 0) return 'Minimal 1 menit';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Ulangi Setiap Hari',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              _buildDaySelector(isDark),
              const SizedBox(height: 32),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      String hint, IconData icon, bool isDark,
      {TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
          fontSize: 15,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
            color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
            fontSize: 14,
            fontWeight: FontWeight.w500),
        hintStyle: TextStyle(
            color: isDark ? Colors.grey.shade600 : const Color(0xFF94A3B8),
            fontSize: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: Icon(icon, color: const Color(0xFF10B981), size: 20),
        ),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.grey.shade200,
              width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.grey.shade200,
              width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      validator: validator,
    );
  }

  Widget _buildTimePicker(bool isDark) {
    return InkWell(
      onTap: () async {
        final timeParts = _startTime.split(':');
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(
            hour: int.tryParse(timeParts[0]) ?? 0,
            minute: int.tryParse(timeParts[1]) ?? 0,
          ),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: isDark
                    ? const ColorScheme.dark(primary: Color(0xFF10B981))
                    : const ColorScheme.light(primary: Color(0xFF10B981)),
              ),
              child: child!,
            );
          },
        );
        if (time != null) {
          setState(() => _startTime =
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.grey.shade200,
              width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time_rounded,
                color: Color(0xFF10B981), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Waktu Mulai',
                      style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : const Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(_startTime,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySelector(bool isDark) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _days.map((day) {
        final isSelected = _selectedDays.contains(day['value']);
        return GestureDetector(
          onTap: () => setState(() {
            if (isSelected) {
              _selectedDays.remove(day['value']);
            } else {
              _selectedDays.add(day['value']);
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF10B981)
                  : (isDark ? Colors.white.withOpacity(0.04) : Colors.white),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF10B981)
                    : (isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.shade300),
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4))
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                day['label']!,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSaveButton() {
    return Container(
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
        onPressed: _isSaving ? null : _updateSchedule,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : const Icon(Icons.save_rounded, color: Colors.white),
        label: Text(
          _isSaving ? 'Menyimpan...' : 'Update Jadwal',
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }

  Future<void> _updateSchedule() async {
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal 1 hari'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      try {
        final deviceProvider =
            Provider.of<DeviceProvider>(context, listen: false);
        final currentDeviceId = deviceProvider.selectedDevice?.deviceId ??
            widget.schedule['deviceId'];

        final response = await ApiService.updateSchedule(
          widget.schedule['_id'],
          {
            'name': _nameController.text,
            'startTime': _startTime,
            'durationMinutes': int.parse(_durationController.text),
            'days': _selectedDays,
            'deviceId': currentDeviceId,
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['success'] == true
                  ? 'Jadwal berhasil diupdate!'
                  : response['message'] ?? 'Gagal'),
              backgroundColor: response['success'] == true
                  ? const Color(0xFF10B981)
                  : Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          if (response['success'] == true) Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: $e'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating),
          );
        }
      } finally {
        setState(() => _isSaving = false);
      }
    }
  }

  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    super.dispose();
  }
}
