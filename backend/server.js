require("dotenv").config();
const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const mqtt = require("mqtt");

const Threshold = require("./models/Threshold");
const SensorData = require("./models/SensorData");
const Device = require("./models/Device");
const schedulerService = require("./services/schedulerService");

const app = express();

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use((req, res, next) => {
  console.log(`\n🌐 [REQ] ${req.method} ${req.url}`);
  next();
});

const DEFAULT_USER_ID = "6a619115d8cd480d9b492e74";

// =========================
// 1. DATABASE
// =========================
mongoose
  .connect(process.env.MONGODB_URI)
  .then(() => console.log("✅ Connected to MongoDB"))
  .catch((err) => console.error("❌ MongoDB connection error:", err));

// =========================
// 2. MQTT CONFIG
// =========================
const MQTT_CONFIG = {
  clientId: `Backend-COTA-${Math.random().toString(16).substr(2, 8)}`,
  clean: true,
  connectTimeout: 4000,
  reconnectPeriod: 5000,
};

const TOPICS = {
  MOISTURE: "cota/smart_irrigation/+/soil_moisture",
  TEMP: "cota/smart_irrigation/+/temperature",
  PH: "cota/smart_irrigation/+/ph",
  PUMP_STATUS: "cota/smart_irrigation/+/pump/status",
  PUMP_CONTROL: "cota/smart_irrigation/+/pump/control",
  NOTIFICATIONS: "cota/smart_irrigation/+/notifications",
  STATUS: "cota/smart_irrigation/+/status",
  HEARTBEAT: "cota/smart_irrigation/+/heartbeat",
};

const mqttClient = mqtt.connect(process.env.MQTT_BROKER, MQTT_CONFIG);
app.locals.mqttClient = mqttClient;

let activeDeviceId = null;

// =========================
// 3. STATE GLOBAL (✅ DIPERBAIKI: Sekarang per-device)
// =========================
let devicesSensorData = {};

let pumpState = "OFF";
let pumpMode = "AUTO";
let cooldownUntil = 0;

let pumpStartReasons = { dry: false, hot: false };

const COOLDOWN_MS = 5 * 60 * 1000;
const MANUAL_ON_MIN_DURATION_MS = 10 * 1000;

// ✅ BARU: Throttle histori DB per-device (3 menit)
const DB_SAVE_INTERVAL_MS = 3 * 60 * 1000;
let lastSavedAt = {};

let isProcessing = false;
let manualOnEvaluationTimer = null;
let manualOnStartedAt = 0;

let lastPhStatus = "normal";
let lastBadPhNotificationTime = 0;
const PH_REMINDER_INTERVAL_MS = 20 * 60 * 1000;

let isBackendReady = false;
let deviceHeartbeats = {};
let deviceConnectionStatus = {};

// =========================
// 4. MQTT EVENTS
// =========================
mqttClient.on("connect", () => {
  console.log("✅ Connected to MQTT Broker");
  isBackendReady = false;

  Object.values(TOPICS).forEach((topic) => {
    mqttClient.subscribe(topic, (err) => {
      if (!err) console.log(`📡 Subscribed: ${topic}`);
    });
  });

  setTimeout(() => {
    isBackendReady = true;
    console.log(
      "✅ Backend siap memproses data live (Retained message lama diabaikan).",
    );
  }, 5000);
});

mqttClient.on("error", (err) =>
  console.error("❌ MQTT Connection Error:", err.message),
);
mqttClient.on("close", () =>
  console.log("⚠️ MQTT connection closed, reconnecting..."),
);

// =========================
// 5. FUNGSI BANTUAN
// =========================
function sendNotification(type, message, specificDeviceId = null) {
  const payload = JSON.stringify({ type, message, timestamp: Date.now() });
  const targetId = specificDeviceId || activeDeviceId;
  const targetTopic = targetId
    ? `cota/smart_irrigation/${targetId}/notifications`
    : TOPICS.NOTIFICATIONS;
  mqttClient.publish(targetTopic, payload, { qos: 1 });
  console.log(
    `🔔 [NOTIF] ${type.toUpperCase()} [${targetId || "GLOBAL"}]: ${message}`,
  );
}

function clearManualOnTimer() {
  if (manualOnEvaluationTimer) {
    clearTimeout(manualOnEvaluationTimer);
    manualOnEvaluationTimer = null;
  }
}

