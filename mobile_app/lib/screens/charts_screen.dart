import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../config/api_config.dart';
import '../providers/device_provider.dart';
import '../services/storage_service.dart';

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({Key? key}) : super(key: key);

  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  String _selectedRange = 'daily';
  List<FlSpot> _moistureSpots = [];
  List<FlSpot> _temperatureSpots = [];
  List<FlSpot> _phSpots = [];

  double _currentMoisture = 0.0;
  double _currentTemperature = 0.0;
  double _currentPh = 0.0;

  // Statistik tambahan untuk setiap sensor
  double _minMoisture = 0.0, _maxMoisture = 0.0, _avgMoisture = 0.0;
  double _minTemperature = 0.0, _maxTemperature = 0.0, _avgTemperature = 0.0;
  double _minPh = 0.0, _maxPh = 0.0, _avgPh = 0.0;

  bool _isLoading = true;
  int _dataLength = 0;
  DateTime? _lastUpdated;

  // Color palette yang lebih sophisticated
  static const Color _primaryGreen = Color.fromARGB(255, 93, 138, 123);
  static const Color _accentBlue = Color(0xFF3B82F6);
  static const Color _accentOrange = Color(0xFFF97316);
  static const Color _accentPurple = Color(0xFFA855F7);
  static const Color _bgLight = Color(0xFFF8FAFC);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistoricalData();
      // Auto-refresh setiap 30 detik
      _startAutoRefresh();
    });
  }

  void _startAutoRefresh() {
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _loadHistoricalData();
        _startAutoRefresh();
      }
    });
  }

  Future<void> _loadHistoricalData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    final token = authService.user?.token;

    // ✅ Filter by deviceId untuk multi-device support
    final deviceId = deviceProvider.selectedDevice?.deviceId;

    // ✅ PAKAI ENDPOINT /aggregate (rata-rata per interval: 5m/1h/1d)
    // Ini membuat grafik 24 jam / 7 hari / 30 hari benar-benar mewakili
    // SELURUH rentang, bukan cuma 1000 sampel pertama.
    // Format response tetap sama (moisture, temperature, ph) → parsing kompatibel.
    final aggregatePath =
        ApiConfig.endpointSensorsHistory.replaceFirst('/history', '/aggregate');
    String url = '${ApiConfig.baseUrl}$aggregatePath?range=$_selectedRange';
    if (deviceId != null && deviceId.isNotEmpty) {
      url += '&deviceId=${Uri.encodeComponent(deviceId)}';
    }

    debugPrint('📊 [CHARTS] Memuat data: $url');

    try {
      // ✅ BARU: sertakan token dari storage
      final token = await StorageService.getToken();
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      debugPrint('📊 [CHARTS] Response status: ${response.statusCode}');

      if (response.statusCode == 200 && mounted) {
        final responseData = json.decode(response.body);

        // ✅ Cek success flag dari backend
        if (responseData['success'] != true) {
          debugPrint('❌ [CHARTS] Backend return success=false');
          setState(() => _isLoading = false);
          return;
        }

        final data = responseData['data'] as List;
        _dataLength = data.length;
        _lastUpdated = DateTime.now();

        debugPrint('📊 [CHARTS] Data diterima: ${data.length} titik');

        if (data.isEmpty) {
          _moistureSpots = [];
          _temperatureSpots = [];
          _phSpots = [];
          setState(() => _isLoading = false);
          return;
        }

        // Parse data untuk charts (kompatibel dengan response /aggregate)
        _moistureSpots = data
            .asMap()
            .entries
            .map((e) => FlSpot(
                e.key.toDouble(), (e.value['moisture'] as num).toDouble()))
            .toList();
        _temperatureSpots = data
            .asMap()
            .entries
            .map((e) => FlSpot(
                e.key.toDouble(), (e.value['temperature'] as num).toDouble()))
            .toList();
        _phSpots = data
            .asMap()
            .entries
            .map((e) =>
                FlSpot(e.key.toDouble(), (e.value['ph'] as num).toDouble()))
            .toList();

        // Hitung statistik
        _calculateStatistics(data);

        setState(() => _isLoading = false);
      } else {
        debugPrint('❌ [CHARTS] HTTP Error: ${response.statusCode}');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ [CHARTS] Network Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateStatistics(List<dynamic> data) {
    if (data.isEmpty) return;

    // Moisture stats
    final moistures =
        data.map((d) => (d['moisture'] as num).toDouble()).toList();
    _currentMoisture = moistures.last;
    _minMoisture = moistures.reduce((a, b) => a < b ? a : b);
    _maxMoisture = moistures.reduce((a, b) => a > b ? a : b);
    _avgMoisture = moistures.reduce((a, b) => a + b) / moistures.length;

    // Temperature stats
    final temperatures =
        data.map((d) => (d['temperature'] as num).toDouble()).toList();
    _currentTemperature = temperatures.last;
    _minTemperature = temperatures.reduce((a, b) => a < b ? a : b);
    _maxTemperature = temperatures.reduce((a, b) => a > b ? a : b);
    _avgTemperature =
        temperatures.reduce((a, b) => a + b) / temperatures.length;

    // pH stats
    final phs = data.map((d) => (d['ph'] as num).toDouble()).toList();
    _currentPh = phs.last;
    _minPh = phs.reduce((a, b) => a < b ? a : b);
    _maxPh = phs.reduce((a, b) => a > b ? a : b);
    _avgPh = phs.reduce((a, b) => a + b) / phs.length;
  }

  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deviceProvider = Provider.of<DeviceProvider>(context);

    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Analitik Sensor',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: Colors.white)),
            if (deviceProvider.selectedDevice != null)
              Text(
                deviceProvider.selectedDevice!.deviceName,
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500),
              ),
          ],
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadHistoricalData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistoricalData,
        color: _primaryGreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time Range Selector
              _buildTimeRangeSelector(isDark),
              const SizedBox(height: 20),

              // Data Summary Card
              _buildDataSummaryCard(isDark),
              const SizedBox(height: 24),

              // Charts
              if (_isLoading)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator()))
              else if (_moistureSpots.isEmpty)
                _buildEmptyState(isDark)
              else
                Column(
                  children: [
                    _buildChartCard(
                      title: 'Kelembaban Tanah',
                      subtitle: 'Soil Moisture Level',
                      icon: Icons.water_drop,
                      color: _accentBlue,
                      spots: _moistureSpots,
                      unit: '%',
                      currentValue: _currentMoisture,
                      minValue: _minMoisture,
                      maxValue: _maxMoisture,
                      avgValue: _avgMoisture,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 20),
                    _buildChartCard(
                      title: 'Suhu Tanah',
                      subtitle: 'Soil Temperature',
                      icon: Icons.thermostat,
                      color: _accentOrange,
                      spots: _temperatureSpots,
                      unit: '°C',
                      currentValue: _currentTemperature,
                      minValue: _minTemperature,
                      maxValue: _maxTemperature,
                      avgValue: _avgTemperature,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 20),
                    _buildChartCard(
                      title: 'pH Tanah',
                      subtitle: 'Soil Acidity Level',
                      icon: Icons.science,
                      color: _accentPurple,
                      spots: _phSpots,
                      unit: 'pH',
                      currentValue: _currentPh,
                      minValue: _minPh,
                      maxValue: _maxPh,
                      avgValue: _avgPh,
                      isDark: isDark,
                    ),
                  ],
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTimeSegment('24 Jam', 'daily', isDark),
          _buildTimeSegment('7 Hari', 'weekly', isDark),
          _buildTimeSegment('30 Hari', 'monthly', isDark),
        ],
      ),
    );
  }

  Widget _buildTimeSegment(String label, String range, bool isDark) {
    final isSelected = _selectedRange == range;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedRange != range) {
            setState(() => _selectedRange = range);
            _loadHistoricalData();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataSummaryCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.info_outline, color: _primaryGreen, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data Historis',
                  style: TextStyle(
                    color: isDark ? Colors.white : _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _lastUpdated != null
                      ? 'Terakhir diperbarui: ${DateFormat('HH:mm').format(_lastUpdated!)}'
                      : 'Memuat data...',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : _textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_dataLength > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_dataLength titik',
                style: const TextStyle(
                  color: _primaryGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Belum Ada Data',
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : _textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Data sensor akan muncul di sini setelah perangkat mengirim data',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.grey.shade500 : _textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<FlSpot> spots,
    required String unit,
    required double currentValue,
    required double minValue,
    required double maxValue,
    required double avgValue,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header dengan current value
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : _textPrimary,
                        )),
                    Text(subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade500 : _textSecondary,
                          fontWeight: FontWeight.w500,
                        )),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text('Saat Ini',
                        style: TextStyle(
                          fontSize: 9,
                          color: color.withOpacity(0.8),
                          fontWeight: FontWeight.w600,
                        )),
                    Text('${currentValue.toStringAsFixed(1)}$unit',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Chart
          SizedBox(
            height: 200,
            child: LineChart(_buildChartData(color, spots, isDark)),
          ),
          const SizedBox(height: 16),

          // Statistik min/max/avg
          Row(
            children: [
              Expanded(
                child: _buildStatChip('Min', minValue, unit, color, isDark),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatChip('Avg', avgValue, unit, color, isDark),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatChip('Max', maxValue, unit, color, isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
      String label, double value, String unit, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade700 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.grey.shade400 : _textSecondary,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 2),
          Text('${value.toStringAsFixed(1)}$unit',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : _textPrimary,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }

  LineChartData _buildChartData(Color color, List<FlSpot> spots, bool isDark) {
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) => FlLine(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
          strokeWidth: 1,
          dashArray: [4, 4],
        ),
      ),
      titlesData: FlTitlesData(
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                value.toStringAsFixed(0),
                style: TextStyle(
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (value, meta) {
              String label = '';
              if (value == 0)
                label = 'Awal';
              else if (value == meta.max)
                label = 'Akhir';
              else if (value == meta.max / 2) label = 'Tengah';

              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: isDark ? Colors.grey.shade800 : Colors.white,
          tooltipRoundedRadius: 8,
          tooltipPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          tooltipBorder: BorderSide(color: color.withOpacity(0.3), width: 1),
          getTooltipItems: (touchedSpots) => touchedSpots
              .map((spot) => LineTooltipItem(
                    '${spot.y.toStringAsFixed(1)}',
                    TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ))
              .toList(),
        ),
        handleBuiltInTouches: true,
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.4,
          color: color,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withOpacity(0.15), color.withOpacity(0.0)],
            ),
          ),
        ),
      ],
    );
  }
}
