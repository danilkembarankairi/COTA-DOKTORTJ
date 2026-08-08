import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/mqtt_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../widgets/sensor_card.dart';
import '../widgets/pump_control_card.dart';
import 'charts_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';
import 'notification_screen.dart';
import 'device_management_screen.dart';
import '../providers/theme_provider.dart';
import '../providers/device_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  StreamSubscription? _mqttSubscription;

  int _unreadNotifications = 0;

  final List<Map<String, dynamic>> _notificationHistory = [];

  String? _syncedDeviceId;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _gradientController;
  late Animation<double> _gradientAnimation;

  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 1.0, end: 1.15).animate(_pulseController);

    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _gradientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _gradientController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final deviceProvider =
          Provider.of<DeviceProvider>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final mqttService = Provider.of<MQTTService>(context, listen: false);

      await deviceProvider.fetchDevices(authService);

      if (deviceProvider.selectedDevice != null) {
        debugPrint(
            "📱 [DEBUG] Selected Device NAME: ${deviceProvider.selectedDevice!.deviceName}");
        debugPrint(
            "📱 [DEBUG] Selected Device ID: ${deviceProvider.selectedDevice!.deviceId}");
        debugPrint(
            "📱 [DEBUG] Selected Device .id: ${deviceProvider.selectedDevice!.id}");

        mqttService.setCurrentDevice(deviceProvider.selectedDevice!.deviceId);
      } else {
        debugPrint("❌ [DEBUG] selectedDevice is NULL!");
      }

      mqttService.connect();
      _listenToMqttNotifications();
    });
  }

  void dispose() {
    _pulseController.dispose();
    _gradientController.dispose();
    _mqttSubscription?.cancel();
    super.dispose();
  }

  void _listenToMqttNotifications() {
    final mqttService = Provider.of<MQTTService>(context, listen: false);

    _mqttSubscription = mqttService.messageStream.listen((message) {
      if (message['topic'].toString().contains('/notifications')) {
        try {
          final payload = message['payload'];
          if (payload == null) return;

          final data = jsonDecode(payload);
          final type = (data['type'] ?? data['TYPE'] ?? 'warning')
              .toString()
              .toLowerCase();
          final msg = data['message'] ?? data['MESSAGE'] ?? 'Tidak ada pesan';

          debugPrint("📝 Notifikasi Diterima -> Tipe: $type, Pesan: $msg");

          setState(() {
            _notificationHistory.insert(0, {
              'type': type,
              'message': msg,
              'time': DateTime.now(),
            });
            if (type == 'warning' || type == 'error') {
              _unreadNotifications++;
            }
          });

          _showSystemNotification(type, msg);
        } catch (e) {
          debugPrint("❌ Gagal parse notifikasi: $e");
        }
      }
    });
  }

  void _showSystemNotification(String type, String msg) {
    String title = '✅ Kondisi Normal';
    Color bgColor = const Color(0xFF10B981);

    if (type == 'warning') {
      title = '⚠️ Peringatan Sistem';
      bgColor = const Color(0xFFF59E0B);
    } else if (type == 'error') {
      title = '🚨 Error Kritis';
      bgColor = const Color(0xFFEF4444);
    }

    NotificationService.showNotification(
      title: title,
      body: msg,
      payload: type,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                type == 'error'
                    ? Icons.error_outline
                    : (type == 'warning'
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline),
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    msg,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    debugPrint("🔔 Notifikasi sistem dipicu: $msg");
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  IconData _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) return Icons.wb_sunny_rounded;
    if (hour < 15) return Icons.wb_sunny_outlined;
    if (hour < 18) return Icons.cloud_outlined;
    return Icons.nightlight_round;
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now);
  }

  Widget build(BuildContext context) {
    final mqttService = Provider.of<MQTTService>(context);
    final authService = Provider.of<AuthService>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final lastMsgTime = mqttService.lastMessageTime;
    final bool hasRealData = lastMsgTime != null &&
        DateTime.now().difference(lastMsgTime).inSeconds < 15;

    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildPremiumAppBar(authService, mqttService, isDark, hasRealData),
          Consumer2<DeviceProvider, MQTTService>(
            builder: (context, deviceProvider, mqttServiceConsumer, child) {
              if (deviceProvider.isLoading) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final selectedDevice = deviceProvider.selectedDevice;

              // ✅ SYNC: filter MQTT DIPAKSA mengikuti device terpilih
              final selectedId = selectedDevice?.deviceId;
              if (selectedId != null && selectedId != _syncedDeviceId) {
                _syncedDeviceId = selectedId;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    mqttServiceConsumer.setCurrentDevice(selectedId);
                  }
                });
              }

              if (selectedDevice == null) {
                return _buildEmptyState(isDark);
              }
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusCard(
                          mqttServiceConsumer, isDark, hasRealData),
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                          title: 'Ringkasan Kebun', icon: Icons.eco_outlined),
                      const SizedBox(height: 16),
                      _buildQuickStats(
                          mqttServiceConsumer, isDark, hasRealData),
                      const SizedBox(height: 32),
                      _buildSectionHeader(
                          title: 'Kontrol Irigasi',
                          icon: Icons.water_drop_outlined),
                      const SizedBox(height: 16),
                      PumpControlCard(
                        isOn: mqttServiceConsumer.isPumpOn,
                        onToggle: () {
                          if (!mqttServiceConsumer.isConnected) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Tidak terhubung ke Cloud. Periksa koneksi internet.'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }

                          if (!mqttServiceConsumer.isDeviceOnline) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    '⚠️ Perangkat Offline! Tidak dapat mengontrol pompa. Cek listrik atau WiFi.'),
                                backgroundColor: Colors.orange,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }

                          mqttServiceConsumer
                              .controlPump(!mqttServiceConsumer.isPumpOn);
                        },
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader(
                              title: 'Sensor Real-Time',
                              icon: Icons.sensors_outlined),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: hasRealData
                                ? _buildLiveBadge()
                                : _buildNoDataBadge(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.95,
                        children: [
                          SensorCard(
                            title: 'Kelembaban',
                            value: hasRealData
                                ? mqttServiceConsumer.soilMoisture
                                    .toStringAsFixed(1)
                                : '0.0',
                            unit: '%',
                            icon: Icons.water_drop,
                            color: const Color(0xFF3B82F6),
                            progress: hasRealData
                                ? mqttServiceConsumer.soilMoisture / 100
                                : 0,
                            status: !hasRealData
                                ? 'Menunggu'
                                : (mqttServiceConsumer.soilMoisture < 30
                                    ? 'Kering'
                                    : (mqttServiceConsumer.soilMoisture < 60
                                        ? 'Normal'
                                        : 'Basah')),
                          ),
                          SensorCard(
                            title: 'Suhu',
                            value: hasRealData
                                ? mqttServiceConsumer.temperature
                                    .toStringAsFixed(1)
                                : '0.0',
                            unit: '°C',
                            icon: Icons.thermostat,
                            color: const Color(0xFFF97316),
                            progress: hasRealData
                                ? mqttServiceConsumer.temperature / 50
                                : 0,
                            status: !hasRealData
                                ? 'Menunggu'
                                : (mqttServiceConsumer.temperature < 20
                                    ? 'Dingin'
                                    : (mqttServiceConsumer.temperature < 35
                                        ? 'Normal'
                                        : 'Panas')),
                          ),
                          SensorCard(
                            title: 'pH Tanah',
                            value: hasRealData
                                ? mqttServiceConsumer.ph.toStringAsFixed(1)
                                : '0.0',
                            unit: 'pH',
                            icon: Icons.science,
                            color: const Color(0xFFA855F7),
                            progress:
                                hasRealData ? mqttServiceConsumer.ph / 14 : 0,
                            status: !hasRealData
                                ? 'Menunggu'
                                : ((mqttServiceConsumer.ph >= 5.5 &&
                                        mqttServiceConsumer.ph <= 6.5)
                                    ? 'Ideal'
                                    : 'Tidak Ideal'),
                          ),
                          _buildChartCard(),
                        ],
                      ),
                      const SizedBox(height: 25),
                      _buildScheduleButton(),
                      const SizedBox(height: 1),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return SliverFillRemaining(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFFF8FAFC), Colors.white],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.2),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.agriculture_outlined,
                          size: 64,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                Text(
                  'Belum Ada Device Dipilih',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    'Silakan pilih atau tambahkan device untuk mulai memantau dan mengontrol kebun Anda secara real-time.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color:
                          isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DeviceManagementScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_circle_outline, size: 22),
                    label: const Text(
                      'Tambah Device Baru',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.3,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DeviceManagementScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'Lihat Semua Device',
                    style: TextStyle(
                      color:
                          isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumAppBar(
    AuthService authService,
    MQTTService mqttService,
    bool isDark,
    bool hasRealData,
  ) {
    // ============================================================
    // COTA PREMIUM APP BAR
    // Tema disinkronkan dengan Settings:
    // Light : Emerald Green
    // Dark  : Deep Emerald
    // ============================================================

    final List<Color> gradientColors = isDark
        ? [
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
          ];

    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,

      // ============================================================
      // BASE COLOR
      // ============================================================
      backgroundColor:
          isDark ? const Color(0xFF022C22) : const Color(0xFF047857),

      elevation: 0,

      flexibleSpace: FlexibleSpaceBar(
        background: AnimatedBuilder(
          animation: _gradientAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                // ==================================================
                // MAIN GRADIENT
                // ==================================================
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),

                // ==================================================
                // SOFT GREEN GLOW
                // ==================================================
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(
                      isDark ? 0.12 : 0.30,
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // ==================================================
                  // SUBTLE GRID PATTERN
                  // ==================================================
                  Positioned.fill(
                    child: Opacity(
                      opacity: isDark ? 0.035 : 0.05,
                      child: CustomPaint(
                        painter: _GridPatternPainter(),
                      ),
                    ),
                  ),

                  // ==================================================
                  // TOP RIGHT DECORATIVE CIRCLE
                  // ==================================================
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
                                Colors.white.withOpacity(
                                  isDark ? 0.08 : 0.12,
                                ),
                                Colors.white.withOpacity(
                                  isDark ? 0.035 : 0.08,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // ==================================================
                  // BOTTOM LEFT DECORATIVE CIRCLE
                  // ==================================================
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
                                Colors.white.withOpacity(
                                  isDark ? 0.055 : 0.08,
                                ),
                                Colors.white.withOpacity(
                                  isDark ? 0.025 : 0.05,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // ==================================================
                  // CONTENT
                  // ==================================================
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        16,
                        20,
                        20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ==================================================
                          // TOP ROW
                          // LOGO + USER INFO + ACTION BUTTONS
                          // ==================================================
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // ==================================================
                              // LOGO + USER INFO
                              // ==================================================
                              Expanded(
                                child: Row(
                                  children: [
                                    // ==================================================
                                    // COTA LOGO
                                    // ==================================================
                                    SizedBox(
                                      width: 80,
                                      height: 80,
                                      child: Image.asset(
                                        'assets/logo_cota.png',
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return const Center(
                                            child: Icon(
                                              Icons.eco,
                                              color: Color(0xFF10B981),
                                              size: 28,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 14),

                                    // ==================================================
                                    // USER INFORMATION
                                    // ==================================================
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // ==================================================
                                          // GREETING
                                          // ==================================================
                                          Row(
                                            children: [
                                              Icon(
                                                _getGreetingIcon(),
                                                color: Colors.white
                                                    .withOpacity(0.95),
                                                size: 14,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _getGreeting(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 4),

                                          // ==================================================
                                          // USER NAME
                                          // ==================================================
                                          Text(
                                            authService.user?.name ?? 'User',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.2,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),

                                          // ==================================================
                                          // SELECTED DEVICE
                                          // ==================================================
                                          Consumer<DeviceProvider>(
                                            builder: (
                                              context,
                                              deviceProvider,
                                              child,
                                            ) {
                                              if (deviceProvider
                                                      .selectedDevice ==
                                                  null) {
                                                return const SizedBox.shrink();
                                              }

                                              // Ambil device terbaru dari list
                                              final selected = deviceProvider
                                                  .selectedDevice!;

                                              final freshName =
                                                  deviceProvider.devices
                                                      .firstWhere(
                                                        (d) =>
                                                            d.id == selected.id,
                                                        orElse: () => selected,
                                                      )
                                                      .deviceName;

                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 4,
                                                ),
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withOpacity(0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withOpacity(0.3),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      // ==================================================
                                                      // DEVICE ONLINE PULSE
                                                      // ==================================================
                                                      AnimatedBuilder(
                                                        animation:
                                                            _pulseController,
                                                        builder:
                                                            (context, child) {
                                                          final isPulse =
                                                              _pulseAnimation
                                                                      .value >
                                                                  1.075;

                                                          return Container(
                                                            width: 6,
                                                            height: 6,
                                                            decoration:
                                                                BoxDecoration(
                                                              color: isPulse
                                                                  ? const Color(
                                                                      0xFF34D399)
                                                                  : const Color(
                                                                      0xFF10B981),
                                                              shape: BoxShape
                                                                  .circle,
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color:
                                                                      const Color(
                                                                    0xFF34D399,
                                                                  ).withOpacity(
                                                                    0.6,
                                                                  ),
                                                                  blurRadius: 4,
                                                                  spreadRadius:
                                                                      1,
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        },
                                                      ),

                                                      const SizedBox(
                                                        width: 6,
                                                      ),

                                                      Flexible(
                                                        child: Text(
                                                          freshName,
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 8),

                              // ==================================================
                              // ACTION BUTTONS
                              // DEVICE / NOTIFICATION / SETTINGS
                              // ==================================================
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // DEVICE
                                  Consumer<DeviceProvider>(
                                    builder: (
                                      context,
                                      deviceProvider,
                                      child,
                                    ) {
                                      return _buildGlassIconButton(
                                        icon: Icons.devices_outlined,
                                        onTap: () => _showDeviceSelector(
                                          context,
                                          deviceProvider,
                                        ),
                                      );
                                    },
                                  ),

                                  const SizedBox(width: 8),

                                  // NOTIFICATION
                                  _buildGlassIconButton(
                                    icon: Icons.notifications_outlined,
                                    badge: _unreadNotifications > 0
                                        ? _unreadNotifications
                                        : null,
                                    onTap: () {
                                      setState(() {
                                        _unreadNotifications = 0;
                                      });

                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              NotificationHistoryScreen(
                                            history: _notificationHistory,
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  const SizedBox(width: 8),

                                  // SETTINGS
                                  _buildGlassIconButton(
                                    icon: Icons.settings_outlined,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const SettingsScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const Spacer(),

                          // ==================================================
                          // SENSOR STATUS
                          // ==================================================
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(
                                isDark ? 0.18 : 0.15,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hasRealData
                                      ? Icons.sensors_rounded
                                      : Icons.cloud_off_rounded,
                                  color: hasRealData
                                      ? const Color(0xFF34D399)
                                      : Colors.white70,
                                  size: 13,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  hasRealData
                                      ? 'Sensor Aktif'
                                      : 'Menunggu Data Alat...',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
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
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
    int? badge,
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
        child: Stack(
          children: [
            Center(child: Icon(icon, color: Colors.white, size: 20)),
            if (badge != null)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  constraints:
                      const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withOpacity(0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text('$badge',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDeviceSelector(
      BuildContext context, DeviceProvider deviceProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.devices,
                          color: Color(0xFF10B981), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilih Device',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        Text(
                          '${deviceProvider.devices.length} device terdaftar',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: deviceProvider.devices.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.devices_other,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Belum ada device terdaftar',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: deviceProvider.devices.length,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemBuilder: (context, index) {
                          final device = deviceProvider.devices[index];
                          final isSelected =
                              device.id == deviceProvider.selectedDevice?.id;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  deviceProvider.selectDevice(device);
                                  final mqttService = Provider.of<MQTTService>(
                                      context,
                                      listen: false);
                                  mqttService.setCurrentDevice(device.deviceId);
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF10B981)
                                            .withOpacity(0.1)
                                        : Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF10B981)
                                          : Colors.grey.withOpacity(0.2),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFF10B981)
                                                  .withOpacity(0.2)
                                              : Colors.grey.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.memory,
                                          color: isSelected
                                              ? const Color(0xFF10B981)
                                              : Colors.grey,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              device.deviceName,
                                              style: TextStyle(
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.w600,
                                                fontSize: 14,
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.color,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              device.location.isNotEmpty
                                                  ? device.location
                                                  : 'Lokasi tidak diatur',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF10B981),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DeviceManagementScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    label: const Text(
                      'Tambah Device Baru',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader({required String title, required IconData icon}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF10B981).withOpacity(0.18),
                const Color(0xFF10B981).withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF10B981), size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).textTheme.bodyLarge?.color,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildLiveBadge() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        // ✅ Pakai _pulseAnimation (1.0 – 1.15), bukan controller mentah
        final pulse = _pulseAnimation.value;
        return Container(
          key: const ValueKey('live'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      // ✅ clamp biar tidak pernah keluar 0..1
                      color: const Color(0xFF10B981).withOpacity(
                          (0.3 + (pulse - 1.0) * 2).clamp(0.0, 1.0)),
                      blurRadius: 6,
                      spreadRadius: pulse > 1.075 ? 1.5 : 0.5,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Text('LIVE',
                  style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoDataBadge() {
    return Container(
      key: const ValueKey('nodata'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.signal_cellular_off, color: Colors.grey, size: 12),
          SizedBox(width: 6),
          Text('NO DATA',
              style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
      MQTTService mqttService, bool isDark, bool hasRealData) {
    final isConnected = mqttService.isConnected;
    final isPumpRunning = mqttService.isPumpOn;

    final statusColor = hasRealData
        ? const Color(0xFF10B981)
        : isConnected
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    final statusText = hasRealData
        ? 'Terhubung ke Perangkat'
        : isConnected
            ? 'MQTT Online, Perangkat Offline'
            : 'Terputus dari Cloud';

    final subtitle = hasRealData
        ? 'Data sensor real-time sedang diterima.'
        : isConnected
            ? 'Broker aktif, tetapi alat belum mengirim data > 15 detik.'
            : 'Periksa koneksi internet atau status broker MQTT.';

    final statusIcon = hasRealData
        ? Icons.wifi_tethering_rounded
        : (isConnected
            ? Icons.router_rounded
            : Icons.portable_wifi_off_rounded);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? Theme.of(context).cardColor : Colors.white,
            isDark
                ? Theme.of(context).cardColor.withOpacity(0.95)
                : Colors.white.withOpacity(0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(isDark ? 0.15 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      statusColor.withOpacity(0.25),
                      statusColor.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(statusIcon, color: statusColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status Sistem',
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      statusText,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                          letterSpacing: -0.2),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusColor.withOpacity(0.15),
                      statusColor.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  hasRealData ? 'LIVE' : (isConnected ? 'ONLINE' : 'OFFLINE'),
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (isConnected) {
                  if (isPumpRunning) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            '⚠️ Matikan pompa terlebih dahulu sebelum memutus koneksi!'),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 3),
                      ),
                    );
                    return;
                  }

                  mqttService.disconnect();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Koneksi MQTT diputuskan manual'),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  mqttService.connect();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mencoba menghubungkan ke MQTT...'),
                      backgroundColor: Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              icon: Icon(
                  isConnected
                      ? Icons.power_settings_new_rounded
                      : Icons.refresh_rounded,
                  size: 18),
              label: Text(
                isConnected ? 'Putuskan Koneksi' : 'Hubungkan MQTT',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPumpRunning
                    ? Colors.red.shade100
                    : (isConnected
                        ? isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade100
                        : const Color(0xFF10B981)),
                foregroundColor: isPumpRunning
                    ? Colors.red.shade800
                    : (isConnected
                        ? isDark
                            ? Colors.grey.shade200
                            : Colors.grey.shade700
                        : Colors.white),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(
      MQTTService mqttService, bool isDark, bool hasRealData) {
    return Row(
      children: [
        Expanded(
          child: _buildQuickStatCard(
            icon: Icons.water_drop_outlined,
            label: 'Kelembaban',
            value: hasRealData
                ? '${mqttService.soilMoisture.toStringAsFixed(0)}%'
                : '0.0%',
            color: const Color(0xFF3B82F6),
            progress: hasRealData ? mqttService.soilMoisture / 100 : 0,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildQuickStatCard(
            icon: Icons.thermostat_outlined,
            label: 'Suhu',
            value: hasRealData
                ? '${mqttService.temperature.toStringAsFixed(1)}°C'
                : '0.0°C',
            color: const Color(0xFFF97316),
            progress: hasRealData ? mqttService.temperature / 50 : 0,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildQuickStatCard(
            icon: Icons.science_outlined,
            label: 'pH',
            value: hasRealData ? mqttService.ph.toStringAsFixed(1) : '0.0',
            color: const Color(0xFFA855F7),
            progress: hasRealData ? mqttService.ph / 14 : 0,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required double progress,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Theme.of(context).cardColor,
                  Theme.of(context).cardColor.withOpacity(0.95)
                ]
              : [Colors.white, Colors.white.withOpacity(0.98)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(isDark ? 0.15 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    color.withOpacity(0.2),
                    color.withOpacity(0.08)
                  ]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 11,
                fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF14B8A6),
              Color(0xFF0D9488),
              Color(0xFF0F766E),
            ]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF14B8A6).withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Stack(
        children: [
          Positioned(
              top: -20,
              right: -20,
              child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08)))),
          Positioned(
              bottom: -15,
              left: -15,
              child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06)))),
          Positioned(
              top: 40,
              right: 50,
              child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05)))),
          InkWell(
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ChartsScreen()));
            },
            borderRadius: BorderRadius.circular(18),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]),
                    child: const Icon(Icons.show_chart,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 14),
                  const Text('Lihat Grafik',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3)),
                  const SizedBox(height: 4),
                  Text('Analisis Tren',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF10B981),
              Color(0xFF059669),
              Color(0xFF047857),
            ]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF10B981).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ScheduleScreen()));
          },
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(
                right: 20,
                top: -30,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              Positioned(
                left: -20,
                bottom: -30,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.3), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]),
                      child: const Icon(Icons.schedule_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Text('Atur Jadwal Penyiraman',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3)),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