// ✅ BARU: Simpan event ON/OFF pompa ke histori (langsung saat berubah)
async function logPumpEvent(deviceId, newState) {
  try {
    const data = devicesSensorData[deviceId];
    if (
      !data ||
      data.moisture === null ||
      data.temperature === null ||
      data.ph === null
    ) {
      console.log(
        `📌 [PUMP EVENT] ${newState} untuk ${deviceId} (sensor belum lengkap, skip save)`,
      );
      return;
    }

    const targetDevice = await Device.findOne({
      deviceId: { $regex: new RegExp(`^${deviceId}$`, "i") },
    });
    const saveUserId = targetDevice ? targetDevice.userId : DEFAULT_USER_ID;

    await SensorData.create({
      userId: saveUserId,
      deviceId: deviceId,
      moisture: data.moisture,
      temperature: data.temperature,
      ph: data.ph,
      pumpStatus: newState,
      timestamp: new Date(),
    });

    // Reset throttle timer biar throttling tidak double-save setelah event
    lastSavedAt[deviceId] = Date.now();

    console.log(
      `📌 [PUMP EVENT] Pompa ${newState} tercatat di histori ${deviceId}`,
    );
  } catch (err) {
    console.error("❌ Gagal simpan pump event:", err.message);
  }
}

function turnPumpOn(source = "AUTO", targetDevice = null) {
  if (pumpState === "ON") return;
  const deviceId = targetDevice || activeDeviceId;
  const targetTopic = deviceId
    ? `cota/smart_irrigation/${deviceId}/pump/control`
    : TOPICS.PUMP_CONTROL;
  const statusTopic = deviceId
    ? `cota/smart_irrigation/${deviceId}/pump/status`
    : TOPICS.PUMP_STATUS;

  mqttClient.publish(targetTopic, "ON", { qos: 1 });
  mqttClient.publish(statusTopic, "ON", { qos: 1, retain: true });
  pumpState = "ON";
  pumpMode = source;
  logPumpEvent(deviceId, "ON"); // ✅ BARU
  console.log(`🚰 Pompa dinyalakan (${source}) untuk Device: ${deviceId}`);
}

function turnPumpOff(source = "AUTO", targetDevice = null) {
  if (pumpState === "OFF") return;
  const deviceId = targetDevice || activeDeviceId;
  const targetTopic = deviceId
    ? `cota/smart_irrigation/${deviceId}/pump/control`
    : TOPICS.PUMP_CONTROL;
  const statusTopic = deviceId
    ? `cota/smart_irrigation/${deviceId}/pump/status`
    : TOPICS.PUMP_STATUS;

  mqttClient.publish(targetTopic, "OFF", { qos: 1 });
  mqttClient.publish(statusTopic, "OFF", { qos: 1, retain: true });
  pumpState = "OFF";
  pumpMode =
    source === "AUTO_EVALUATION" || source === "MANUAL_TIMEOUT_EVAL"
      ? "AUTO"
      : source;
  logPumpEvent(deviceId, "OFF"); // ✅ BARU
  console.log(`🛑 Pompa dimatikan (${source}) untuk Device: ${deviceId}`);
}

function checkPhAndNotify(ph, phMin, phMax, deviceId) {
  const now = Date.now();
  const isBad = ph < phMin || ph > phMax;
  if (isBad) {
    if (lastPhStatus === "normal") {
      sendNotification(
        "warning",
        `⚠️ pH tanah buruk: ${ph}. Range normal: ${phMin} - ${phMax}`,
        deviceId,
      );
      lastPhStatus = "bad";
      lastBadPhNotificationTime = now;
    } else if (now - lastBadPhNotificationTime >= PH_REMINDER_INTERVAL_MS) {
      sendNotification(
        "warning",
        `⚠️ pH masih buruk: ${ph}. Mohon cek kondisi tanah.`,
        deviceId,
      );
      lastBadPhNotificationTime = now;
    }
  } else {
    if (lastPhStatus === "bad") {
      sendNotification("success", `✅ pH kembali normal: ${ph}`, deviceId);
      lastPhStatus = "normal";
      lastBadPhNotificationTime = 0;
    }
  }
}

