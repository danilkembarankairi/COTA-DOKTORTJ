const mongoose = require("mongoose");

const deviceSchema = new mongoose.Schema(
  {
    deviceId: {
      type: String,
      required: [true, "Device ID wajib diisi"],
      unique: true,
      trim: true,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "User ID wajib diisi"],
    },
    // ✅ Akun lain yang ikut terhubung (shared access)
    sharedWith: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],
    deviceName: {
      type: String,
      default: "Smart Irrigation Device",
      trim: true,
    },
    location: {
      type: String,
      default: "Belum diatur",
      trim: true,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    lastSeen: {
      type: Date,
      default: Date.now,
    },
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  },
);

// ==========================================
// INDEXES (Performa)
// ==========================================
deviceSchema.index({ userId: 1 });
deviceSchema.index({ sharedWith: 1 });
deviceSchema.index({ deviceId: 1 }, { unique: true });

// ==========================================
// VIRTUALS
// ==========================================
deviceSchema.virtual("isOnline").get(function () {
  const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
  return this.lastSeen > fiveMinutesAgo;
});

deviceSchema.virtual("linkedUserCount").get(function () {
  return 1 + (this.sharedWith ? this.sharedWith.length : 0);
});

module.exports = mongoose.model("Device", deviceSchema);
