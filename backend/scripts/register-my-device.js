require("dotenv").config();
const mongoose = require("mongoose");

// Import model
const Device = require("../models/Device");

const MY_USER_ID = "6a619115d8cd480d9b492e74";
const MY_DEVICE_ID = "ESP32_1434e3ec";

async function createAndRegisterDevice() {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log("✅ Connected to MongoDB");

    // Cek apakah user ada
    const User = mongoose.model("User");
    const user = await User.findById(MY_USER_ID);

    if (!user) {
      console.error("❌ User tidak ditemukan! Cek User ID Anda.");
      process.exit(1);
    }

    console.log(" User ditemukan:", user.email || user.name);

    // Cek apakah device sudah ada
    let device = await Device.findOne({ deviceId: MY_DEVICE_ID });

    if (device) {
      console.log("⚠️ Device sudah ada, updating...");
      device.deviceName = "ESP32 Utama";
      device.location = "Kebun Rumah";
      device.isActive = true;
      device.lastSeen = new Date();
      await device.save();
    } else {
      console.log(" Membuat device baru...");
      device = await Device.create({
        deviceId: MY_DEVICE_ID,
        userId: MY_USER_ID,
        deviceName: "ESP32 Utama",
        location: "Kebun Rumah",
        isActive: true,
        lastSeen: new Date(),
      });
    }

    console.log("\n✅ Device BERHASIL didaftarkan!");
    console.log("   Device ID:", device.deviceId);
    console.log("   Nama:", device.deviceName);
    console.log("   Location:", device.location);
    console.log("   User ID:", device.userId);
    console.log(
      "\n🎉 Sekarang buka MongoDB Compass - collection `devices` sudah muncul!",
    );
    console.log(" Restart aplikasi Flutter Anda!");

    process.exit(0);
  } catch (error) {
    console.error("\n❌ Error:", error.message);
    console.error("\n Pastikan:");
    console.error("   1. File backend/models/Device.js sudah ada");
    console.error("   2. MongoDB URI di .env sudah benar");
    console.error("   3. User ID valid");
    process.exit(1);
  }
}

createAndRegisterDevice();