function getWateringDecision(data, threshold, reasons) {
  const { moisture, temperature } = data;
  const { moistureMin, moistureMax, temperatureMin, temperatureMax } =
    threshold;

  const shouldStart = moisture < moistureMin || temperature > temperatureMax;

  const drySatisfied = !reasons.dry || moisture >= moistureMax;
  const hotSatisfied = !reasons.hot || temperature <= temperatureMin;
  const shouldStop = drySatisfied && hotSatisfied;

  return { shouldStart, shouldStop };
}

// =========================
// 6. LOGIKA UTAMA (AUTO WATERING)
// =========================
async function checkAllThresholdsAndTrigger(deviceId) {
  if (isProcessing) return;
  isProcessing = true;

  try {
    const data = devicesSensorData[deviceId];
    if (!data) {
      console.log(`⏭️ [SKIP] Data untuk ${deviceId} belum tersedia.`);
      return;
    }

    const now = Date.now();
    const DEVICE_OFFLINE_TIMEOUT_MS = 5 * 60 * 1000;

    if (
      now - data.lastUpdate > DEVICE_OFFLINE_TIMEOUT_MS ||
      data.lastUpdate === 0
    ) {
      console.log(
        `⏭️ [SKIP] Device ${deviceId} OFFLINE atau data kadaluarsa (> 5 menit).`,
      );
      if (pumpState === "ON") {
        console.log(
          `🛑 [SAFETY] Mematikan pompa ${deviceId} karena alat terputus.`,
        );
        turnPumpOff("SAFETY_OFFLINE", deviceId);
      }
      return;
    }

    const { moisture, temperature, ph } = data;

    if (moisture === null || temperature === null) {
      console.log(
        `❌ [SAFETY] Data sensor ${deviceId} TIDAK LENGKAP (Null). Mematikan pompa.`,
      );
      if (pumpState === "ON") turnPumpOff("SAFETY_NULL_DATA", deviceId);
      return;
    }

    let threshold = await Threshold.findOne({ deviceId: deviceId });

    if (!threshold) {
      const legacyThreshold = await Threshold.findOne({
        deviceId: { $exists: false },
      }).sort({ updatedAt: -1 });

      if (legacyThreshold) {
        console.log(
          `🔄 [MIGRASI] Threshold legacy dipindahkan ke device ${deviceId}`,
        );
        legacyThreshold.deviceId = deviceId;
        await legacyThreshold.save();
        threshold = legacyThreshold;
      }
    }

    if (!threshold) {
      const targetDevice = await Device.findOne({
        deviceId: { $regex: new RegExp(`^${deviceId}$`, "i") },
      });
      const userId = targetDevice ? targetDevice.userId : DEFAULT_USER_ID;

      threshold = await Threshold.create({
        userId: userId,
        deviceId: deviceId,
        deviceName: targetDevice ? targetDevice.deviceName : deviceId,
        moistureMin: 70,
        moistureMax: 90,
        phMin: 5.5,
        phMax: 6.5,
        temperatureMin: 25,
        temperatureMax: 30,
        isAutoWateringEnabled: true,
      });
      console.log(
        `🆕 [DEFAULT] Threshold baru dibuat otomatis untuk device ${deviceId}`,
      );
    }

    if (!threshold.isAutoWateringEnabled) {
      console.log(
        `⏸️ [AUTO] ❌ PENYIRAMAN OTOMATIS DIMATIKAN OLEH USER untuk ${deviceId}.`,
      );
      return;
    }

    if (ph !== null) {
      checkPhAndNotify(ph, threshold.phMin, threshold.phMax, deviceId);
    }

    const decision = getWateringDecision(data, threshold, pumpStartReasons);
    const isManualGracePeriodOver =
      pumpMode === "MANUAL" && pumpState === "ON"
        ? now - manualOnStartedAt >= MANUAL_ON_MIN_DURATION_MS
        : true;

    if (pumpMode === "MANUAL" && pumpState === "OFF" && now >= cooldownUntil) {
      pumpMode = "AUTO";
      console.log(
        "🔁 [MODE] Cooldown manual OFF selesai → kendali kembali ke AUTO.",
      );
    }

    console.log("==================================================");
    console.log(`🔍 [X-RAY THRESHOLD CHECK] Device: ${deviceId}`);
    console.log(
      `📊 Data Saat Ini : Moisture = ${moisture}%, Temp = ${temperature}°C`,
    );
    console.log(
      `🎯 Batas Threshold: Min = ${threshold.moistureMin}%, Max = ${threshold.moistureMax}%, TempMin = ${threshold.temperatureMin}°C, TempMax = ${threshold.temperatureMax}°C`,
    );
    console.log(
      `🧠 Keputusan     : shouldStart = ${decision.shouldStart}, shouldStop = ${decision.shouldStop}`,
    );
    console.log(
      `🧭 Alasan Nyala  : ${pumpStartReasons.dry ? "KERING" : "-"}${pumpStartReasons.dry && pumpStartReasons.hot ? " + " : ""}${pumpStartReasons.hot ? "PANAS" : ""}`,
    );
    console.log(`⚙️ Status Pompa   : State = ${pumpState}, Mode = ${pumpMode}`);
    console.log("==================================================");

    if (decision.shouldStart && pumpState === "OFF" && pumpMode === "AUTO") {
      pumpStartReasons = {
        dry: moisture < threshold.moistureMin,
        hot: temperature > threshold.temperatureMax,
      };
      console.log(
        `🧭 [REASON] Pompa NYALA karena: ${pumpStartReasons.dry ? "TANAH KERING" : ""}${pumpStartReasons.dry && pumpStartReasons.hot ? " + " : ""}${pumpStartReasons.hot ? "SUHU PANAS" : ""}`,
      );
      console.log(
        `✅ [DEBUG] KONDISI TERPENUHI! Memerintahkan Pompa ${deviceId} NYALA...`,
      );
      turnPumpOn("AUTO", deviceId);
      sendNotification(
        "warning",
        "🚰 Penyiraman otomatis dimulai karena suhu tinggi atau tanah kering",
        deviceId,
      );
      return;
    }

    if (decision.shouldStop && pumpState === "ON" && pumpMode === "AUTO") {
      turnPumpOff("AUTO_EVALUATION", deviceId);
      pumpStartReasons = { dry: false, hot: false };
      sendNotification(
        "success",
        "✅ Kondisi sudah aman, pompa dimatikan otomatis.",
        deviceId,
      );
      return;
    }

    if (
      pumpMode === "MANUAL" &&
      pumpState === "ON" &&
      isManualGracePeriodOver
    ) {
      console.log(
        "⚠️ Mode Manual berakhir (>10s). Mengalihkan kendali ke AUTO.",
      );
      pumpMode = "AUTO";
      pumpStartReasons = {
        dry: moisture < threshold.moistureMin,
        hot: temperature > threshold.temperatureMax,
      };
    }
  } catch (err) {
    console.error("❌ Error cek threshold:", err.message);
  } finally {
    isProcessing = false;
  }
}

