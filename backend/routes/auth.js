const express = require("express");
const router = express.Router();
const jwt = require("jsonwebtoken");
const User = require("../models/User");
const { protect } = require("../middleware/auth");

// ✅ Import email service (reset + register OTP)
const {
  isEmailConfigured,
  sendResetCodeEmail,
  sendRegisterOtpEmail, // ✅ BARU
} = require("../services/emailService");

// ==========================================
// ✅ BARU: OTP Store untuk Register (in-memory)
// ==========================================
const registerOtpStore = new Map(); // email → {code, expiresAt, nextAllowedAt}

function generateOtp() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// Generate JWT Token
const generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRE,
  });
};

// ==========================================
// @route   POST /api/auth/register
// @desc    Register a new user (✅ SEKARANG WAJIB PAKAI OTP)
// ==========================================
router.post("/register", async (req, res) => {
  try {
    const { name, email, password, otp } = req.body;

    // ✅ BARU: Validasi OTP wajib diisi
    if (!otp) {
      return res.status(400).json({
        success: false,
        message: "Kode OTP wajib diisi",
      });
    }

    const cleanEmail = (email || "").toLowerCase().trim();

    // ✅ BARU: Verifikasi OTP
    const record = registerOtpStore.get(cleanEmail);
    if (!record) {
      return res.status(400).json({
        success: false,
        message: "Kirim kode OTP terlebih dahulu",
      });
    }
    if (Date.now() > record.expiresAt) {
      registerOtpStore.delete(cleanEmail);
      return res.status(400).json({
        success: false,
        message: "Kode OTP kedaluwarsa. Kirim ulang.",
      });
    }
    if (record.code !== otp.trim()) {
      return res.status(400).json({
        success: false,
        message: "Kode OTP salah",
      });
    }

    // Check if user exists
    const userExists = await User.findOne({ email: cleanEmail });
    if (userExists) {
      return res.status(400).json({
        success: false,
        message: "User already exists",
      });
    }

    // Create user (logika lama tetap jalan)
    const user = await User.create({
      name,
      email: cleanEmail,
      password,
    });

    // ✅ BARU: Hapus OTP dari store (biar tidak bisa dipakai ulang)
    registerOtpStore.delete(cleanEmail);

    const token = generateToken(user._id);

    res.status(201).json({
      success: true,
      data: {
        _id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        token,
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

// ==========================================
// ✅ BARU: POST /api/auth/send-register-otp
// @desc    Kirim kode OTP untuk verifikasi pendaftaran
// ==========================================
router.post("/send-register-otp", async (req, res) => {
  try {
    const email = (req.body.email || "").toLowerCase().trim();
    if (!email || !email.includes("@")) {
      return res.status(400).json({
        success: false,
        message: "Email tidak valid",
      });
    }

    // Cek email sudah terdaftar?
    const existing = await User.findOne({ email });
    if (existing) {
      return res.status(400).json({
        success: false,
        message: "Email sudah terdaftar. Silakan login.",
      });
    }

    // ✅ Rate limit sederhana: 30 detik antar kirim
    const prev = registerOtpStore.get(email);
    if (prev && prev.nextAllowedAt && Date.now() < prev.nextAllowedAt) {
      return res.status(429).json({
        success: false,
        message: "Tunggu sebentar sebelum kirim ulang kode.",
      });
    }

    const code = generateOtp();
    registerOtpStore.set(email, {
      code,
      expiresAt: Date.now() + 5 * 60 * 1000, // berlaku 5 menit
      nextAllowedAt: Date.now() + 30 * 1000, // rate limit 30 detik
    });

    // ✅ MODE REAL: kirim email sungguhan (sama kayak forgot-password)
    if (isEmailConfigured()) {
      try {
        await sendRegisterOtpEmail(email, code);
        console.log(`📧 [REGISTER OTP] Terkirim ke ${email}`);
        return res.status(200).json({
          success: true,
          message: "Kode verifikasi telah dikirim ke email Anda",
        });
      } catch (emailError) {
        console.error(
          "❌ [REGISTER OTP] Gagal kirim email, fallback demo:",
          emailError.message,
        );
        return res.status(200).json({
          success: true,
          message: "Email gagal dikirim (mode demo aktif)",
          demoCode: code,
        });
      }
    }

    // ✅ MODE DEMO: SMTP belum diatur → kode tampil di dialog & terminal
    console.log(`🎭 [DEMO OTP] Register ${email}: ${code}`);
    return res.status(200).json({
      success: true,
      message: "Kode verifikasi berhasil dibuat (mode demo)",
      demoCode: code,
    });
  } catch (error) {
    console.error("❌ [SEND-REGISTER-OTP] Error:", error.message);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

// @route   POST /api/auth/login
// @desc    Login user
router.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: "Please provide an email and password",
      });
    }

    const user = await User.findOne({ email }).select("+password");

    if (!user) {
      return res.status(401).json({
        success: false,
        message: "Invalid credentials",
      });
    }

    const isMatch = await user.matchPassword(password);

    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: "Invalid credentials",
      });
    }

    const token = generateToken(user._id);

    res.status(200).json({
      success: true,
      data: {
        _id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        token,
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

// @route   GET /api/auth/me
// @desc    Get current logged in user
router.get("/me", protect, async (req, res) => {
  try {
    const user = await User.findById(req.user.id);
    res.status(200).json({
      success: true,
      data: user,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

// ==========================================
// ✅ ROUTES UNTUK PROFIL & KEAMANAN
// ==========================================

// @route   PUT /api/auth/profile
// @desc    Update nama user (login wajib)
router.put("/profile", protect, async (req, res) => {
  try {
    const { name } = req.body;
    if (!name || name.trim().length < 3) {
      return res
        .status(400)
        .json({ success: false, message: "Nama minimal 3 karakter" });
    }
    const user = await User.findById(req.user.id);
    user.name = name.trim();
    await user.save();
    res.status(200).json({
      success: true,
      data: {
        _id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// @route   PUT /api/auth/password
// @desc    Ganti password (wajib tahu password saat ini)
router.put("/password", protect, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    const user = await User.findById(req.user.id).select("+password");

    if (!user) {
      return res
        .status(404)
        .json({ success: false, message: "User tidak ditemukan" });
    }

    const isMatch = await user.matchPassword(currentPassword || "");
    if (!isMatch) {
      return res
        .status(401)
        .json({ success: false, message: "Password saat ini salah" });
    }

    if (!newPassword || newPassword.length < 6) {
      return res
        .status(400)
        .json({ success: false, message: "Password baru minimal 6 karakter" });
    }

    user.password = newPassword;
    await user.save();
    res
      .status(200)
      .json({ success: true, message: "Password berhasil diubah" });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// @route   POST /api/auth/forgot-password
// @desc    Minta kode reset (HYBRID: email asli jika SMTP aktif, demo jika tidak)
router.post("/forgot-password", async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res
        .status(400)
        .json({ success: false, message: "Email wajib diisi" });
    }

    const user = await User.findOne({ email });
    if (!user) {
      return res
        .status(404)
        .json({ success: false, message: "Email tidak terdaftar" });
    }

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    user.resetCode = code;
    user.resetCodeExpire = Date.now() + 10 * 60 * 1000;
    await user.save();

    if (isEmailConfigured()) {
      try {
        await sendResetCodeEmail(email, code);
        return res.status(200).json({
          success: true,
          message: "Kode reset telah dikirim ke email Anda",
        });
      } catch (emailError) {
        console.error(
          "❌ Gagal kirim email, fallback demo:",
          emailError.message,
        );
        return res.status(200).json({
          success: true,
          message: "Email gagal dikirim (mode demo aktif)",
          demoCode: code,
        });
      }
    }

    console.log(`📧 [SIMULASI EMAIL] Kode reset untuk ${email}: ${code}`);
    return res.status(200).json({
      success: true,
      message: "Kode reset berhasil dibuat",
      demoCode: code,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// @route   POST /api/auth/reset-password
// @desc    Reset password pakai kode OTP
router.post("/reset-password", async (req, res) => {
  try {
    const { email, code, newPassword } = req.body;

    if (!email || !code || !newPassword) {
      return res.status(400).json({
        success: false,
        message: "Email, kode, dan password baru wajib diisi",
      });
    }

    const user = await User.findOne({ email });
    if (!user) {
      return res
        .status(404)
        .json({ success: false, message: "Email tidak terdaftar" });
    }

    if (!user.resetCode || user.resetCode !== code) {
      return res
        .status(400)
        .json({ success: false, message: "Kode reset salah" });
    }

    if (!user.resetCodeExpire || user.resetCodeExpire < Date.now()) {
      return res
        .status(400)
        .json({ success: false, message: "Kode reset kedaluwarsa" });
    }

    if (newPassword.length < 6) {
      return res
        .status(400)
        .json({ success: false, message: "Password minimal 6 karakter" });
    }

    user.password = newPassword;
    user.resetCode = undefined;
    user.resetCodeExpire = undefined;
    await user.save();

    res.status(200).json({
      success: true,
      message: "Password berhasil direset. Silakan login.",
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
