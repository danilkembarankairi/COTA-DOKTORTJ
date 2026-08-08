const Schedule = require("../models/Schedule");

let mqttClient = null;

// Fungsi untuk menginisialisasi scheduler (dipanggil dari server.js)
const initScheduler = (mqtt) => {
  mqttClient = mqtt;
  console.log("✅ Scheduler Service initialized with MQTT client");
};

// Fungsi utama yang dijalankan setiap menit
const startCronJob = () => {
  const cron = require("node-cron");

  cron.schedule("* * * * *", async () => {
    try {
      const now = new Date();

      // Format waktu saat ini menjadi "HH:mm" (contoh: "14:00")
      const currentTime = `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;

      // Hari ini (0 = Minggu, 1 = Senin, ..., 6 = Sabtu)
      const currentDay = now.getDay();

      console.log(
        `⏰ [CRON] Checking schedules at ${currentTime}, Day: ${currentDay}`,
      );

      // Cari jadwal yang:
      // 1. Aktif (isActive: true)
      // 2. Waktu mulainya cocok dengan waktu sekarang
      // 3. Hari ini ada di daftar hari yang dipilih
      const schedules = await Schedule.find({
        isActive: true,
        startTime: currentTime,
        days: { $in: [currentDay] },
      });

      if (schedules.length > 0) {
        console.log(`🚀 Found ${schedules.length} schedule(s) to execute!`);
      }

      for (const schedule of schedules) {
        // ✅ PERBAIKAN KRUSIAL: Cek deviceId SEBELUM memproses apapun
        if (!schedule.deviceId) {
          console.error(
            `⚠️ SKIP "${schedule.name}": Data rusak (tidak ada deviceId). Hapus jadwal ini dari aplikasi.`,
          );
          continue; // Lewati jadwal ini, jangan diproses atau di-save
        }

        // Cek agar tidak dieksekusi 2x di menit yang sama
        if (schedule.lastExecuted) {
          const lastExec = new Date(schedule.lastExecuted);
          const diffInMinutes = (now - lastExec) / 1000 / 60;

          // Jika sudah dieksekusi dalam 1 menit terakhir, skip
          if (diffInMinutes < 1) {
            console.log(
              `⏭️ Skipping "${schedule.name}" (already executed recently)`,
            );
            continue;
          }
        }

        console.log(
          `💧 EXECUTING: "${schedule.name}" for ${schedule.durationMinutes} minutes`,
        );

        // ✅ Sekarang DIJAMIN schedule.deviceId ADA isinya
        const targetTopic = `cota/smart_irrigation/${schedule.deviceId}/schedule/execute`;

        const payload = JSON.stringify({
          type: "scheduled_irrigation",
          name: schedule.name,
          durationMinutes: schedule.durationMinutes,
        });

        if (mqttClient && mqttClient.connected) {
          mqttClient.publish(targetTopic, payload, { qos: 1 }, (err) => {
            if (err) {
              console.error(`❌ Gagal publish ke ${targetTopic}:`, err.message);
            } else {
              console.log(`📤 MQTT Published to ${targetTopic}`);
            }
          });
        } else {
          console.error("❌ MQTT Client not connected!");
        }

        // Update waktu terakhir eksekusi di database
        // (Aman dilakukan sekarang karena deviceId sudah pasti ada, tidak akan error validasi)
        schedule.lastExecuted = now;
        await schedule.save();
      }
    } catch (error) {
      console.error("❌ Error in scheduler cron job:", error.message);
    }
  });

  console.log("🟢 Cron job started! Checking every minute...");
};

module.exports = { initScheduler, startCronJob };