// =========================
// 7. MQTT MESSAGE HANDLER
// =========================
mqttClient.on("message", async (topic, message) => {
  if (!isBackendReady) return;

  const topicParts = topic.split("/");
  let incomingDeviceId =
    topicParts.length >= 3 ? topicParts[2].trim() : "LEGACY_DEVICE";
  const rawMessage = message.toString().trim();
  const upperMessage = rawMessage.toUpperCase();

  if (incomingDeviceId !== "LEGACY_DEVICE") {
    const registeredDevice = await Device.findOne({
      deviceId: { $regex: new RegExp(`^${incomingDeviceId}$`, "i") },
      isActive: true,
    });

    if (!registeredDevice) {
      console.log(
        `🚫 [SECURITY] Data dari device TIDAK TERDAFTAR: ${incomingDeviceId}`,
      );
      return;
    }
    console.log(`✅ [ACCEPTED] Device: ${registeredDevice.deviceId}`);
    activeDeviceId = registeredDevice.deviceId;
  }

  const isTopic = (suffix) => topic.endsWith(suffix);
  if (isTopic("/notifications")) return;

  if (isTopic("/status") && !isTopic("/pump/status")) {
    if (rawMessage === "offline_power_loss") {
      console.log(`🚨 [CRITICAL] Device ${incomingDeviceId} mati mendadak!`);
      deviceConnectionStatus[incomingDeviceId] = "offline";
      sendNotification(
        "error",
        `⚠️ Perangkat ${incomingDeviceId} mati mendadak! Periksa sumber listrik.`,
        incomingDeviceId,
      );

      clearManualOnTimer();
      if (pumpState === "ON") {
        turnPumpOff("AUTO_EVALUATION", incomingDeviceId);
        sendNotification(
          "success",
          "🛑 Pompa dimatikan otomatis karena perangkat kehilangan daya.",
          incomingDeviceId,
        );
      }
    } else if (rawMessage === "online") {
      console.log(`✅ [RECOVERY] Device ${incomingDeviceId} online kembali.`);
      deviceConnectionStatus[incomingDeviceId] = "online";
      sendNotification(
        "success",
        `✅ Perangkat ${incomingDeviceId} kembali online.`,
        incomingDeviceId,
      );
    }
    return;
  }

  if (isTopic("/heartbeat")) {
    deviceHeartbeats[incomingDeviceId] = Date.now();
    deviceConnectionStatus[incomingDeviceId] = "online";
    return;
  }

  try {
    if (isTopic("/pump/control")) {
      if (upperMessage === "OFF") {
        console.log("✋ User mematikan pompa");
        clearManualOnTimer();
        turnPumpOff("MANUAL", incomingDeviceId);
        cooldownUntil = Date.now() + COOLDOWN_MS;
        return;
      }
      if (upperMessage === "ON") {
        console.log("👍 User menyalakan pompa manual");
        clearManualOnTimer();
        turnPumpOn("MANUAL", incomingDeviceId);
        cooldownUntil = 0;
        manualOnStartedAt = Date.now();
        manualOnEvaluationTimer = setTimeout(async () => {
          console.log("⏱️ 10 detik Manual ON habis, evaluasi ulang...");
          manualOnEvaluationTimer = null;
          await checkAllThresholdsAndTrigger(incomingDeviceId);
        }, MANUAL_ON_MIN_DURATION_MS);
        return;
      }
    }

    if (isTopic("/pump/status")) {
      if (pumpMode === "MANUAL" && pumpState === "ON") {
        const now = Date.now();
        if (now - manualOnStartedAt < MANUAL_ON_MIN_DURATION_MS) {
          console.log(
            "⚠️ [PROTEKSI] Mengabaikan sinyal OFF dari ESP32. Masih masa tunggu 10 detik.",
          );
          return;
        }
      }
      pumpState = upperMessage === "ON" ? "ON" : "OFF";
      return;
    }

    let value = null;
    try {
      const parsed = JSON.parse(rawMessage);
      if (typeof parsed === "object" && parsed !== null) {
        if (parsed.deviceId) incomingDeviceId = parsed.deviceId.trim();
        if (parsed.value !== undefined) value = parseFloat(parsed.value);
        else if (parsed.moisture !== undefined && isTopic("/soil_moisture"))
          value = parseFloat(parsed.moisture);
        else if (parsed.temperature !== undefined && isTopic("/temperature"))
          value = parseFloat(parsed.temperature);
        else if (parsed.ph !== undefined && isTopic("/ph"))
          value = parseFloat(parsed.ph);
      } else if (typeof parsed === "number") {
        value = parsed;
      }
    } catch (e) {
      value = parseFloat(rawMessage);
    }

    if (value === null || isNaN(value)) {
      console.log(
        `⚠️ Data sensor tidak valid di ${topic} | Raw: "${rawMessage}"`,
      );
      return;
    }

    if (!devicesSensorData[incomingDeviceId]) {
      devicesSensorData[incomingDeviceId] = {
        moisture: null,
        temperature: null,
        ph: null,
        lastUpdate: 0,
      };
    }

    if (isTopic("/soil_moisture")) {
      devicesSensorData[incomingDeviceId].moisture = value;
      console.log(`💧 [${incomingDeviceId}] Update Moisture: ${value}%`);
    } else if (isTopic("/temperature")) {
      devicesSensorData[incomingDeviceId].temperature = value;
      console.log(`🌡️ [${incomingDeviceId}] Update Temperature: ${value}°C`);
    } else if (isTopic("/ph")) {
      devicesSensorData[incomingDeviceId].ph = value;
      console.log(`🧪 [${incomingDeviceId}] Update pH: ${value}`);
    }

    devicesSensorData[incomingDeviceId].lastUpdate = Date.now();

    if (incomingDeviceId !== "LEGACY_DEVICE") {
      try {
        let device = await Device.findOne({
          deviceId: { $regex: new RegExp(`^${incomingDeviceId}$`, "i") },
        });
        if (!device) {
          device = await Device.create({
            deviceId: incomingDeviceId,
            userId: DEFAULT_USER_ID,
            deviceName: `Device ${incomingDeviceId.substring(0, 8).toUpperCase()}`,
            location: "Belum diatur",
            isActive: true,
          });
        }
        await Device.updateOne({ _id: device._id }, { lastSeen: new Date() });
      } catch (err) {
        console.error("❌ Error auto-register device:", err.message);
      }
    }

    // ✅ SIMPAN KE DATABASE — THROTTLE 3 MENIT PER DEVICE
    // MQTT publish ke Flutter tetap jalan tiap 5 detik (tidak disentuh)
    const currentData = devicesSensorData[incomingDeviceId];
    if (
      currentData.moisture !== null &&
      currentData.temperature !== null &&
      currentData.ph !== null
    ) {
      const nowSave = Date.now();
      const lastSave = lastSavedAt[incomingDeviceId] || 0;

      // Save pertama (lastSave === 0) langsung jalan,
      // selanjutnya hanya kalau sudah lewat 3 menit
      if (lastSave === 0 || nowSave - lastSave >= DB_SAVE_INTERVAL_MS) {
        lastSavedAt[incomingDeviceId] = nowSave;
        try {
          const targetDevice = await Device.findOne({
            deviceId: { $regex: new RegExp(`^${incomingDeviceId}$`, "i") },
          });
          const saveUserId = targetDevice
            ? targetDevice.userId
            : DEFAULT_USER_ID;

          await SensorData.create({
            userId: saveUserId,
            deviceId: incomingDeviceId,
            moisture: currentData.moisture,
            temperature: currentData.temperature,
            ph: currentData.ph,
            pumpStatus: pumpState,
            timestamp: new Date(),
          });
          console.log(
            `💾 [HISTORI] Save DB (interval 3m) untuk ${incomingDeviceId}`,
          );
        } catch (dbError) {
          console.error(
            "❌ Gagal menyimpan data ke database:",
            dbError.message,
          );
        }
      }
    }

    await checkAllThresholdsAndTrigger(incomingDeviceId);
  } catch (error) {
    console.error("❌ Error processing MQTT message:", error.message);
  }
});

