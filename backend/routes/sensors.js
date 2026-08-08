const express = require("express");
const router = express.Router();
const SensorData = require("../models/SensorData");
const Device = require("../models/Device");
const { protect } = require("../middleware/auth");

// ==========================================
// 🔧 HELPER: Cleaning query (buang data error sensor)
// ==========================================
const buildCleaningQuery = (baseQuery = {}) => {
  return {
    ...baseQuery,
    moisture: { $gte: 0, $lte: 100 },
    temperature: { $gte: -10, $lte: 60 },
    ph: { $gte: 0, $lte: 14 },
  };
};

// ==========================================
// 🔧 HELPER: Time range query
// ==========================================
const buildTimeRangeQuery = (range, startDate, endDate) => {
  const timeQuery = {};
  const now = new Date();

  if (startDate) {
    timeQuery.$gte = new Date(startDate);
  } else {
    const start = new Date();
    if (range === "daily") {
      start.setHours(0, 0, 0, 0);
    } else if (range === "weekly") {
      start.setDate(now.getDate() - 7);
    } else if (range === "monthly") {
      start.setMonth(now.getMonth() - 1);
    } else {
      start.setHours(0, 0, 0, 0);
    }
    timeQuery.$gte = start;
  }

  timeQuery.$lte = endDate ? new Date(endDate) : now;
  return timeQuery;
};

// ==========================================
// ✅ HELPER: device id yang bisa diakses user (owner / shared, format apapun)
// ==========================================
const getAccessibleDeviceIds = async (userId) => {
  const uid = String(userId);
  const devices = await Device.find({});
  return devices
    .filter((d) => {
      if (String(d.userId) === uid) return true;
      if (Array.isArray(d.sharedWith)) {
        return d.sharedWith.some((u) => String(u) === uid);
      }
      return false;
    })
    .map((d) => d.deviceId);
};

