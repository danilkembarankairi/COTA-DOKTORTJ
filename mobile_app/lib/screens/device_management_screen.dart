import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../services/auth_service.dart';
import '../services/mqtt_service.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({Key? key}) : super(key: key);

  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Manajemen Device',
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<DeviceProvider>(
        builder: (context, deviceProvider, child) {
          if (deviceProvider.isLoading) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF10B981)));
          }

          if (deviceProvider.devices.isEmpty) {
            return _buildEmptyState(isDark);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            physics: const BouncingScrollPhysics(),
            itemCount: deviceProvider.devices.length,
            itemBuilder: (context, index) {
              final device = deviceProvider.devices[index];
              final isActive = device.id == deviceProvider.selectedDevice?.id;

              return _buildDeviceCard(device, isActive, deviceProvider, isDark);
            },
          );
        },
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
            // ✅ FIX 1: FAB sekarang bisa diklik
            onTap: () => _showAddDeviceDialog(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.add_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text('Tambah Device',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🎨 EMPTY STATE (adaptif dark/light)
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
            child: Icon(Icons.devices_rounded,
                size: 72,
                color:
                    isDark ? const Color(0xFF6EE7B7) : const Color(0xFF10B981)),
          ),
          const SizedBox(height: 24),
          Text(
            'Belum Ada Device',
            style: TextStyle(
              fontSize: 20,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Tambahkan ESP32 Anda untuk mulai memantau dan mengontrol perangkat IoT.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showAddDeviceDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Device Pertama'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 DEVICE CARD (adaptif dark/light dengan detail premium)
  Widget _buildDeviceCard(DeviceModel device, bool isActive,
      DeviceProvider deviceProvider, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? const Color(0xFF10B981).withOpacity(isDark ? 0.5 : 0.3)
              : (isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.grey.shade200),
          width: isActive ? 2 : 1,
        ),
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
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isActive
                          ? [const Color(0xFF10B981), const Color(0xFF059669)]
                          : isDark
                              ? [Colors.grey.shade700, Colors.grey.shade800]
                              : [Colors.grey.shade300, Colors.grey.shade400],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981)
                                  .withOpacity(isDark ? 0.35 : 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: const Icon(Icons.memory_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              device.deviceName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF10B981),
                                    Color(0xFF059669)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle,
                                      color: Colors.white, size: 8),
                                  SizedBox(width: 4),
                                  Text(
                                    'Aktif',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.04)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          device.deviceId,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (device.location.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 14,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                device.location,
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                    fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                if (!isActive)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // ✅ Step 1: pilih device di provider
                        deviceProvider.selectDevice(device);

                        // ✅ Step 2: PAKSA filter MQTT mengikuti device ini
                        Provider.of<MQTTService>(context, listen: false)
                            .setCurrentDevice(device.deviceId);

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text('Device berhasil diaktifkan'),
                                ],
                              ),
                              backgroundColor: Color(0xFF10B981),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Aktifkan'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF10B981),
                        side: const BorderSide(color: Color(0xFF10B981)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                if (!isActive) const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showEditDeviceDialog(context, device),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF3B82F6),
                      backgroundColor: const Color(0xFF3B82F6)
                          .withOpacity(isDark ? 0.15 : 0.08),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showDeleteConfirmation(
                        context, device, deviceProvider),
                    icon: const Icon(Icons.delete_rounded, size: 18),
                    label: const Text('Hapus'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      backgroundColor: const Color(0xFFEF4444)
                          .withOpacity(isDark ? 0.15 : 0.08),
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

  // ✅ FIX 2: Launcher dialog yang aman (menggunakan StatefulWidget terpisah)
  void _showAddDeviceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _AddDeviceDialog(),
    );
  }

  void _showEditDeviceDialog(BuildContext context, DeviceModel device) {
    showDialog(
      context: context,
      builder: (_) => _EditDeviceDialog(device: device),
    );
  }

  // 🎨 DELETE CONFIRMATION (adaptif dark/light)
  void _showDeleteConfirmation(
      BuildContext context, DeviceModel device, DeviceProvider deviceProvider) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? Theme.of(context).cardColor : Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF7F1D1D), const Color(0xFF991B1B)]
                        : [const Color(0xFFFEE2E2), const Color(0xFFFECACA)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_forever_rounded,
                    color: Color(0xFFEF4444), size: 20),
              ),
              const SizedBox(width: 12),
              Text('Hapus Device?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  )),
            ],
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus device "${device.deviceName}"? Tindakan ini tidak dapat dibatalkan.',
            style: TextStyle(
              color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Batal',
                  style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final authService =
                      Provider.of<AuthService>(dialogContext, listen: false);

                  final success =
                      await deviceProvider.deleteDevice(authService, device.id);

                  if (mounted) {
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(
                              success
                                  ? Icons.check_circle_rounded
                                  : Icons.error_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(success
                                  ? 'Device berhasil dihapus'
                                  : 'Gagal menghapus device'),
                            ),
                          ],
                        ),
                        backgroundColor: success
                            ? const Color(0xFFEF4444)
                            : Colors.red.shade800,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text('Hapus',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void dispose() {
    super.dispose();
  }
}