// =========================
// 7.5. HEARTBEAT MONITORING
// =========================
setInterval(() => {
  const now = Date.now();
  const HEARTBEAT_TIMEOUT_MS = 45000;

  for (const [deviceId, lastBeat] of Object.entries(deviceHeartbeats)) {
    if (now - lastBeat > HEARTBEAT_TIMEOUT_MS) {
      if (deviceConnectionStatus[deviceId] === "online") {
        console.log(`⚠️ [WARNING] Device ${deviceId} heartbeat timeout.`);
        deviceConnectionStatus[deviceId] = "unresponsive";
        sendNotification(
          "warning",
          `⚠️ Perangkat ${deviceId} tidak merespon. Periksa koneksi WiFi.`,
          deviceId,
        );
      }
    }
  }
}, 30000);

// =========================
// 8. ROUTES & 9. SCHEDULER & 10. START
// =========================
app.use("/api/auth", require("./routes/auth"));
app.use("/api/sensors", require("./routes/sensors"));
app.use("/api/pump", require("./routes/pump"));
app.use("/api/threshold", require("./routes/threshold"));
app.use("/api/schedule", require("./routes/schedule"));
app.use("/api/device", require("./routes/device"));

app.get("/", (req, res) =>
  res.json({ message: "Smart Irrigation API", status: "Running" }),
);

app.use((err, req, res, next) => {
  console.error("❌ SERVER ERROR:", err.stack);
  res.status(500).json({ success: false, message: "Something went wrong!" });
});

schedulerService.initScheduler(mqttClient, {
  getPumpState: () => pumpState,
  getPumpMode: () => pumpMode,
  getCooldownUntil: () => cooldownUntil,
  setCooldownUntil: (value) => {
    cooldownUntil = value;
  },
  turnPumpOn,
  turnPumpOff,
  getLatestSensorData: () => devicesSensorData,
});
schedulerService.startCronJob();

const PORT = process.env.PORT || 3000;
const server = app.listen(PORT, () =>
  console.log(`🚀 Server running on port ${PORT}`),
);

process.on("SIGINT", async () => {
  console.log("\n🛑 Shutdown...");
  clearManualOnTimer();
  await mongoose.connection.close();
  mqttClient.end();
  server.close(() => {
    console.log("✅ Server closed safely.");
    process.exit(0);
  });
});

module.exports = { app, mqttClient };
