class ScheduleModel {
  final String? id;
  final String userId;
  final String name;
  final String startTime; // Sesuai dengan 'startTime' di backend
  final int durationMinutes;
  final List<int> days; // 0=Minggu, 1=Senin, ..., 6=Sabtu
  final bool isActive;
  final DateTime? lastExecuted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ScheduleModel({
    this.id,
    required this.userId,
    required this.name,
    required this.startTime,
    required this.durationMinutes,
    required this.days,
    this.isActive = true,
    this.lastExecuted,
    this.createdAt,
    this.updatedAt,
  });

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    // 1. Handle ID MongoDB dengan aman
    String? safeId = json['_id'] != null ? json['_id'].toString() : null;

    // 2. Safe parsing untuk List Hari (Menangani angka atau string)
    List<int> parsedDays = [];
    if (json['days'] is List) {
      parsedDays = (json['days'] as List).map((e) {
        int? dayInt = int.tryParse(e.toString());
        // Pastikan angka valid antara 0-6, jika tidak, default ke 0 (Minggu)
        return (dayInt != null && dayInt >= 0 && dayInt <= 6) ? dayInt : 0;
      }).toList();
    } else {
      parsedDays = [0, 1, 2, 3, 4, 5, 6]; // Default setiap hari jika null
    }

    return ScheduleModel(
      id: safeId,
      userId: json['userId']?.toString() ?? '',
      name: json['name'] ?? 'Jadwal Penyiraman',
      // Fallback ke '00:00' jika data kosong
      startTime: json['startTime']?.toString() ?? '00:00',

      // Safe parsing untuk integer (mencegah crash jika backend kirim string "5")
      durationMinutes: json['durationMinutes'] != null
          ? int.tryParse(json['durationMinutes'].toString()) ?? 1
          : 1,

      days: parsedDays,
      isActive: json['isActive'] ?? true,

      // Safe parsing untuk DateTime
      lastExecuted: json['lastExecuted'] != null
          ? DateTime.tryParse(json['lastExecuted'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'userId': userId,
      'name': name,
      'startTime': startTime,
      'durationMinutes': durationMinutes,
      'days': days,
      'isActive': isActive,
    };
  }

  // 🎁 BONUS: Helper untuk menampilkan hari di UI dengan rapi
  String get daysText {
    const dayNames = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];

    // Jika semua hari dipilih (7 hari)
    if (days.length >= 7) return 'Setiap Hari';

    // Sort hari agar urut dan filter angka yang valid (0-6) untuk mencegah error
    final sortedDays = List<int>.from(days)..sort();

    return sortedDays
        .where((d) => d >= 0 && d <= 6)
        .map((d) => dayNames[d])
        .join(', ');
  }
}