// ==========================================
// 🎨 Helper field untuk dialog (adaptif dark/light)
// ==========================================
Widget _dialogField(
  BuildContext context,
  TextEditingController controller,
  String label,
  String? hint,
  IconData icon,
  String? Function(String?)? validator,
) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return TextFormField(
    controller: controller,
    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF10B981), size: 20),
      labelStyle: TextStyle(
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
      hintStyle: TextStyle(
          color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
      filled: true,
      fillColor:
          isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF10B981), width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    validator: validator,
  );
}

// ==========================================
// 🎨 DIALOG TAMBAH DEVICE (StatefulWidget = lifecycle controller aman)
// ==========================================
class _AddDeviceDialog extends StatefulWidget {
  const _AddDeviceDialog({Key? key}) : super(key: key);

  State<_AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<_AddDeviceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _deviceIdController = TextEditingController();
  final _deviceNameController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isProcessing = false;

  void dispose() {
    // ✅ Dispose otomatis saat dialog ditutup oleh Flutter — aman!
    _deviceIdController.dispose();
    _deviceNameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final deviceProvider =
          Provider.of<DeviceProvider>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);

      final success = await deviceProvider.registerDevice(
        authService,
        _deviceIdController.text.trim(),
        _deviceNameController.text.trim(),
        _locationController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(
        content: Row(children: [
          Icon(success ? Icons.check_circle_rounded : Icons.error_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(success
                  ? 'Device berhasil ditambahkan!'
                  : 'Gagal menambahkan device. Cek Device ID.')),
        ]),
        backgroundColor: success ? const Color(0xFF10B981) : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        messenger.showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? Theme.of(context).cardColor : Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.add_circle_outline,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text('Tambah Device Baru',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A))),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(
                  context,
                  _deviceIdController,
                  'Device ID ESP32',
                  'Contoh: ESP32_1434e3ec',
                  Icons.memory,
                  (val) =>
                      val!.trim().isEmpty ? 'Device ID wajib diisi' : null),
              const SizedBox(height: 16),
              _dialogField(
                  context,
                  _deviceNameController,
                  'Nama Device',
                  'Contoh: ESP32 Kebun',
                  Icons.label_outline,
                  (val) =>
                      val!.trim().isEmpty ? 'Nama device wajib diisi' : null),
              const SizedBox(height: 16),
              _dialogField(
                  context,
                  _locationController,
                  'Lokasi',
                  'Contoh: Kebun Belakang Rumah',
                  Icons.location_on_outlined,
                  null),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          child: Text('Batal',
              style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: _isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : const Text('Tambah',
                  style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// ==========================================
// 🎨 DIALOG EDIT DEVICE (StatefulWidget = lifecycle controller aman)
// ==========================================
class _EditDeviceDialog extends StatefulWidget {
  final DeviceModel device;
  const _EditDeviceDialog({Key? key, required this.device}) : super(key: key);

  State<_EditDeviceDialog> createState() => _EditDeviceDialogState();
}

class _EditDeviceDialogState extends State<_EditDeviceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _deviceNameController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isProcessing = false;

  void initState() {
    super.initState();
    _deviceNameController.text = widget.device.deviceName;
    _locationController.text = widget.device.location;
  }

  void dispose() {
    // ✅ Dispose otomatis saat dialog ditutup — aman!
    _deviceNameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final deviceProvider =
          Provider.of<DeviceProvider>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);

      final success = await deviceProvider.updateDevice(
        authService,
        widget.device.id,
        _deviceNameController.text.trim(),
        _locationController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(
        content: Row(children: [
          Icon(success ? Icons.check_circle_rounded : Icons.error_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(success
                  ? 'Device berhasil diupdate!'
                  : 'Gagal mengupdate device')),
        ]),
        backgroundColor: success ? const Color(0xFF10B981) : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        messenger.showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? Theme.of(context).cardColor : Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text('Edit Device',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A))),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🎨 Device ID read-only
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.04)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tag,
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey.shade600,
                        size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.device.deviceId,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _dialogField(
                  context,
                  _deviceNameController,
                  'Nama Device',
                  null,
                  Icons.label_outline,
                  (val) =>
                      val!.trim().isEmpty ? 'Nama device wajib diisi' : null),
              const SizedBox(height: 16),
              _dialogField(context, _locationController, 'Lokasi', null,
                  Icons.location_on_outlined, null),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          child: Text('Batal',
              style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: _isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : const Text('Simpan',
                  style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
