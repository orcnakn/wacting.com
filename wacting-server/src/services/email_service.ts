import nodemailer from 'nodemailer';

const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST || 'mail.wacting.com',
    port: Number(process.env.SMTP_PORT) || 465,
    secure: Number(process.env.SMTP_PORT) === 465,
    auth: {
        user: process.env.SMTP_USER || 'info@wacting.com',
        pass: process.env.SMTP_PASS || '',
    },
});

const FROM = `"Wacting" <${process.env.SMTP_USER || 'info@wacting.com'}>`;

// ─── Shared HTML wrapper ─────────────────────────────────────────────────────
function wrapHtml(body: string): string {
    return `<!DOCTYPE html>
<html>
<body style="font-family: 'Segoe UI', Arial, sans-serif; background: #0D0D0D; color: #fff; padding: 40px; margin: 0;">
  <div style="max-width: 480px; margin: 0 auto; background: #1a1a1a; border-radius: 12px; padding: 32px; text-align: center;">
    <h1 style="color: #4A90E2; letter-spacing: 4px; margin-bottom: 4px; font-size: 28px;">WACTING</h1>
    <p style="color: #666; margin-bottom: 32px; font-size: 13px;">Establish your planetary dominance.</p>
    ${body}
    <hr style="border: none; border-top: 1px solid #333; margin: 28px 0;" />
    <p style="color: #555; font-size: 11px;">&copy; 2025 Wacting &middot; wacting.com</p>
  </div>
</body>
</html>`;
}

// ═════════════════════════════════════════════════════════════════════════════
// 1. Aktivasyon Kodu Maili
// ═════════════════════════════════════════════════════════════════════════════
export async function sendVerificationCode(email: string, code: string): Promise<void> {
    const html = wrapHtml(`
    <h2 style="font-size: 18px; margin-bottom: 12px; color: #fff;">Email Aktivasyon Kodu</h2>
    <p style="color: #bbb; line-height: 1.7; font-size: 14px;">
      Wacting'e hos geldiniz!<br/>
      Kaydınızı tamamlamak icin asagıdaki 6 haneli aktivasyon kodunu uygulamaya girin.
    </p>
    <div style="background: #111; border: 2px solid #4A90E2; border-radius: 12px; padding: 24px; margin: 28px auto; max-width: 280px;">
      <span style="font-size: 44px; font-weight: bold; letter-spacing: 14px; color: #4A90E2; font-family: 'Courier New', monospace;">${code}</span>
    </div>
    <p style="color: #888; font-size: 13px; line-height: 1.6;">
      Bu kodu kimseyle paylasmayın.<br/>
      Kod 24 saat gecerlidir.
    </p>
    <p style="color: #555; font-size: 12px; margin-top: 16px;">
      Eger bu hesabı siz acmadıysanız bu emaili gormezden gelebilirsiniz.
    </p>
    `);

    await transporter.sendMail({
        from: FROM,
        to: email,
        subject: `Wacting Aktivasyon Kodu: ${code}`,
        html,
    });
}

// ═════════════════════════════════════════════════════════════════════════════
// 2. Aktivasyon Tamamlandı Maili
// ═════════════════════════════════════════════════════════════════════════════
export async function sendWelcomeEmail(email: string, username: string): Promise<void> {
    const html = wrapHtml(`
    <div style="margin-bottom: 24px;">
      <span style="display: inline-block; background: #1a3a2a; color: #2ecc71; padding: 8px 20px; border-radius: 20px; font-size: 14px; font-weight: bold;">&#10003; Aktivasyon Tamamlandi</span>
    </div>
    <h2 style="font-size: 20px; margin-bottom: 12px; color: #fff;">Hos Geldin, ${username}!</h2>
    <p style="color: #bbb; line-height: 1.7; font-size: 14px;">
      Email adresiniz basariyla dogrulandı.<br/>
      Artik <strong style="color: #4A90E2;">Wacting</strong>'e giris yapabilirsiniz.
    </p>
    <div style="background: #111; border-radius: 10px; padding: 20px; margin: 24px 0; text-align: left;">
      <p style="color: #888; font-size: 13px; margin: 0 0 8px 0;">&#127793; <strong style="color: #ccc;">1 WAC</strong> hos geldin bonusu hesabiniza eklendi.</p>
      <p style="color: #888; font-size: 13px; margin: 0 0 8px 0;">&#127758; Kampanya olusturun, oylama baslatin.</p>
      <p style="color: #888; font-size: 13px; margin: 0;">&#9889; Haritada yerinizi alin!</p>
    </div>
    <a href="https://wacting.com"
       style="display: inline-block; padding: 14px 32px; background: #4A90E2;
              color: #fff; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 15px; letter-spacing: 1px;">
      Wacting'e Git
    </a>
    `);

    await transporter.sendMail({
        from: FROM,
        to: email,
        subject: 'Wacting — Aktivasyonunuz Tamamlandi!',
        html,
    });
}