// ==========================================
// @route   GET /api/sensors/latest
// ==========================================
router.get("/latest", protect, async (req, res) => {
  try {
    const { deviceId } = req.query;

    // ✅ SIMPLIFIED: filter langsung by deviceId (tetap wajib login)
    let query = buildCleaningQuery();
    if (deviceId) {
      query.deviceId = deviceId;
    } else {
      const ids = await getAccessibleDeviceIds(req.user._id);
      query.deviceId = { $in: ids.length ? ids : ["__none__"] };
    }

    const data = await SensorData.findOne(query).sort({ timestamp: -1 });

    console.log(
      `📊 [SENSOR LATEST] device=${deviceId || "ALL"}, found=${!!data}`,
    );

    res.status(200).json({
      success: true,
      data: data || {
        moisture: 0,
        temperature: 0,
        ph: 0,
        pumpStatus: "OFF",
        deviceId: deviceId || "default_device",
        timestamp: new Date(),
      },
    });
  } catch (error) {
    console.error("❌ [SENSOR LATEST] Error:", error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});

// ==========================================
// @route   GET /api/sensors/history
// ==========================================
router.get("/history", protect, async (req, res) => {
  try {
    const {
      startDate,
      endDate,
      range = "daily",
      limit = 1000,
      order = "asc",
      deviceId,
    } = req.query;

    // ✅ SIMPLIFIED: filter langsung by deviceId
    let query = buildCleaningQuery();
    if (deviceId) {
      query.deviceId = deviceId;
    } else {
      const ids = await getAccessibleDeviceIds(req.user._id);
      query.deviceId = { $in: ids.length ? ids : ["__none__"] };
    }

    if (startDate || endDate || range) {
      query.timestamp = buildTimeRangeQuery(range, startDate, endDate);
    }

    const sortOrder = order === "desc" ? -1 : 1;
    const data = await SensorData.find(query)
      .sort({ timestamp: sortOrder })
      .limit(parseInt(limit));

    console.log(
      `📊 [SENSOR HISTORY] device=${deviceId || "ALL"}, range=${range}, count=${data.length}`,
    );

    res.status(200).json({
      success: true,
      count: data.length,
      range,
      deviceId: deviceId || "all",
      data,
    });
  } catch (error) {
    console.error("❌ [SENSOR HISTORY] Error:", error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});

// ==========================================
// @route   GET /api/sensors/aggregate
// ==========================================
router.get("/aggregate", protect, async (req, res) => {
  try {
    const { deviceId, range = "daily" } = req.query;

    if (!deviceId) {
      return res
        .status(400)
        .json({ success: false, message: "deviceId wajib dikirim" });
    }

    let intervalMinutes;
    const startDate = new Date();

    if (range === "daily") {
      intervalMinutes = 5;
      startDate.setHours(0, 0, 0, 0);
    } else if (range === "weekly") {
      intervalMinutes = 60;
      startDate.setDate(startDate.getDate() - 7);
    } else if (range === "monthly") {
      intervalMinutes = 1440;
      startDate.setMonth(startDate.getMonth() - 1);
    } else {
      return res.status(400).json({
        success: false,
        message: "Range tidak valid. Gunakan: daily, weekly, monthly",
      });
    }

    const intervalMs = intervalMinutes * 60 * 1000;

    const aggregation = await SensorData.aggregate([
      {
        $match: {
          deviceId: deviceId,
          timestamp: { $gte: startDate },
          moisture: { $gte: 0, $lte: 100 },
          temperature: { $gte: -10, $lte: 60 },
          ph: { $gte: 0, $lte: 14 },
        },
      },
      {
        $group: {
          _id: {
            $subtract: [
              { $toLong: "$timestamp" },
              { $mod: [{ $toLong: "$timestamp" }, intervalMs] },
            ],
          },
          avgMoisture: { $avg: "$moisture" },
          avgTemperature: { $avg: "$temperature" },
          avgPh: { $avg: "$ph" },
          minMoisture: { $min: "$moisture" },
          maxMoisture: { $max: "$moisture" },
          count: { $sum: 1 },
        },
      },
      { $sort: { _id: 1 } },
      {
        $project: {
          timestamp: { $toDate: "$_id" },
          moisture: { $round: ["$avgMoisture", 1] },
          temperature: { $round: ["$avgTemperature", 1] },
          ph: { $round: ["$avgPh", 2] },
          minMoisture: 1,
          maxMoisture: 1,
          count: 1,
          _id: 0,
        },
      },
    ]);

    console.log(
      `📊 [SENSOR AGGREGATE] device=${deviceId}, range=${range}, count=${aggregation.length}`,
    );

    res.status(200).json({
      success: true,
      count: aggregation.length,
      range,
      interval: `${intervalMinutes}min`,
      deviceId,
      data: aggregation,
    });
  } catch (error) {
    console.error("❌ [SENSOR AGGREGATE] Error:", error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});

// ==========================================
// @route   GET /api/sensors/stats
// ==========================================
router.get("/stats", protect, async (req, res) => {
  try {
    const { deviceId, range = "daily" } = req.query;

    if (!deviceId) {
      return res
        .status(400)
        .json({ success: false, message: "deviceId wajib dikirim" });
    }

    const startDate = new Date();
    if (range === "daily") {
      startDate.setHours(0, 0, 0, 0);
    } else if (range === "weekly") {
      startDate.setDate(startDate.getDate() - 7);
    } else if (range === "monthly") {
      startDate.setMonth(startDate.getMonth() - 1);
    }

    const stats = await SensorData.aggregate([
      {
        $match: {
          deviceId: deviceId,
          timestamp: { $gte: startDate },
          moisture: { $gte: 0, $lte: 100 },
          temperature: { $gte: -10, $lte: 60 },
          ph: { $gte: 0, $lte: 14 },
        },
      },
      {
        $group: {
          _id: null,
          totalSamples: { $sum: 1 },
          avgMoisture: { $avg: "$moisture" },
          minMoisture: { $min: "$moisture" },
          maxMoisture: { $max: "$moisture" },
          avgTemperature: { $avg: "$temperature" },
          minTemperature: { $min: "$temperature" },
          maxTemperature: { $max: "$temperature" },
          avgPh: { $avg: "$ph" },
          minPh: { $min: "$ph" },
          maxPh: { $max: "$ph" },
        },
      },
      {
        $project: {
          _id: 0,
          totalSamples: 1,
          moisture: {
            avg: { $round: ["$avgMoisture", 1] },
            min: "$minMoisture",
            max: "$maxMoisture",
          },
          temperature: {
            avg: { $round: ["$avgTemperature", 1] },
            min: { $round: ["$minTemperature", 1] },
            max: { $round: ["$maxTemperature", 1] },
          },
          ph: {
            avg: { $round: ["$avgPh", 2] },
            min: { $round: ["$minPh", 2] },
            max: { $round: ["$maxPh", 2] },
          },
        },
      },
    ]);

    const result = stats[0] || {
      totalSamples: 0,
      moisture: { avg: 0, min: 0, max: 0 },
      temperature: { avg: 0, min: 0, max: 0 },
      ph: { avg: 0, min: 0, max: 0 },
    };

    res.status(200).json({ success: true, range, deviceId, data: result });
  } catch (error) {
    console.error("❌ [SENSOR STATS] Error:", error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});

// ==========================================
// @route   GET /api/sensors/export
// ==========================================
router.get("/export", protect, async (req, res) => {
  try {
    const { deviceId, range = "daily" } = req.query;

    if (!deviceId) {
      return res
        .status(400)
        .json({ success: false, message: "deviceId wajib dikirim" });
    }

    const startDate = new Date();
    if (range === "daily") {
      startDate.setHours(0, 0, 0, 0);
    } else if (range === "weekly") {
      startDate.setDate(startDate.getDate() - 7);
    } else if (range === "monthly") {
      startDate.setMonth(startDate.getMonth() - 1);
    }

    const data = await SensorData.find({
      deviceId: deviceId,
      timestamp: { $gte: startDate },
      moisture: { $gte: 0, $lte: 100 },
      temperature: { $gte: -10, $lte: 60 },
      ph: { $gte: 0, $lte: 14 },
    })
      .sort({ timestamp: 1 })
      .limit(10000);

    const header = "timestamp,deviceId,moisture,temperature,ph,pumpStatus\n";
    const rows = data
      .map((d) => {
        const ts = new Date(d.timestamp).toISOString();
        return `${ts},${d.deviceId},${d.moisture},${d.temperature},${d.ph},${d.pumpStatus || "OFF"}`;
      })
      .join("\n");

    const csvContent = header + rows;
    const filename = `cota_sensor_${deviceId}_${range}_${Date.now()}.csv`;

    res.setHeader("Content-Type", "text/csv");
    res.setHeader("Content-Disposition", `attachment; filename="${filename}"`);
    res.status(200).send(csvContent);
  } catch (error) {
    console.error("❌ [SENSOR EXPORT] Error:", error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});

// ==========================================
// @route   POST /api/sensors/save
// ==========================================
router.post("/save", protect, async (req, res) => {
  try {
    const { moisture, temperature, ph, pumpStatus, deviceId } = req.body;

    if (
      moisture === undefined ||
      temperature === undefined ||
      ph === undefined
    ) {
      return res.status(400).json({
        success: false,
        message: "moisture, temperature, dan ph wajib diisi",
      });
    }

    const data = await SensorData.create({
      userId: req.user._id,
      deviceId: deviceId || "default_device",
      moisture,
      temperature,
      ph,
      pumpStatus: pumpStatus || "OFF",
    });

    res.status(201).json({ success: true, data });
  } catch (error) {
    console.error("❌ [SENSOR SAVE] Error:", error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
