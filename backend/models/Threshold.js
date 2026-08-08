const mongoose = require("mongoose");

const thresholdSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true, // Mempercepat query pencarian berdasarkan userId
    },
    // ✅ BARU: Threshold kini melekat ke DEVICE, bukan user.
    // Satu device = satu dokumen threshold (tidak saling tumpang tindih).
    deviceId: {
      type: String,
      required: [true, "Device ID wajib diisi"],
      trim: true,
      index: true, // Mempercepat query dari server.js (auto-watering)
    },
    // ✅ BARU: Nama device (opsional) untuk kemudahan identifikasi di DB
    deviceName: {
      type: String,
      default: "Default Device",
      trim: true,
    },
    moistureMin: {
      type: Number,
      default: 30,
      min: 0,
      max: 100,
    },
    moistureMax: {
      type: Number,
      default: 70,
      min: 0,
      max: 100,
    },
    phMin: {
      type: Number,
      default: 5.5,
      min: 0,
      max: 14,
    },
    phMax: {
      type: Number,
      default: 6.5,
      min: 0,
      max: 14,
    },
    temperatureMin: {
      type: Number,
      default: 15,
      min: 0,
      max: 50,
    },
    temperatureMax: {
      type: Number,
      default: 35,
      min: 0,
      max: 50,
    },
    isAutoWateringEnabled: {
      type: Boolean,
      default: true,
    },
    isAlertEnabled: {
      type: Boolean,
      default: true,
    },
    lastTriggeredAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  },
);

// ✅ BARU: Compound unique index — satu user boleh punya banyak device,
// tapi setiap device hanya boleh punya SATU dokumen threshold.
thresholdSchema.index({ userId: 1, deviceId: 1 }, { unique: true });

module.exports = mongoose.model("Threshold", thresholdSchema);
