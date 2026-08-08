const express = require("express");
const router = express.Router();
const Threshold = require("../models/Threshold");
const { protect } = require("../middleware/auth");

// ==========================================
// GET Threshold per-Device
// URL: GET /api/threshold/:deviceId
// ==========================================
router.get("/:deviceId", protect, async (req, res) => {
  try {
    const { deviceId } = req.params;

    if (!deviceId) {
      return res.status(400).json({
        success: false,
        message: "Device ID wajib disediakan di URL",
      });
    }

    console.log(
      `🔍 [BACKEND GET] Mencari threshold user=${req.user._id}, device=${deviceId}`,
    );

    // ✅ Query pakai compound filter (userId + deviceId)
    let threshold = await Threshold.findOne({
      userId: req.user._id,
      deviceId: deviceId.trim(),
    });

    // Fallback: migrasi dokumen lama (yang tidak punya deviceId) ke device ini
    if (!threshold) {
      const legacyThreshold = await Threshold.findOne({
        userId: req.user._id,
        deviceId: { $exists: false },
      }).sort({ updatedAt: -1 });

      if (legacyThreshold) {
        console.log(
          `🔄 [MIGRASI] Dokumen lama dipindahkan ke device ${deviceId}`,
        );
        legacyThreshold.deviceId = deviceId.trim();
        await legacyThreshold.save();
        threshold = legacyThreshold;
      }
    }

    // Kalau masih kosong, buat default baru untuk device ini
    if (!threshold) {
      console.log(
        `⚠️ [BACKEND GET] Tidak ditemukan, membuat default untuk ${deviceId}...`,
      );
      threshold = await Threshold.create({
        userId: req.user._id,
        deviceId: deviceId.trim(),
        deviceName: "Device Baru",
        moistureMin: 70,
        moistureMax: 90,
        phMin: 5.5,
        phMax: 6.5,
        temperatureMin: 25,
        temperatureMax: 30,
        isAutoWateringEnabled: true,
      });
    }

    console.log(`✅ [BACKEND GET] Threshold device ${deviceId} terkirim`);
    res.status(200).json({ success: true, data: threshold });
  } catch (error) {
    console.error("❌ [BACKEND GET] Error:", error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});

// ==========================================
// PUT Update Threshold per-Device
// URL: PUT /api/threshold/:deviceId
// ==========================================
router.put("/:deviceId", protect, async (req, res) => {
  const { deviceId } = req.params;

  console.log(
    `\n📥 [BACKEND PUT] device=${deviceId}, body:\n`,
    JSON.stringify(req.body, null, 2),
  );

  if (!deviceId) {
    return res.status(400).json({
      success: false,
      message: "Device ID wajib disediakan di URL",
    });
  }

  try {
    // 🔥 PAKSA KONVERSI KE NUMBER (dipertahankan)
    const updateData = {
      moistureMin: Number(req.body.moistureMin),
      moistureMax: Number(req.body.moistureMax),
      phMin: Number(req.body.phMin),
      phMax: Number(req.body.phMax),
      temperatureMin: Number(req.body.temperatureMin),
      temperatureMax: Number(req.body.temperatureMax),

      // ✅ Parsing boolean yang aman (dipertahankan)
      isAutoWateringEnabled:
        req.body.isAutoWateringEnabled === true ||
        req.body.isAutoWateringEnabled === "true",
    };

    // ✅ Opsional: update nama device kalau dikirim
    if (req.body.deviceName) {
      updateData.deviceName = req.body.deviceName;
    }

    // ✅ VALIDASI LOGIKA (dipertahankan)
    if (updateData.moistureMin >= updateData.moistureMax) {
      return res.status(400).json({
        success: false,
        message:
          "Moisture Min tidak boleh lebih besar atau sama dengan Moisture Max",
      });
    }
    if (updateData.temperatureMin >= updateData.temperatureMax) {
      return res.status(400).json({
        success: false,
        message:
          "Temperature Min tidak boleh lebih besar atau sama dengan Temperature Max",
      });
    }
    if (updateData.phMin >= updateData.phMax) {
      return res.status(400).json({
        success: false,
        message: "pH Min tidak boleh lebih besar atau sama dengan pH Max",
      });
    }

    console.log("🔄 [BACKEND PUT] Data yang akan disimpan:", updateData);

    // ✅ Cari dokumen spesifik untuk (user + device)
    let threshold = await Threshold.findOne({
      userId: req.user._id,
      deviceId: deviceId.trim(),
    });

    if (threshold) {
      // Update dokumen yang tepat
      Object.assign(threshold, updateData);
      await threshold.save();
      console.log(`✅ [BACKEND PUT] UPDATE sukses untuk device ${deviceId}`);
    } else {
      // Fallback migrasi dokumen lama
      const legacyThreshold = await Threshold.findOne({
        userId: req.user._id,
        deviceId: { $exists: false },
      }).sort({ updatedAt: -1 });

      if (legacyThreshold) {
        legacyThreshold.deviceId = deviceId.trim();
        Object.assign(legacyThreshold, updateData);
        await legacyThreshold.save();
        threshold = legacyThreshold;
        console.log(
          `✅ [BACKEND PUT] MIGRASI + UPDATE untuk device ${deviceId}`,
        );
      } else {
        // Buat dokumen baru
        updateData.userId = req.user._id;
        updateData.deviceId = deviceId.trim();
        threshold = await Threshold.create(updateData);
        console.log(
          `✅ [BACKEND PUT] CREATE dokumen baru untuk device ${deviceId}`,
        );
      }
    }

    res.status(200).json({
      success: true,
      message: "Threshold berhasil diupdate",
      data: threshold,
    });
  } catch (error) {
    console.error("❌ [BACKEND PUT] Error:", error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
