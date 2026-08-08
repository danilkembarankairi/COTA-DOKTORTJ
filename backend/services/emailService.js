const nodemailer = require("nodemailer");

// ✅ Aktif hanya jika SMTP_USER & SMTP_PASS ada di .env
function isEmailConfigured() {
  return Boolean(process.env.SMTP_USER && process.env.SMTP_PASS);
}

function createTransporter() {
  return nodemailer.createTransport({
    host: process.env.SMTP_HOST || "smtp.gmail.com",
    port: parseInt(process.env.SMTP_PORT || "587", 10),
    secure: false, // true jika pakai port 465
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS, // Gmail App Password
    },
  });
}

async function sendResetCodeEmail(toEmail, code) {
  const transporter = createTransporter();

  const mailOptions = {
    from: `"COTA Smart Irrigation" <${process.env.SMTP_USER}>`,
    to: toEmail,
    subject: "🔐 Kode Reset Password - COTA",
    html: `
      <div style="font-family:Arial,sans-serif;background:#f0fdf4;padding:24px;">
        <div style="max-width:480px;margin:auto;background:#fff;border-radius:16px;overflow:hidden;border:1px solid #d1fae5;">
          <div style="background:linear-gradient(135deg,#047857,#10b981);padding:24px;text-align:center;">
            <h1 style="color:#fff;margin:0;letter-spacing:3px;">COTA</h1>
            <p style="color:#d1fae5;margin:4px 0 0;font-size:12px;">CONTROL TANAMAN — Smart Irrigation</p>
          </div>
          <div style="padding:28px;text-align:center;">
            <p style="color:#334155;font-size:14px;">Halo,</p>
            <p style="color:#334155;font-size:14px;">Gunakan kode di bawah untuk mereset password Anda:</p>
            <div style="margin:20px auto;padding:14px 28px;background:#ecfdf5;border:1px dashed #10b981;border-radius:12px;display:inline-block;">
              <span style="font-size:28px;font-weight:bold;letter-spacing:6px;color:#047857;">${code}</span>
            </div>
            <p style="color:#94a3b8;font-size:12px;">Kode berlaku 10 menit. Jika Anda tidak meminta reset, abaikan email ini.</p>
          </div>
        </div>
      </div>
    `,
  };

  const info = await transporter.sendMail(mailOptions);
  console.log(`📧 [EMAIL TERKIRIM] ${info.messageId} -> ${toEmail}`);
  return info;
}

// ✅ BARU: Kirim OTP untuk pendaftaran akun baru
async function sendRegisterOtpEmail(toEmail, code) {
  const transporter = createTransporter();

  const mailOptions = {
    from: `"COTA Smart Irrigation" <${process.env.SMTP_USER}>`,
    to: toEmail,
    subject: "🌱 Kode Verifikasi Pendaftaran - COTA",
    html: `
      <div style="font-family:Arial,sans-serif;background:#f0fdf4;padding:24px;">
        <div style="max-width:480px;margin:auto;background:#fff;border-radius:16px;overflow:hidden;border:1px solid #d1fae5;">
          <div style="background:linear-gradient(135deg,#047857,#10b981);padding:24px;text-align:center;">
            <h1 style="color:#fff;margin:0;letter-spacing:3px;">COTA</h1>
            <p style="color:#d1fae5;margin:4px 0 0;font-size:12px;">CONTROL TANAMAN — Smart Irrigation</p>
          </div>
          <div style="padding:28px;text-align:center;">
            <p style="color:#334155;font-size:14px;">Halo, selamat datang di COTA!</p>
            <p style="color:#334155;font-size:14px;">Gunakan kode berikut untuk menyelesaikan pendaftaran akun Anda:</p>
            <div style="margin:20px auto;padding:14px 28px;background:#ecfdf5;border:1px dashed #10b981;border-radius:12px;display:inline-block;">
              <span style="font-size:28px;font-weight:bold;letter-spacing:6px;color:#047857;">${code}</span>
            </div>
            <p style="color:#94a3b8;font-size:12px;">Kode berlaku 5 menit. Jangan bagikan kode ini kepada siapa pun.</p>
          </div>
          <div style="background:#f8fafc;padding:14px;text-align:center;border-top:1px solid #e5e7eb;">
            <p style="color:#94a3b8;font-size:11px;margin:0;">
              Jika Anda tidak mendaftar di COTA, abaikan email ini.
            </p>
          </div>
        </div>
      </div>
    `,
  };

  const info = await transporter.sendMail(mailOptions);
  console.log(`📧 [EMAIL REGISTER] ${info.messageId} -> ${toEmail}`);
  return info;
}

// ✅ UPDATE: Export kedua fungsi
module.exports = {
  isEmailConfigured,
  sendResetCodeEmail,
  sendRegisterOtpEmail, // ✅ BARU
};
