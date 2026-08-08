const express = require("express");
const router = express.Router();
const Device = require("../models/Device");
const { protect } = require("../middleware/auth");

router.use(protect);

const escapeRegExp = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

// ✅ Helper: terhubung sebagai owner / shared?
const isLinked = (device, userId) =>
  device.userId.toString() === userId.toString() ||
  (device.sharedWith || []).some((id) => id.toString() === userId.toString());

// ==========================================
// HANDLERS
// ==========================================

// ✅ Ambil semua device yang terhubung ke akun ini
const getMyDevices = async (req, res) => {
  try {
    const devices = await Device.find({
      $or: [{ userId: req.user.id }, { sharedWith: req.user.id }],
    }).sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      count: devices.length,
      data: devices,
      devices, // ✅ dua format biar aman di Flutter
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ✅ Device sudah ada → LINK. Belum ada → buat baru (owner).
const registerDevice = async (req, res) => {
  try {
    const { deviceId, deviceName, location } = req.body;

    if (!deviceId || !deviceId.trim()) {
      return res
        .status(400)
        .json({ success: false, message: "Device ID wajib diisi" });
    }

    // Cari case-insensitive (f kecil / F besar sama)
    const existing = await Device.findOne({
      deviceId: new RegExp(`^${escapeRegExp(deviceId.trim())}$`, "i"),
    });

    if (existing) {
      if (isLinked(existing, req.user.id)) {
        return res.status(400).json({
          success: false,
          message: "Device ini sudah terhubung ke akun Anda",
        });
      }
      // ✅ LINK ke akun ini (shared device)
      existing.sharedWith.push(req.user.id);
      await existing.save();
      return res.status(200).json({
        success: true,
        message: "Device berhasil ditambahkan ke akun Anda",
        data: existing,
        device: existing,
      });
    }

    // ✅ Buat baru — simpan persis seperti diketik
    const device = await Device.create({
      deviceId: deviceId.trim(),
      deviceName: deviceName ? deviceName.trim() : undefined,
      location: location || undefined,
      userId: req.user.id,
      sharedWith: [],
      isActive: true,
    });

    res.status(201).json({ success: true, data: device, device });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ✅ Edit nama/lokasi (akun yang terhubung saja)
const updateDevice = async (req, res) => {
  try {
    const device = await Device.findById(req.params.id);
    if (!device)
      return res
        .status(404)
        .json({ success: false, message: "Device tidak ditemukan" });
    if (!isLinked(device, req.user.id)) {
      return res.status(403).json({
        success: false,
        message: "Device ini tidak terhubung ke akun Anda",
      });
    }

    const { deviceName, location, isActive } = req.body;
    if (deviceName) device.deviceName = deviceName.trim();
    if (location !== undefined) device.location = location;
    if (isActive !== undefined) device.isActive = isActive;

    await device.save();
    res.status(200).json({ success: true, data: device, device });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ✅ Owner = hapus total. Shared = lepas dari akun sendiri.
const deleteDevice = async (req, res) => {
  try {
    const device = await Device.findById(req.params.id);
    if (!device)
      return res
        .status(404)
        .json({ success: false, message: "Device tidak ditemukan" });
    if (!isLinked(device, req.user.id)) {
      return res.status(403).json({
        success: false,
        message: "Device ini tidak terhubung ke akun Anda",
      });
    }

    if (device.userId.toString() === req.user.id.toString()) {
      await Device.deleteOne({ _id: device._id });
      return res
        .status(200)
        .json({ success: true, message: "Device dihapus sepenuhnya" });
    }

    device.sharedWith = device.sharedWith.filter(
      (id) => id.toString() !== req.user.id.toString(),
    );
    await device.save();
    res
      .status(200)
      .json({ success: true, message: "Device dilepas dari akun Anda" });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ==========================================
// ROUTES + ALIAS (agar cocok dengan Flutter Anda)
// ==========================================
router.get("/", getMyDevices);
router.get("/my-devices", getMyDevices); // ✅ dipakai aplikasi

router.post("/", registerDevice);
router.post("/register", registerDevice); // ✅ dipakai aplikasi

router.put("/:id", updateDevice);
router.put("/update/:id", updateDevice); // ✅ antisipasi tombol Edit

router.delete("/:id", deleteDevice);
router.delete("/delete/:id", deleteDevice); // ✅ antisipasi tombol Hapus

module.exports = router;
