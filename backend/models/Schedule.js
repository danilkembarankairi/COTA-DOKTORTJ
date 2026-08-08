const mongoose = require("mongoose");

const scheduleSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    // ✅ WAJIB DITAMBAHKAN: Agar backend tahu harus kirim perintah ke alat mana
    deviceId: {
      type: String,
      required: [true, "Device ID wajib diisi"],
      trim: true,
    },
    name: {
      type: String,
      trim: true,
      default: "Jadwal Penyiraman",
    },
    startTime: {
      type: String, // Format "HH:mm"
      required: [true, "Waktu mulai wajib diisi"],
    },
    durationMinutes: {
      type: Number,
      required: [true, "Durasi wajib diisi"],
      min: [1, "Durasi minimal 1 menit"],
    },
    days: {
      type: [Number], // Array hari (0=Minggu, 1=Senin, ..., 6=Sabtu)
      required: [true, "Hari eksekusi wajib diisi"],
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    // ✅ WAJIB DITAMBAHKAN: Agar cron job tahu kapan terakhir kali dijalankan (mencegah eksekusi ganda)
    lastExecuted: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  },
);

module.exports = mongoose.model("Schedule", scheduleSchema);
