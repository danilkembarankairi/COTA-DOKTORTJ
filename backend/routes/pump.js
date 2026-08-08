const express = require("express");
const router = express.Router();
// Using shared MQTT client from server via req.app.locals.mqttClient
const { protect } = require("../middleware/auth");
const Schedule = require("../models/Schedule");

// MQTT client is retrieved from req.app.locals.mqttClient inside route handlers

// ✅ TOPIK MQTT YANG UNIK
const TOPIC_PUMP_CONTROL = "cota/smart_irrigation/pump/control";

// @route   POST /api/pump/control
// @desc    Control pump manually (ON/OFF)
router.post("/control", protect, async (req, res) => {
  try {
    const { action } = req.body; // 'ON' or 'OFF'

    if (!["ON", "OFF"].includes(action)) {
      return res.status(400).json({
        success: false,
        message: "Action must be ON or OFF",
      });
    }

    // Use shared MQTT client from server
    const client = req.app && req.app.locals && req.app.locals.mqttClient;
    if (!client || !client.connected) {
      return res.status(500).json({
        success: false,
        message: "MQTT client not connected",
      });
    }

    client.publish(TOPIC_PUMP_CONTROL, action, { qos: 1 }, (err) => {
      if (err) {
        return res.status(500).json({
          success: false,
          message: "Failed to send command",
        });
      }
    });

    res.status(200).json({
      success: true,
      message: `Pump command ${action} sent successfully`,
      data: { action },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

// @route   GET /api/pump/schedule
// @desc    Get pump schedules
router.get("/schedule", protect, async (req, res) => {
  try {
    const schedules = await Schedule.find({ userId: req.user._id });

    res.status(200).json({
      success: true,
      count: schedules.length,
      data: schedules,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

// @route   POST /api/pump/schedule
// @desc    Create new pump schedule
router.post("/schedule", protect, async (req, res) => {
  try {
    const { name, startTime, endTime, days, isActive } = req.body;

    const schedule = await Schedule.create({
      userId: req.user._id,
      name,
      startTime,
      endTime,
      days: days || [0,1,2,3,4,5,6],
      isActive: isActive !== undefined ? isActive : true,
    });

    res.status(201).json({
      success: true,
      data: schedule,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

// @route   PUT /api/pump/schedule/:id
// @desc    Update schedule
router.put("/schedule/:id", protect, async (req, res) => {
  try {
    let schedule = await Schedule.findById(req.params.id);

    if (!schedule) {
      return res.status(404).json({
        success: false,
        message: "Schedule not found",
      });
    }

    // Make sure user owns the schedule
    if (schedule.userId.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: "Not authorized to update this schedule",
      });
    }

    schedule = await Schedule.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
      runValidators: true,
    });

    res.status(200).json({
      success: true,
      data: schedule,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

// @route   DELETE /api/pump/schedule/:id
// @desc    Delete schedule
router.delete("/schedule/:id", protect, async (req, res) => {
  try {
    const schedule = await Schedule.findById(req.params.id);

    if (!schedule) {
      return res.status(404).json({
        success: false,
        message: "Schedule not found",
      });
    }

    // Make sure user owns the schedule
    if (schedule.userId.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: "Not authorized to delete this schedule",
      });
    }

    await schedule.deleteOne();

    res.status(200).json({
      success: true,
      data: {},
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

module.exports = router;
