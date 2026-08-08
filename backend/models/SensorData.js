const mongoose = require("mongoose");

const sensorDataSchema = new mongoose.Schema({
  deviceId: {
    // ✅ TAMBAHKAN INI
    type: String,
    required: true,
    index: true,
  },
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "User",
    required: true,
  },
  moisture: {
    type: Number,
    required: true,
  },
  temperature: {
    type: Number,
    required: true,
  },
  ph: {
    type: Number,
    required: true,
  },
  pumpStatus: {
    type: String,
    enum: ["ON", "OFF"],
    default: "OFF",
  },
  timestamp: {
    type: Date,
    default: Date.now,
  },
});

// ✅ Index untuk query cepat per-device + time range
sensorDataSchema.index({ deviceId: 1, timestamp: -1 }); // paling penting untuk grafik
sensorDataSchema.index({ userId: 1, timestamp: -1 }); // sudah ada, pertahankan

module.exports = mongoose.model("SensorData", sensorDataSchema);
