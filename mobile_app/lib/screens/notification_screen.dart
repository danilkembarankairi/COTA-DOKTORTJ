import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationHistoryScreen extends StatelessWidget {
  final List<Map<String, dynamic>> history;

  const NotificationHistoryScreen({Key? key, required this.history})
      : super(key: key);

  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF8FAFC),

      // ===== APP BAR SAMA SEPERTI CHARTS SCREEN =====
      appBar: AppBar(
        title: const Text(
          'Riwayat Notifikasi',
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

      body: history.isEmpty
          ? _buildEmptyState(isDark)
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final notif = history[index];
                final isWarning = notif['type'] == 'warning';
                final time = notif['time'] as DateTime;
                final message = notif['message'] ?? 'Tidak ada pesan';

                return _buildNotificationCard(
                  isWarning,
                  message,
                  time,
                  isDark,
                );
              },
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
              color: const Color(0xFF10B981).withOpacity(
                isDark ? 0.15 : 0.08,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF10B981).withOpacity(
                  isDark ? 0.3 : 0.2,
                ),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Belum Ada Notifikasi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Semua sistem berjalan normal. Notifikasi peringatan akan muncul di sini jika ada kondisi tanah atau perangkat yang memerlukan perhatian.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    bool isWarning,
    String message,
    DateTime time,
    bool isDark,
  ) {
    // Tentukan warna berdasarkan jenis notifikasi
    final themeColor =
        isWarning ? const Color(0xFFF97316) : const Color(0xFF10B981);

    final iconBgColor = isWarning
        ? (isDark ? const Color(0xFF431407) : const Color(0xFFFEF3C7))
        : (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5));

    final icon = isWarning
        ? Icons.warning_amber_rounded
        : Icons.check_circle_outline_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: themeColor.withOpacity(isDark ? 0.3 : 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(isDark ? 0.08 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ikon dengan background pastel
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isWarning
                    ? (isDark ? const Color(0xFFFB923C) : themeColor)
                    : (isDark ? const Color(0xFF6EE7B7) : themeColor),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Pesan dan Waktu
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('dd MMM yyyy, HH:mm').format(time),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
