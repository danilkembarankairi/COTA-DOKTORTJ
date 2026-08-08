const express = require("express");
const router = express.Router();
const Schedule = require("../models/Schedule");
const { protect } = require("../middleware/auth");

// ==========================================
// ✅ GET schedules (dengan filter deviceId opsional)
// ==========================================
router.get("/", protect, async (req, res) => {
  try {
    const { deviceId } = req.query; // ✅ BARU: ambil deviceId dari query string

    // ✅ Build query dinamis
    const query = { userId: req.user._id };
    if (deviceId && deviceId.trim() !== "") {
      query.deviceId = deviceId.trim();
    }

    const schedules = await Schedule.find(query).sort({ startTime: 1 });

    console.log(
      `📅 [SCHEDULE GET] user=${req.user._id}, deviceId=${deviceId || "ALL"}, count=${schedules.length}`,
    );

    res.status(200).json({
      success: true,
      count: schedules.length,
      data: schedules,
    });
  } catch (error) {
    console.error("❌ [SCHEDULE GET] Error:", error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});

// ==========================================
// POST create schedule (DIPERBAIKI: Menerima & Menyimpan deviceId)
// ==========================================
router.post("/", protect, async (req, res) => {
  console.log("\n==================================================");
  console.log("🚨🚨🚨 ROUTE POST /api/schedule TERHIT! 🚨🚨🚨");
  console.log("📦 REQ.BODY:", JSON.stringify(req.body, null, 2));
  console.log("==================================================\n");

  try {
    const { name, startTime, durationMinutes, days, isActive, deviceId } =
      req.body;

    if (
      !name ||
      !startTime ||
      durationMinutes === undefined ||
      !days ||
      !deviceId
    ) {
      return res.status(400).json({
        success: false,
        message: "Data tidak lengkap. 'deviceId' wajib dikirim dari aplikasi!",
      });
    }

    const duration = parseInt(durationMinutes, 10);
    const daysArray = Array.isArray(days)
      ? days.map((d) => parseInt(d, 10))
      : [];

    const dataToSave = {
      userId: req.user._id,
      deviceId: String(deviceId),
      name: String(name),
      startTime: String(startTime),
      durationMinutes: duration,
      days: daysArray,
      isActive: isActive !== undefined ? Boolean(isActive) : true,
    };

    console.log(
      "💾 MENYIMPAN KE DATABASE:",
      JSON.stringify(dataToSave, null, 2),
    );

    const newSchedule = new Schedule(dataToSave);
    await newSchedule.save();

    console.log("✅✅✅ BERHASIL DISIMPAN! ID:", newSchedule._id, "✅✅✅\n");

    res.status(201).json({
      success: true,
      message: "Jadwal berhasil dibuat",
      data: newSchedule,
    });
  } catch (error) {
    console.error("❌❌❌ ERROR SAAT SAVE:", error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// ==========================================
// PUT update schedule
// ==========================================
router.put("/:id", protect, async (req, res) => {
  try {
    const schedule = await Schedule.findById(req.params.id);
    if (!schedule)
      return res
        .status(404)
        .json({ success: false, message: "Jadwal tidak ditemukan" });
    if (schedule.userId.toString() !== req.user._id.toString()) {
      return res
        .status(403)
        .json({ success: false, message: "Tidak diizinkan" });
    }

    const updateData = { ...req.body };
    if (updateData.durationMinutes)
      updateData.durationMinutes = parseInt(updateData.durationMinutes, 10);
    if (updateData.days)
      updateData.days = updateData.days.map((d) => parseInt(d, 10));

    const updated = await Schedule.findByIdAndUpdate(
      req.params.id,
      updateData,
      { new: true },
    );
    res.status(200).json({ success: true, data: updated });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ==========================================
// DELETE schedule
// ==========================================
router.delete("/:id", protect, async (req, res) => {
  try {
    const schedule = await Schedule.findById(req.params.id);
    if (!schedule)
      return res
        .status(404)
        .json({ success: false, message: "Jadwal tidak ditemukan" });
    if (schedule.userId.toString() !== req.user._id.toString()) {
      return res
        .status(403)
        .json({ success: false, message: "Tidak diizinkan" });
    }
    await schedule.deleteOne();
    res.status(200).json({ success: true, message: "Jadwal dihapus" });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
